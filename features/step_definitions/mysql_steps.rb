require 'rubygems'
require 'sqlite3'

Given /A set of RightScripts for MySQL promote operations$/ do
  st = ServerTemplate.find(@servers[1].server_template_href)
  @scripts_to_run = {}
  @scripts_to_run['restore'] = st.executables.detect { |ex| ex.name =~  /restore and become/i }
  @scripts_to_run['slave_init'] = st.executables.detect { |ex| ex.name =~ /slave init v2/ }
  @scripts_to_run['promote'] = st.executables.detect { |ex| ex.name =~ /promote to master/ }
  @scripts_to_run['backup'] = st.executables.detect { |ex| ex.name =~ /EBS backup/ }
  @scripts_to_run['terminate'] = st.executables.detect { |ex| ex.name =~ /TERMINATE/ }
# hardwired script! hax! (this is an 'anyscript' that users typically use to setup the master dns)
  @scripts_to_run['master_init'] = RightScript.new('href' => "/api/acct/2901/right_scripts/195053")
  @scripts_to_run['create_stripe'] = RightScript.new('href' => "/api/acct/2901/right_scripts/198381")
  @scripts_to_run['create_mysql_ebs_stripe'] = RightScript.new('href' => "/api/acct/2901/right_scripts/212492")
end

Then /^I should run a mysql query "([^\"]*)" on server "([^\"]*)"$/ do |query, server_index|
  human_index = server_index.to_i - 1
  query_command = "echo -e \"#{query}\"| mysql"
  @servers[human_index].spot_check(query_command) { |result| puts result }
end

Then /^I should setup admin and replication privileges on server "([^\"]*)"$/ do |server_index|
  human_index = server_index.to_i - 1
  admin_grant = "grant all privileges on *.* to admin_user@\'%\' identified by \'admin_passwd\'"
  rep_grant = "grant replication slave on *.* to replication_user@\'%\' identified by \'replication_passwd\'"
  admin_grant2 = "grant all privileges on *.* to admin_user@\'localhost\' identified by \'admin_passwd\'"
  rep_grant2 = "grant replication slave on *.* to replication_user@\'localhost\' identified by \'replication_passwd\'"
  [admin_grant, rep_grant, admin_grant2, rep_grant2].each do |query|
    query_command = "echo -e \"#{query}\"| mysql"
    puts @servers[human_index].spot_check_command(query_command)
  end
end

Then /I should set a variation lineage/ do
  @lineage = "text:testlineage#{rand(1000000)}"
  @deployment.set_input('db/backup/lineage', @lineage)
# unset all server level inputs in the deployment to ensure use of 
# the setting from the deployment level
  @deployment.servers_no_reload.each do |s|
    s.set_input('db/backup/lineage', "text:")
  end
end

Then /I should set a variation backup prefix/ do
  @lineage = "text:testlineage#{rand(1000000)}"
  @deployment.set_input('DB_EBS_PREFIX', @lineage)
# unset all server level inputs in the deployment to ensure use of 
# the setting from the deployment level
  @deployment.servers_no_reload.each do |s|
    s.set_input('DB_EBS_PREFIX', "text:")
  end
end

Then /I should set an oldschool variation lineage/ do
  @lineage = "text:testlineage#{rand(1000000)}"
  @deployment.set_input('DB_LINEAGE_NAME', @lineage)
# unset all server level inputs in the deployment to ensure use of 
# the setting from the deployment level
  @deployment.servers_no_reload.each do |s|
    s.set_input('DB_LINEAGE_NAME', "text:")
  end
  puts "Using Lineage: #{@lineage}"
end

Then /^I should create a MySQL EBS stripe on server "([^\"]*)"$/ do |server_index|
  human_index = server_index.to_i - 1
# this needs to match the deployments inputs for lineage and stripe count.
  options = { "EBS_MOUNT_POINT" => "text:/mnt/mysql", 
              "EBS_STRIPE_COUNT" => "text:#{@stripe_count}", 
              "EBS_VOLUME_SIZE_GB" => "text:1", 
              "DBAPPLICATION_USER" => "text:someuser", 
              "DB_MYSQLDUMP_BUCKET" => "ignore:$ignore",
              "DB_MYSQLDUMP_FILENAME" => "ignore:$ignore",
              "AWS_ACCESS_KEY_ID" => "ignore:$ignore",
              "AWS_SECRET_ACCESS_KEY" => "ignore:$ignore",
              "DB_SCHEMA_NAME" => "ignore:$ignore",
              "DBAPPLICATION_PASSWORD" => "text:somepass", 
              "EBS_TOTAL_VOLUME_GROUP_SIZE_GB" => "text:1",
              "EBS_LINEAGE" => @lineage }
  @status = @servers[human_index].run_executable(@scripts_to_run['create_mysql_ebs_stripe'], options)
end

Then /^I should check for errors in the mysql logfiles$/ do
  result = IO.read("/var/log/messages").grep(/mysqld\[.*error/i)
  raise "Found errors in /var/log/messages! #{result}" unless result.empty?
end

Then /^I should check that mysqltmp is setup properly$/ do
  query = "show variables like 'tmpdir'"
  query_command = "echo -e \"#{query}\"| mysql"
  @servers[human_index].spot_check(query_command) { |result| raise "Failure: tmpdir was unset#{result}" unless result.include?("/mnt/mysqltmp") }
end

Then /^I should create an EBS stripe on server "([^\"]*)"$/ do |server_index|
  human_index = server_index.to_i - 1
# this needs to match the deployments inputs for lineage and stripe count.
  options = { "EBS_MOUNT_POINT" => "text:/mnt/mysql", 
              "EBS_STRIPE_COUNT" => "text:#{@stripe_count}", 
              "EBS_VOLUME_SIZE_GB" => "text:1", 
              "EBS_LINEAGE" => @lineage }
  @status = @servers[human_index].run_executable(@scripts_to_run['create_stripe'], options)
end

Then /^I should set a variation stripe count of "([^\"]*)"$/ do |stripe|
  @stripe_count = stripe
  @deployment.set_input("EBS_STRIPE_COUNT", "text:#{@stripe_count}")
end

Then /^I should set a variation MySQL DNS/ do
    mydb = File.join(File.dirname(__FILE__),"..","shared.db")
    @dns_result = nil
    rowid = nil
    success = nil
    SQLite3::Database.new(mydb) do |db|
      while(1) 
        db.query("SELECT rowid FROM mysql_dns WHERE owner IS NULL") do |result|
          rowid = result.entries.first
        end
        raise "FATAL: unable to find available DNS_IDs to use!" unless rowid
        handle = db.query("UPDATE OR IGNORE mysql_dns SET owner='#{@deployment.nickname}' WHERE rowid = '#{rowid}'")
        handle.close
        success = db.get_first_row("SELECT owner FROM mysql_dns WHERE rowid = '#{rowid}'").first == @deployment.nickname
        break if success
        puts "retrying for lock on DNSIDs"
      end
      db.query("SELECT MASTER_DB_DNSNAME,MASTER_DB_DNSID,SLAVE_DB_DNSNAME,SLAVE_DB_DNSID FROM mysql_dns WHERE owner = '#{@deployment.nickname}'") do |result|
        @dns_result = result.entries.first
      end
    end
    @deployment.set_input("MASTER_DB_DNSNAME", @dns_result[0])
    @deployment.set_input("MASTER_DB_DNSID", @dns_result[1])
    @deployment.set_input("SLAVE_DB_DNSNAME", @dns_result[2])
    @deployment.set_input("SLAVE_DB_DNSID", @dns_result[3])
end

Then /^I should release the dns records for use with other deployments$/ do
  require 'sqlite3'
  SQLite3::Database.new(File.join(File.dirname(__FILE__), "..", "shared.db")) do |db|
    q = db.query("UPDATE mysql_dns SET owner=NULL where owner LIKE '#{@deployment.nickname}%'")
    q.close
  end
end

Then /^I should setup master dns to point at server "([^\"]*)"$/ do |server_index|
  human_index = server_index.to_i - 1
  audit = @servers[human_index].run_executable(@scripts_to_run['master_init']) #, {'DB_TEST_MASTER_DNSID' => @dns_result[1]})
  audit.wait_for_completed
  #@servers[human_index].run_script(@scripts_to_run['master_init']) #, {'DB_TEST_MASTER_DNSID' => @dns_result[1]})
end

Then /I should stop the mysql servers$/ do
  if @scripts_to_run['terminate']
    @servers.each { |s| s.run_executable(@scripts_to_run['terminate']) unless s.state == 'stopped' }
  else
    @servers.each { |s| s.stop }
  end

  @servers.each { |s| s.wait_for_state("stopped") }
# unset dns in our local cached copy..
  @servers.each { |s| s.params['dns-name'] = nil }
end
