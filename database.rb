require "rubygems"
require 'sqlite3'
require 'logger'

class Database
  def initialize(logger)
    @db = SQLite3::Database.new( 'tickets.db' )
    @logger = logger
  end

  #Subscription events..
  def new_subscription(session_code, strike_price, twitter_handle)
    
    event_id = get_event_id(session_code)
    if(event_id.nil?)
      return false
    end
    
    result = @db.get_first_value( "select count(*) from Subscriptions where SessionCode=? and TwitterName = ?", session_code, twitter_handle )
    #Create a new subscription if one does not exist, otherwise update the strike price
    if result == 0
      @db.execute( "insert into Subscriptions (SessionCode, StrikePrice, TwitterName) values (?,?,?)", session_code, strike_price, twitter_handle )
    else
      @db.execute( "update Subscriptions set StrikePrice=? where SessionCode=? and TwitterName=?", strike_price, session_code, twitter_handle )
    end
    self.new_watchlist(session_code)
    true
  end

  def get_subscriptions_for_session(session_code)
    @db.results_as_hash = true
    result = @db.execute( "select TwitterName, StrikePrice from Subscriptions where SessionCode = ? and Active=1", session_code)
    @db.results_as_hash = false
    result
  end

  def delete_subscription(session_code, twitter_handle)
    result = @db.get_first_value( "select count(*) from Subscriptions where SessionCode=? and TwitterName=?", session_code, twitter_handle )
    if result > 0
      @db.execute("delete from Subscriptions where SessionCode=? and TwitterName=?", session_code, twitter_handle)
    end

    #delete from watchlist and currenttickets if this is the last subscription for this event
    num_subs = @db.get_first_value( "select count(*) from Subscriptions where SessionCode=?", session_code)
    if num_subs == 0
      @db.execute("delete from Watchlist where SessionCode=?", session_code)
      @db.execute("delete from Currenttickets where SessionCode=?", session_code)
    end
  end

  def get_subscription_for_user(twitter_handle)
    result = @db.execute( "select SessionCode from Subscriptions where TwitterName = ? and Active=1", twitter_handle)
    if result.length > 0
      result.flatten!
    end
    result
  end

  #Watchlist stuff
  def get_all_watched_sessions()
    result = @db.execute( "select SessionCode from Watchlist where Active=1" )
    if result.length > 0
      result.flatten!
    end
    result
  end
  
  def get_event_id(session_code)
     @db.get_first_value( "select EventID from Events where Name=?", session_code )
  end

  def new_watchlist(session_code)
    result = @db.get_first_value( "select count(*) from Watchlist where SessionCode=?", session_code )
    if result == 0
      @db.execute( "insert into Watchlist (SessionCode) values (?)", session_code )
    end
  end

  def update_watchlist(session_code, tickets_available)
    @db.execute("update WatchList set TicketsAvailable=?, LastChecked=CURRENT_TIMESTAMP where SessionCode=?", tickets_available, session_code )
    if tickets_available == 0
      @db.execute("delete from CurrentTickets where SessionCode=?", session_code)
    end
  end

  #Update current ticket data for a specific session (available_tickets contains category and price data)
  def update_current_tickets(session_code, available_tickets)
    @db.execute("delete from CurrentTickets where SessionCode=?", session_code)

    available_tickets.each do |category, price|
      @db.execute("insert into CurrentTickets (SessionCode, PriceCategory, Price) values (?,?,?)", session_code, category, price)
    end
  end

  #Get ticket data from the last time the script was run
  def get_last_available_seats(session_code)
    last_run = @db.execute("select PriceCategory from CurrentTickets where SessionCode=?", session_code).flatten!
    last_run.nil? ? [] : last_run
  end

  #Config
  def get_config_value(name)
    @db.get_first_value( "select value from Config where name=?", name )
  end

  def set_config_value(name, value)
    result = @db.get_first_value( "select count(*) from Config where name=?", name )
    if result == 0
      @db.execute( "insert into Config (name, value) values (?,?)", name, value )
    else
      @db.execute( "update Config set value=? where name=?", value, name )
    end
  end

end
