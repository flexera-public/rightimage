require 'rubygems'
require 'rest_connection'
require 'ruby-debug'
require 'timeout'

Given /^A deployment$/ do
  @servers = Hash.new
  raise "FATAL:  Please set the environment variable $DEPLOYMENT" unless ENV['DEPLOYMENT']
  @deployment = Deployment.find_by_nickname_speed(ENV['DEPLOYMENT']).first
  raise "FATAL: Couldn't find a deployment with the name #{ENV['DEPLOYMENT']}!" unless @deployment
#  @servers = @deployment.servers_no_reload
  @servers["all"] = @deployment.servers_no_reload
  raise "FATAL: Deployment #{ENV['DEPLOYMENT']} does not contain any servers!" unless @servers["all"]
  raise "need at 4 servers to start, only have: #{@servers["all"].size}" unless @servers["all"].size == 4
  @servers["all"].each { |s| s.settings }
  puts "found deployment to use: #{@deployment.nickname}, #{@deployment.href}"
  # Set the default port
  @port="80"
end

Given /^A deployment with "([^\"]*)" servers$/ do |count|
  @servers = Hash.new
  raise "FATAL:  Please set the environment variable $DEPLOYMENT" unless ENV['DEPLOYMENT']
  @deployment = Deployment.find_by_nickname_speed(ENV['DEPLOYMENT']).first
  raise "FATAL: Couldn't find a deployment with the name #{ENV['DEPLOYMENT']}!" unless @deployment
  @servers["all"] = @deployment.servers_no_reload
  raise "FATAL: Deployment #{ENV['DEPLOYMENT']} does not contain any servers!" unless @servers["all"]
  raise "need at #{count} servers to start, only have: #{@servers["all"].size}" unless @servers["all"].size == count.to_i
  @servers["all"].each { |s| s.settings }
  puts "found deployment to use: #{@deployment.nickname}, #{@deployment.href}"
end

When /^I launch the "([^\"]*)" servers$/ do |server_set|
  puts "entering :I launch the #{server_set}"
  @servers[server_set] = @servers["all"].select { |s| s.nickname =~ /#{server_set}?/ }
  raise "need exactly 2 #{server_set} servers to start, only have: #{@servers[server_set].size}" unless @servers[server_set].size == 2
  @servers[server_set].each { |s| s.start }
  puts "exiting :I launch the #{server_set}"
end

When /^I launch "([^\"]*)" of the "([^\"]*)" servers$/ do |count, server_set|
  puts "entering :I launch the #{server_set}"
  @servers[server_set] = @servers["all"].select { |s| s.nickname =~ /#{server_set}?/ }
  raise "need exactly #{count} #{server_set} servers to start, only have: #{@servers[server_set].size}" unless @servers[server_set].size == count.to_i
  @servers[server_set].each { |s| s.start }
  puts "exiting :I launch the #{server_set}"
end

When /^I launch all servers$/ do
  puts "entering :I launch all servers"
  @servers["all"].each { |s| s.start }
  puts "exiting :I launch all servers"
end

Then /^the "([^\"]*)" servers become non\-operational$/ do |server_set|
  @servers[server_set].each { |s| s.wait_for_state('decommissioning') }
end

Then /^the "([^\"]*)" servers become operational$/ do |server_set|
  puts "entering :the #{server_set} servers become operational"
  @servers[server_set].each { |s| s.wait_for_operational_with_dns ; s.settings ; s.reload }
  puts "exiting :the #{server_set} servers become operational"
end

#TODO we are not testing mixed OS deployments - just grab the OS of one server
Given /^with a known OS$/ do
  @servers_os = Array.new
  @servers["all"].each do |server|
    puts "server.spot_check_command?(\"lsb_release -is | grep Ubuntu\") = #{server.spot_check_command?("lsb_release -is | grep Ubuntu")}"
    if server.spot_check_command?("lsb_release -is | grep Ubuntu")
      puts "setting server to ubuntu"
      @servers_os << "ubuntu"
      @apache_str = "apache2"
      @apache_check = "apache2ctl status"
      @haproxy_check = "service haproxy status"
    else
      puts "setting server to centos"
      @servers_os << "centos"
      @apache_str = "httpd"
      @apache_check = "service httpd status"
      @haproxy_check = "service haproxy check"
    end
  end
end

When /^I query "([^\"]*)" on the servers$/ do |uri|
  @responses = Array.new
  @server_set.each { |s| 
    cmd = "curl -s #{s['dns-name']}:#{@port}#{uri} 2> /dev/null "
    @responses << `#{cmd}` 
  }
end

Then /^I should see "([^\"]*)" in all the responses$/ do |message|
  @responses.each { |r| puts "r  #{r}" ; r.should include(message) }
end

Then /^I should see "([^\"]*)" from "([^\"]*)" on the servers$/ do |message, uri|
  @server_set.each { |s| 
    cmd = "curl -s #{s['dns-name']}:#{@port}#{uri} 2> /dev/null "
    puts cmd
    timeout=60 * 5
    begin
      status = Timeout::timeout(timeout) do
        while true
          response = `#{cmd}` 
	  break if response.include?(message)
          puts "Retrying..."
          sleep 10
        end
      end
    rescue Timeout::Error => e
      raise "ERROR: Query failed after #{timeout/60} minutes."
    end
  }
end

When /^I reboot the servers$/ do
  wait_for_reboot = true
  puts "entering :I reboot the servers"
  @server_set.each { |s| s.reboot(wait_for_reboot) }
  puts "exiting :I reboot the servers"
end

Then /^I should do nothing$/ do
  puts "NO OP"
end

Then /^print the args passed "([^\"]*)"$/ do |arg1|
  puts "Arg1: #{arg1}"
end

Given /^an operational app deployment$/ do
  steps %Q{
    Given A deployment
    When I launch the frontends
    Then the frontends become operational
    When I launch the appservers
    Then the appservers become operational
  }

end

When /^I reboot the app deployment$/ do
  steps %Q{
    Given A deployment
    When I launch the frontends
    And I launch the appservers
    And I reboot the "frontend" servers
    Then the frontends become non-operational
    Then the frontends become operational
    When I reboot the "app" servers
    Then the appservers become non-operational
    Then the appservers become operational
  }
end

Then /^the app tests should succeed$/ do
    Given 'A deployment'
    When 'I query "/index.html" on all servers'
    Then 'I should see "html serving succeeded." in all the responses'
    When 'I query "/appserver/" on all servers'
    Then 'I should see "configuration=succeeded" in all the responses'
    When 'I query "/dbread/" on all servers'
    Then 'I should see "I am in the db" in all the responses'
    When 'I query "/serverid/" on all servers'
    Then 'I should see "hostname=" in all the responses'
    When 'I query "/dbread/" on all servers'
    Then 'I should see "I am in the db" in all the responses'
end

Given /^I am testing the "([^\"]*)"$/ do |server_set|
  @server_set = @servers[server_set]
end

Given /^I am using port "([^\"]*)"$/ do |port|
  @port = port
end

When /^I sleep for "([^\"]*)" seconds$/ do |seconds|
  sleep seconds.to_i
end

Then /^I run the unified app tests on the servers$/ do
#    Then "I should do nothing"
#    And 'print the args passed "\#{server_set}"'
#    When 'I query "/index.html" on the servers'
#    Then 'I should see "html serving succeeded." in all the responses'
  steps %Q{
#    When I query "/index.html" on the servers 
#    Then I should see "html serving succeeded." in all the responses
  }
end
