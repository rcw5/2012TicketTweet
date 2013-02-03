require 'rubygems'
require 'twitter'
require 'logger'
require 'hpricot'
require 'open-uri'
require 'settings.rb'
require 'twitter_actions.rb'
require 'database.rb'
require 'sqlite3'
require 'yaml'

class TicketSearcher
  def initialize(db, twitter, logger)
    @db = db
    @twitter = twitter
    @log = logger
  end

  #Map the value in the select list on the L2012 website with a category ID. Not all sessions have all categories below.
  def Seat_Category(value)
    case value
    when 1: "AA"
    when 2: "A"
    when 3: "B"
    when 4: "C"
    when 5: "D"
    when 6: "E"
    end
  end

  #Are seats available for a specific event_id/session_code?
  def seats_available(event_id, session_code)
    url = "http://www.tickets.london2012.com/eventdetails?id=#{event_id}"
    @log.debug "going to #{url}"
    begin
      ticket_page = open(url) { |f| Hpricot(f) }
    rescue OpenURI::HTTPError => the_error
      @log.error "Cannot download from url #{url}. Error is: #{the_error.message}"
      return
    end

    tickets_available = ticket_page.search("//p[@class='txt14-orange']/[text()*='currently unavailable']").count == 0
    
    if(!tickets_available)
      @log.debug "No tickets available for #{session_code}"
      @db.update_watchlist(session_code, 0)
      return 0      
    end

    seats = ticket_page.at("//form[@id='select_tickets']//select[@name='price_category']").containers

    latest_seats = {}
    seats.each do |seat|
      price = seat[:price]
      pricecategory = Seat_Category(seat[:value].to_i)
      @log.debug "Seats available in Category #{pricecategory} for #{price}"
      latest_seats[pricecategory] = price
    end

    whats_changed(session_code, event_id, latest_seats)
  end

  #Determine what has changed since the last time we checked
  def whats_changed(session_code, event_id, latest_seats)
    last_run = @db.get_last_available_seats(session_code)
    #stores the minimum price of the new seats found. Set to a number bigger than most expensive seat to avoid alerting users unnecessarily.
    min_new_price = 10000
    new_seat_categories = []

    latest_seats.each do |price_category,price|
      if(!last_run.include?(price_category)) #No seats in this price category last time around
        @log.info "NEW SEATS AVAILABLE!!! Session #{session_code} category #{price_category}"
        min_new_price = [price.to_i, min_new_price].min
        are_changes = true
        new_seat_categories.push({:price_category=>price_category,:price=>price}) #store the category and price in a hash
      else
        @log.debug "already knew about seats in this category #{session_code} #{price_category}"
      end
    end

    if new_seat_categories.length > 0 then #If there are new seats, work out whether we need to tell anyone
      subscribers = @db.get_subscriptions_for_session(session_code)
      subscribers.each do |subscriber|
        #Find if any new tickets meet users strike price
        if min_new_price <= subscriber["StrikePrice"].to_i
          @twitter.send_message(subscriber["TwitterName"], "ALERT! New tix for #{session_code} under #{subscriber["StrikePrice"]}GBP - http://www.tickets.london2012.com/eventdetails?id=#{event_id}")
        end
      end

      #Also send out a tweet for everyone (if send_tweets is enabled in the config file)
      categories = new_seat_categories.sort_by{ |k| k[:price_category]}.map { |x| "#{x[:price_category]}(#{x[:price]}GBP)" }.join ","
      str = "New seats found for #{session_code}: #{categories}. http://www.tickets.london2012.com/eventdetails?id=#{event_id}"
      @twitter.send_update(str)


    end
    @db.update_watchlist(session_code, 1)
    @db.update_current_tickets(session_code, latest_seats)

    return new_seat_categories.length
  end

  def tickets_available(session_code)
    
  #Used to scrape the page for the session code to work out whether tickets are for sale for a given session
  #however this is quite inaccurate as the direct link often updates before the search.
  #Instead, use the database and search every time
=begin
    url = "http://www.tickets.london2012.com/browse?form=session&tab=oly&sessionCode=#{session_code}"
    begin
      ticket_page = open(url) { |f| Hpricot(f) }
    rescue OpenURI::HTTPError => the_error
      @log.error "Cannot download from url #{url}. Error is: #{the_error.message}"
      return
    end

    #held in search_results table. If you see "<div style="width:60px">Currently unavailable</div>" then no tickets.

    search_results = ticket_page.at("//table[@id='searchResults']")

    regexp = '<div style="width:60px">Currently unavailable</div>'
    if(search_results.inner_html.match(regexp).nil?) then
      @log.info "Tickets available for #{session_code}! woot! Finding out some more..."

      #Find out which tickets...
      #<form name="Continue1" id="Continue1" method="GET" action="/eventdetails">
      #              <input type="hidden" name="id" value="0000455ACF400E76" />
      #               <input type="submit" value="Select" />

      event_id = search_results.at("//form[@id='Continue1']").at("input[@name='id']")[:value]
      
=end
  #Instead of searching the page, get the event_id from the database..

    event_id = @db.get_event_id(session_code)
    return seats_available(event_id, session_code)
  end
end

Settings.configure('config.yaml')
if Settings.log_dest == 'STDOUT'
  logger = Logger.new(STDOUT)
else
  logger = Logger.new(Settings.log_name)
end
db = Database.new(logger)
twitter = TwitterActions.new(db, logger)

logger.info "Starting up!"

#Stores the number of new tickets found on the last 'n' runs (controlled by fast/slow_sleep_time and trigger).
#This data is used to determine whether to switch between fast and slow collection times

num_new_tix = []
num_new_tix_size = [Settings.fast_sleep_trigger, Settings.slow_sleep_trigger].max
#num_new_tix_size controls size of array used to store number of tickets returned in the past collection
num_new_tix.fill(0, 0..num_new_tix_size)
#Fill array with 0s as initial history

sleep_time = Settings.sleep_time
while true
  twitter.follow_users()
  twitter.handle_subscriptions()

  new_tix_this_loop = 0
  db.get_all_watched_sessions.each do |session|
    begin
      ts = TicketSearcher.new(db, twitter, logger)
      new_tix_this_loop += ts.tickets_available(session)
    rescue Exception => msg
      logger.error "Error: #{msg}"
      logger.error msg.backtrace
    end
  end

  logger.debug "New tickets returned this loop: #{new_tix_this_loop}"
  num_new_tix.push new_tix_this_loop
  num_new_tix.shift while num_new_tix.size > num_new_tix_size
  
  #Control whether to switch to/from fast or slow sleep times
  
  slow_subset = num_new_tix[-Settings.fast_sleep_trigger,Settings.fast_sleep_trigger]
  fast_subset = num_new_tix[-Settings.slow_sleep_trigger,Settings.slow_sleep_trigger]
  
  if !slow_subset.include? 0 and sleep_time == Settings.sleep_time then
    logger.info "Last #{Settings.fast_sleep_trigger} collections have returned new seats: #{num_new_tix.join ","}. Switching to faster refresh time."
    sleep_time = Settings.fast_sleep_time
  elsif fast_subset.inject(:+) == 0 and sleep_time == Settings.fast_sleep_time then
    logger.info "Switching back to standard sleep time."
    sleep_time = Settings.sleep_time
  end


  db.set_config_value("last_run_time", Time.now.strftime("%d/%m/%y %H:%M:%S"))
  logger.debug "Sleeping for #{sleep_time}s......."
  sleep(sleep_time)
end
