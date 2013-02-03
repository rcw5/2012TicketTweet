# this is myserver_control.rb

require 'rubygems'        # if you use RubyGems
require 'daemons'

options = {
  :app_name   => "tweety_twelve",
  :dir_mode   => :normal,
  :dir => ".",
  :multiple   => false,
  :backtrace  => true,
  :monitor    => true,
  :ontop => false
}

#Run daemons this way simply because it changes the PWD to / which makes locating config files/custom classes difficult.
#This solves the problem - see http://stackoverflow.com/questions/224845/ruby-daemons-will-not-start

pwd = Dir.pwd 
Daemons.run_proc('tweety_twelve.rb', options) do 
  Dir.chdir(pwd) 
  exec 'ruby tweety_twelve.rb'
end