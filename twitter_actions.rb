require 'rubygems'
require 'twitter'
require 'logger'

class TwitterActions
  def initialize(db, logger)
    # Configure the Twitter gem with the different API keys
    Twitter.configure do |config|
      config.consumer_key = Settings.consumer_key
      config.consumer_secret =  Settings.consumer_secret
      config.oauth_token = Settings.oauth_token
      config.oauth_token_secret = Settings.oauth_token_secret
    end
    @db = db
    @log = logger
  end
  
  def send_update(message)
    @log.debug "tweeting #{message}"
      begin
        Twitter.update(full_message[0..140]) if Settings.send_tweets #trim message
      rescue Twitter => msg
        @log.error "Twitter says: #{msg}"
      rescue Exception => msg
        @log.error "Error: #{msg}"
      end
    end

  def send_message(user_id, message)
    @log.debug "tweeting #{user_id} #{message}"
    begin
      full_message = "#{rand(5000)} #{message}" #add random number to get around twitter not allowing duplicate messages
      Twitter.direct_message_create(user_id, full_message[0..140]) if Settings.send_dms #trim message
    rescue Twitter => msg
      @log.error "Twitter says: #{msg}"
    rescue Exception => msg
      @log.error "Error: #{msg}"
    end
  end

  def followers()
    Twitter.follower_ids.ids
  end

  def friends()
    Twitter.friend_ids.ids
  end

  def handle_subscriptions()
    #read DMs. Find out ID of last DM we read
    last_checked_dm_id = @db.get_config_value('last_checked_dm_id')
    if last_checked_dm_id.nil?
      last_checked_dm_id = 0
    else
      last_checked_dm_id = last_checked_dm_id.to_i
    end


    begin
      dms = Twitter.direct_messages({:since_id => last_checked_dm_id})
      dms.each do |dm|
        if dm.text.match /^subscribe ([a-z]{2,3}\d{2,3}) ?(\d+)?$/i then
          #subscribe request...
          match = dm.text.match /^subscribe ([a-z]{2,3}\d{2,3}) ?(\d+)?$/i
          session, strike_price = match[1], match[2]
          strike_price = 9999 if strike_price.nil? #If none given set a big number
          sender = dm.sender.screen_name
          new_subscription(session, sender, strike_price)

        elsif dm.text.match /^status/i then
          last_run_time = @db.get_config_value('last_run_time')
          sender = dm.sender.screen_name
          subscriptions = @db.get_subscription_for_user(sender).join(",").gsub("00","")
          send_message(sender, "Hi. I last ran @ #{last_run_time}. Subscriptions: #{subscriptions}.")
        elsif dm.text.match /^unsubscribe ([a-z]{2,3}\d{2,3})$/i then
          session = (dm.text.match /^unsubscribe ([a-z]{2,3}\d{2,3})$/i)[1]
          sender = dm.sender.screen_name
          delete_subscription(session, sender)
        end
        #update last_checked_dm_id
        last_checked_dm_id = dm.id.to_i unless last_checked_dm_id > dm.id.to_i
      end

      @db.set_config_value('last_checked_dm_id', last_checked_dm_id)
    end
  rescue Twitter => msg
    @log.error "Twitter says: #{msg}"
  rescue Exception => msg
    @log.error "Error: #{msg}"
  end

  def new_subscription(session, sender, strike_price)
    @log.debug "New subscription for #{sender} to session #{session} strike price #{strike_price}"
    result = @db.new_subscription(session.upcase, strike_price, sender)
    if(!result)
      send_message(sender, "Sorry I don't know about event #{session} so I can't set up a subscription.")
    else
      send_message(sender, "Hello. I've set up your subscription for #{session}. You'll be notified if there are tickets available for <= #{strike_price} GBP.")
    end
  end

  def delete_subscription(session, sender)
    @log.debug "removing subscription for #{sender} from session #{session}"
    @db.delete_subscription(session.upcase, sender)
    send_message(sender, "Hello. I've removed your subscription for #{session}.")
  end

  #Follow anyone not already following us
  def follow_users()
    friends, followers = friends(), followers()
    if friends
      followers.each do |user|
        begin
          if !friends.include?(user) then
            Twitter.friendship_create(user)
            @log.debug "Now following #{user}"
          end
        rescue Twitter => msg
          @log.error "Twitter says: #{msg}"
        rescue Exception => msg
          @log.error "Error: #{msg}"
        end
      end
    end
  end
end
