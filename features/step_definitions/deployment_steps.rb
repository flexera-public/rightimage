require "rubygems"
require "rest_connection"
require "net/ssh"
require "timeout"

Given /A deployment/ do
  raise "FATAL:  Please set the environment variable $DEPLOYMENT" unless ENV['DEPLOYMENT']
  @all_servers = Array.new
  @all_servers_os = Array.new
  @all_responses = Array.new
  @deployment = Deployment.find_by_nickname_speed(ENV['DEPLOYMENT']).first
  @servers = @deployment.servers

  if ENV['SERVER_TAG']
    puts "found SERVER_TAG environment variable. Scoping server list with tag: #{ENV['SERVER_TAG']}"
    @servers = @servers.select { |s| s.nickname =~ /#{ENV['SERVER_TAG']}/ }
  end

  raise "FATAL: Couldn't find a deployment with the name #{ENV['DEPLOYMENT']}!" unless @deployment
  puts "found deployment to use: #{@deployment.nickname}, #{@deployment.href}"
end

Given /^with ssh private key$/ do
  raise "FATAL: Please set the environment $SSH_KEY_PATH to the private ssh key of the server that you want to test!" unless ENV['SSH_KEY_PATH']
  @deployment.connection.settings[:ssh_key] = ENV['SSH_KEY_PATH']
end

Given /^with a known OS$/ do
  @all_servers.each do |server|
    puts "server.spot_check_command?(\"lsb_release -is | grep Ubuntu\") = #{server.spot_check_command?("lsb_release -is | grep Ubuntu")}"
    if server.spot_check_command?("lsb_release -is | grep Ubuntu")
      puts "setting server to ubuntu"
      @all_servers_os << "ubuntu"
    else 
      puts "setting server to centos"
      @all_servers_os << "centos"
    end
  end
end

Given /^"([^\"]*)" operational servers/ do |num|
  servers = @deployment.servers_no_reload
  @servers = servers.select { |s| s.nickname =~ /#{ENV['SERVER_TAG']}/ }
  # only want 2 even if we matched more than that.
  @servers = @servers.slice(0,2)
  raise "need at least #{num} servers to start, only have: #{@servers.size}" if @servers.size < num.to_i
  @servers.each { |s| s.start } 
  @servers.each { |s| s.wait_for_operational_with_dns } 
end

Given /A deployment named "(.*)"/ do | deployment |
  @all_servers = Array.new
  @all_responses = Array.new
  @deployment = Deployment.find_by_nickname_speed(deployment).first
  raise "FATAL: Couldn't find a deployment with the name #{deployment}!" unless deployment
end

Given /A server named "(.*)"/ do |server|
  servers = @deployment.servers_no_reload
  @server = servers.detect { |s| s.nickname =~ /#{server}/ }
  @server.start
  @server.wait_for_state("operational")
  raise "FATAL: couldn't find a server named #{server}" unless server
end

Given /^"([^\"]*)" operational servers named "([^\"]*)"$/ do |num, server_name|
  servers = @deployment.servers_no_reload
  @servers = servers.select { |s| s.nickname =~ /#{server_name}/ }
  @servers.each do |s| 
    @all_servers.push s
  end
  #@all_servers.push  { |s| s.nickname =~ /#{server_name}/ }
  raise "need at least #{num} servers to start, only have: #{@servers.size}" if @servers.size < num.to_i
  @servers.each { |s| s.start } 
  @servers.each { |s| s.wait_for_operational_with_dns } 
end

Then /^I should sleep (\d+) seconds$/ do |seconds|
  sleep seconds.to_i
end

Then /^I should set rs_agent_dev:package to "(.*)"$/ do |package|
  @deployment.servers_no_reload.each do |s|
    s.tags << {"name"=>"rs_agent_dev:package=#{package}"}
    s.save
  end
end

Then /^I should set un-set all tags on all servers in the deployment$/ do
  @deployment.servers_no_reload.each do |s|
    # can't unset ALL tags, so we must set a bogus one
    s.tags = [{"name"=>"removeme:now=1"}]
    s.save
  end
end

Then /^the servers should have monitoring enabled$/ do
  @servers.each do |server|
    server.monitoring
  end
end

Then /I should set a variation bucket/ do
  bucket = "text:testingcandelete#{@deployment.href.split(/\//).last}"
  @deployment.set_input('remote_storage/default/container', bucket)
# unset all server level inputs in the deployment to ensure use of 
# the setting from the deployment level
  @deployment.servers_no_reload.each do |s|
    s.set_input('remote_storage/default/container', "text:")
  end
end
Then /I should wait for the servers to be operational with dns$/ do
  @servers.each { |s| s.wait_for_operational_with_dns } 
end
Then /all servers should go operational./ do 
  raise "ERROR: no servers found in deployment '#{ENV['DEPLOYMENT']}'" if @servers.size == 0
  
  @servers.each { |s| s.start } 
  @servers.each { |s| s.wait_for_operational_with_dns } 
end

Then /all servers should shutdown/ do 
  servers = @deployment.servers_no_reload
  server_tag = ENV['SERVER_TAG']
  @servers = servers.select { |s| s.nickname =~ /#{server_tag}/ }
  raise "ERROR: no servers with tag '#{server_tag}' found in deployment '#{ENV['DEPLOYMENT']}'" if @servers.size == 0
  @servers.each { |s| s.stop } 
  @servers.each { |s| s.wait_for_state("terminated") } 
end

Then /I should reboot the servers$/ do
  @servers.each { |s| s.reboot }
  @servers.each { |s| s.wait_for_state_change }
end

Then /I should stop the servers$/ do
  @servers.each { |s| s.stop }
  @servers.each { |s| s.wait_for_state("stopped") }
# need to unset dns ?
  @servers.each { |s| s.dns_name = "" }
  @servers.each { |s| s.params['dns-name'] = nil }
end
