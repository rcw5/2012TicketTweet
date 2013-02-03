2012TicketTweet
===============

The bot I wrote to get me tickets for the Olympics. Thanks to a few hundred lines of Ruby I got to see:

* The opening ceremony (Bought 5th July for £20.12 a ticket)
* USA vs Lithuania Basketball (Bought 1st August for £20 a ticket)
* "Super Saturday" athletics with Jess Ennis and Mo Farah (Bought 1st August for £50/each)
* The Mens 100m finals night (Bought 21st July for £125/each)
* Men's Track Cycling individual sprint final (Bought 5th July for £50/each)
* Men's 1500m finals night (Bought 2nd August for £95/each)
* Cycling qualifiers (Bought 27th June for £50)
* Paralympic opening ceremony (swapped)
* 2 Paralympic track cycling sessions (Bought 20th and 26th August for £20 or £30/each)
* Paralympic swimming (Bought 22nd August for £45/each)
* Paralympic athletics (Bought 16th August for £20/each)

How it worked
===============

The bot used a subscription model to check for new tickets to Olympic and Paralympic events on the official London 2012 ticketing site (www.tickets.london2012.com), notifying subscribers over twitter DM of new tickets under a specific strike price (or alternatively via public tweets). The tweet contained a link so you could go buy the ticket straight away.

Subscriptions were set up by DMing @2012TicketTweet with the 'subscribe' action, the session code and a strike price. e.g. "subscribe AT005 125" would notify you of new tickets to AT005 (Men's 100m finals athletics) costing £125 or less. 

The bot translates session codes into URLs on the L2012 ticketing site and every minute or so scrapes the page to work out whether new tickets were released since the last time it checked. 

The actual refresh frequency is configurable and varies: normally it checked every 60 seconds (sleep\_time in config.yaml) however if the previous 2 checks return new seats then it checked more regularly (fast\_sleep\_time in config.yaml). It goes back to the standard, slower, sleep time after 10 checks return 0 new seats (the number of checks is configured by fast\_sleep\_trigger and slow\_sleep\_trigger).

In the first version the bot would run a search for the event ID and if the website said tickets were available it would then 'click' the link and load the page. However the London 2012 ticketing website was hugely cached and the search pages often updated much later than the actual event page. This was OK at the start but as interest in London 2012 tickets increased and other checkers (such as Ben Marsh's 2012TicketChecker) became more popular it was better to check the specific event page rather than perform a search.

Other actions available were 'status' (which replied to the DM with your active subscriptions) and 'unsubscribe'.

Requirements
============

The script runs on Ruby 1.8 and needs the following gems:

* daemons (see below)
* hpricot
* twitter
* logger
* sqlite3

It uses daemons as hpricot has a bug where it randomly segfaults when parsing a page causing the bot to crash. Daemons will auto-restart the application if this happens.

Usage 
======

Take a copy of config.yaml.sample and rename it config.yaml. 

**Timing settings**

* sleep_time: standard wait time in between checks for new tickets
* fast\_sleep\_time: sleep time when running in 'fast' mode
* fast\_sleep\_trigger: number of consecutive collections which return new seats, switching bot to 'fast' mode
* slow\_sleep\_trigger: number of consecutive collections which return no new seats, switching bot to 'standard' mode

**Logging related settings**

* log\_dest: set to STDOUT to log to the screen, any other value will log to a log file
* log\_name: log file name

**Twitter related settings**

* send\_tweets: Send public tweets when new tickets are found
* send\_dms: Send DMs to subscribers when new tickets are found
* The other 4 settings are required to use the twitter API

Then run:

ruby tweety\_twelve\_control.rb start

Other random interesting stuff
================================

The L2012 website was load balanced based on your session cookie. The bot did not handle cookies and as a result would bounce around from one web server to another. During ticket releases, some web servers updated before others and the bot would often tweet that new tickets were available but the site would say none were available when I checked on my laptop. Clearing cookies helps here, but it does mean you have to log in again and enter the captcha which slows down the ticket buying process and reduced your chance of success.

Because the bot bounced around web servers it often would find new tickets (and send a tweet), then on the next refresh it would go to a different web server showing no tickets available and next it would go back again to the original server (and send another tweet). It could get quite spammy and Twitter does not let you send multiple DMs with the same text, so I added a random number at the start of the tweets to ensure they were always unique. For example:

"3479 ALERT! New tix for AT005 under 150GBP - http://www.tickets.london2012.com/browse?form=session&tab=oly&sessionCode=AT005"

Idle sessions on the ticket website timed out after 15 minutes, so to speed up the buying process once I got alerted by the bot it was beneficial to keep a session active using a screen refresher plugin, refreshing the page every 5 minutes. Then when I got ticket alerts I could quickly buy them without logging in and entering the captcha again (assuming I was on the same web server as the bot).

I went to bed every night for 3 months with my phone next to me, one ear open listening for a DM notification when I would jump out of bed and go to my laptop (see below).

Before the Olympics started it was pretty easy to get tickets - you just had to be near a computer at the right time. Once they began everyone wanted tickets and there was a lot of luck involved. Much depended on the number of tickets available and which price category you chose, but by staying logged in, being quick and being decisive meant I was often lucky!

Highlight of 2012TicketTweet
===========================

I wanted to go and see the Men's 100m finals but never thought for a second that I would get a ticket that didn't cost a fortune. I nearly bought some tickets from the French Official Olympic ticket reseller but the website crashed on me, and although some had been made available on the London 2012 site in mid-July it was always at the wrong time: I was either out at lunch, on the train or just not near a computer. 

At 4:40am on Saturday 21st July I was woken up by my bot telling me there were new tickets available for that session (AT005). I had had a couple of false alarms for other events so didn't expect much but it was too good an opportunity to go back to bed. So I got up, dashed to my computer, added 2 category C tickets to my basket then clicked "Request Tickets".

To my surprise instead of the familiar "no tickets available" message I had actually been given 2 tickets, and the countdown timer for their release had begun! From being asleep to having one chance to enter correct payment details in 2 minutes meant I checked, double checked and triple checked to be sure I had got them correct. A few tense seconds later I got the confirmation email and then tried to but failed to get back to sleep. 

Not bad for what was probably one day's work!