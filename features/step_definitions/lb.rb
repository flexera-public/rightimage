require "rubygems"
require "ruby-debug"
require "rest_connection"
require "net/ssh"

def get_lb_hostname_input(fe_servers)
  lb_hostname_input = "text:"
  fe_servers.each do |fe|
      lb_hostname_input << fe.settings['private-dns-name'] + " " 
  end
  lb_hostname_input
end

def get_tester_ip_addr()
  require "/var/spool/ec2/meta-data" #TODO: use ohai to grab this value when we move to v5 testers
  my_ip_input = "text:" 
  my_ip_input << ENV['EC2_PUBLIC_HOSTNAME'] 
  my_ip_input.strip
end

When /^I cross connect the frontends$/ do
  puts "entering :I cross\-connect the frontends"
  @statuses = Array.new 
  st = ServerTemplate.find(@servers["Front End"].first.server_template_href)
  script_to_run = st.executables.detect { |ex| ex.name =~  /LB [app|mongrels]+ to HA proxy connect/i }
  raise "Could not find script" unless script_to_run
  
  options = Hash.new
  options[:LB_HOSTNAME] = get_lb_hostname_input(@servers["Front End"])
  
  @servers["Front End"].each { |s| @statuses << s.run_executable(script_to_run, options) }
  puts "exiting :I cross\-connect the frontends"
end

When /^I setup deployment input "([^\"]*)" to current "([^\"]*)"$/ do |input, server_set|
  @deployment.set_input(:"#{input}",get_lb_hostname_input(@servers[server_set])) 
end

When /^I setup deployment input "([^\"]*)" to "([^\"]*)"$/ do |input_name, value|
  value = get_tester_ip_addr() if value == "tester_ip"
  @deployment.set_input(:"#{input_name}", value) 
end

Then /^the cross connect script completes successfully$/ do
  @statuses.each_with_index { |s,i| s.wait_for_completed(@servers["Front End"][i].audit_link) }
end

Then /^I should see all "([^\"]*)" servers in the haproxy config$/ do |app_server_set|
  puts "entering :I should see all #{app_server_set} servers in the haproxy config"
  @server_ips = Array.new
  @servers[app_server_set].each { |app| @server_ips << app['private-ip-address'] }
  @server_set.each do |fe|
    fe.settings
    haproxy_config = fe.spot_check_command('cat /home/haproxy/rightscale_lb.cfg | grep server')
    @server_ips.each { |ip|  haproxy_config.to_s.should include(ip) }
  end
  puts "Exiting from :I should see all #{app_server_set} servers in the haproxy config"
end

Then /^I should see all servers being served from haproxy$/ do
  puts "entering :I should see all servers being served from haproxy"
  @servers["Front End"].each do |fe|
    ip_list = @app_server_ips.clone
    ip_list.size.times do 
      cmd = "curl -q #{fe['dns-name']}/serverid/ 2> /dev/null | grep ip= | sed 's/^ip=//' | sed 's/;.*$//'"
      puts cmd
      serverip = `#{cmd}`.chomp
      puts "serverip = #{serverip.inspect}"
      ip_list.delete serverip 
      puts "ip_list.inspect = #{ip_list.inspect}"
    end
    raise "Did not see all servers being served by haproxy!!!" unless ip_list.empty?
  end
end


When /^I restart haproxy$/ do
  @server_set.each_with_index do |server,i|
    response = server.spot_check_command?('service haproxy stop')
    raise "Haproxy stop command failed" unless response

    stopped = false
    count = 0
    until response || count > 3 do
      response = server.spot_check_command(@haproxy_check)
      stopped = response.include?("not running")
      break if stopped
      count += 1
      sleep 10
    end

    response = server.spot_check_command?('service haproxy start')
    raise "Haproxy start failed" unless response
  end
end

Then /^haproxy status should be good$/ do
  raise "ERROR: you must include 'Given with a known OS' step before this one!" unless @haproxy_check
  @server_set.each_with_index do |server,i|
    response = nil
    count = 0
    until response || count > 3 do
      response = server.spot_check_command?(@haproxy_check)
      break if response	
      count += 1
      sleep 10
    end
    raise "Haproxy check failed" unless response
  end
end

# When /^I restart apache on all servers$/ do
#   puts "entering :I restart apache on all servers"
#   @statuses = Array.new
#   st = ServerTemplate.find(@servers["all"].first.server_template_href)
#   script_to_run = st.executables.detect { |ex| ex.name =~  /WEB apache \(re\)start v2/i }
#   raise "Script not found" unless script_to_run
#   @servers["Front End"].each { |s| @statuses << s.run_executable(script_to_run) }
#   @servers["app"].each { |s| @statuses << s.run_executable(script_to_run) }
#   puts "exiting :I restart apache on all servers"
# end

# Then /^apache status should be good$/ do
#   if @servers_os.first == "ubuntu"
#     apache_status_cmd = "apache2ctl status"
#   else
#     apache_status_cmd = "service httpd status"
#   end
#   @servers["all"].each_with_index do |server,i|
#     response = nil
#     count = 0
#     until response || count > 3 do
#       response = server.spot_check_command?(apache_status_cmd)
#       break if response 
#       count += 1
#       sleep 10
#     end
#     raise "Apache status failed" unless response
#   end
# end

When /^I restart apache$/ do
  puts "entering :I restart apache"
  @statuses = Array.new
  st = ServerTemplate.find(@server_set.first.server_template_href)
  script_to_run = st.executables.detect { |ex| ex.name =~  /WEB apache \(re\)start v2/i }
  raise "Script not found" unless script_to_run
  @server_set.each { |s| @statuses << s.run_executable(script_to_run) }
  puts "exiting :I restart apache on the frontend servers"
end

Then /^apache status should be good$/ do
  raise "ERROR: you must include 'Given with a known OS' step before this one!" unless @apache_check
  @server_set.each_with_index do |server,i|
    response = nil
    count = 0
    until response || count > 3 do
      response = server.spot_check_command?(@apache_check)
      break if response	
      count += 1
      sleep 10
    end
    raise "Apache status failed" unless response
  end
end

When /^I restart mongrels on all servers$/ do
  puts "entering :I restart mongrels on all servers"
  @statuses = Array.new
  st = ServerTemplate.find(@servers["all"].first.server_template_href)
  script_to_run = st.executables.detect { |ex| ex.name =~  /RB mongrel_cluster \(re\)start v1/i }
  raise "Script not found" unless script_to_run
  @servers["Front End"].each { |s| @statuses << s.run_executable(script_to_run) }
  puts "exiting :I restart mongrels on all servers"
end

Then /^mongrel status should be good$/ do
  @servers["all"].each_with_index do |server,i|
    response = nil
    count = 0
    until response || count > 3 do
      response = server.spot_check_command?("service mongrel_cluster status")
      break if response	
      count += 1
      sleep 10
    end
    raise "Mongrel status failed" unless response
  end
end

When /^I force log rotation$/ do
  @server_set.each do |server|
    response = server.spot_check_command?('logrotate -f /etc/logrotate.conf')
    raise "Logrotate restart failed" unless response
  end
end

Then /^I should see rotated apache log "([^\"]*)" in base dir "([^\"]*)"$/ do |logfile, basedir|
  raise "ERROR: you must include 'Given with a known OS' step before this one!" unless @apache_str
  @server_set.each do |server|
    response = nil
    count = 0
    until response || count > 3 do
      response = server.spot_check_command?("test -f #{basedir}/#{@apache_str}/#{logfile}")
      break if response
      count += 1
      sleep 10
    end
    raise "Log file does not exist" unless response
  end
end

Then /^I should see "([^\"]*)"$/ do |logfile|
  @server_set.each do |server|
    response = nil
    count = 0
    until response || count > 3 do
      response = server.spot_check_command?("test -f #{logfile}")
      break if response
      count += 1
      sleep 10
    end
    raise "Log file does not exist" unless response
  end
end

Then /^the lb tests should succeed$/ do
  steps %Q{
    Given A deployment with frontends
    When I cross connect the frontends
    Then the cross connect script completes successfully
#    And I should see all servers in the haproxy config
  Then I should see all "app" servers in the haproxy config
    Then I should see all "all" servers in the haproxy config
#    And I should see all servers being served from haproxy
  }
end
