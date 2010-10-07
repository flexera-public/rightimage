@lb_test

Feature: LB Server Test
  Tests the LB servers

Scenario: LB server test

  Given A deployment
  
  When I setup deployment input "MASTER_DB_DNSNAME" to "tester_ip"

  When I launch the "Apache" servers
  Then the "Apache" servers become operational

  When I setup deployment input "LB_HOSTNAME" to current "Apache"

  When I launch the "App Server" servers
  Then the "App Server" servers become operational

  Given I am testing the "Apache"
  Given with a known OS
  Given I am using port "80"
  
  Then I should see "html serving succeeded." from "/index.html" on the servers
  Then I should see "configuration=succeeded" from "/appserver/" on the servers
  Then I should see "I am in the db" from "/dbread/" on the servers
  Then I should see "hostname=" from "/serverid/" on the servers

  Then I should see all "App Server" servers in the haproxy config

  When I restart haproxy
  Then haproxy status should be good

  When I restart apache
  Then apache status should be good

  When I force log rotation
  Then I should see rotated apache log "haproxy.log.1" in base dir "/mnt/log" 
  Then I should see rotated apache log "access.log.1" in base dir "/mnt/log" 

  When I reboot the servers
  Then the "Apache" servers become operational

  Then I should see "html serving succeeded." from "/index.html" on the servers
  Then I should see "configuration=succeeded" from "/appserver/" on the servers
  Then I should see "I am in the db" from "/dbread/" on the servers

# Disconnect test - todo
