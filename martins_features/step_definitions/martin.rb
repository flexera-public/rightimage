require "rubygems"
require "rest_connection"

## Here is a list of environment variable inputs 
#
# ENV['DEPLOYMENT'] -- the name of the deployment that you want to work on. This will be created if it 
#                      does not already exist
#

Given /^A deployment name$/ do
  ## Given a deployment, find it, or create it if it does not exit
  raise "FATAL:  Please set the environment variable $DEPLOYMENT" unless ENV['DEPLOYMENT']
  @deployment = Deployment.find_by_nickname_speed(ENV['DEPLOYMENT']).first
  @deployment = Deployment.create(:nickname => ENV['DEPLOYMENT']) unless @deployment
  puts "Using deployment '#{ENV['DEPLOYMENT']}'"
end

Given /^"([^\"]*)" operational frontends$/ do |num_servers|
  servers = @deployment.servers_no_reload
  puts "i = #{num_servers}"
  num_servers.to_i.times do |i| 
    server_name = "frontend-#{i}"
    find_or_create_server server_name
  end
end
