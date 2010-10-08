@mysql_5.x
Feature: mysql 5.x v2 or v4 promote operations test
  Tests the RightScale premium ServerTemplate

  Scenario: Setup 2 server deployment and run basic cluster failover operations
#
# PHASE 1) Bootstrap a backup lineage from scratch
#
    Given A deployment
    And A set of RightScripts for MySQL promote operations. 
    Then I should stop the mysql servers
    Then I should set an oldschool variation lineage
    Then I should set a variation stripe count of "1"
    Then I should set a variation MySQL DNS
    Then all servers should go operational
    Then I should create a MySQL EBS stripe on server "1"
    Then the rightscript should complete successfully
    Then I should run a mysql query "create database mynewtest" on server "1"
    Then I should setup master dns to point at server "1"
# This sleep is to wait for DNS to settle
    Then I should sleep 120 seconds
    When I run a rightscript named "backup" on server "1"
    Then the rightscript should complete successfully

#
# PHASE 2) Relaunch and run restore operations
#
    Then I should stop the mysql servers
    Then all servers should go operational
    And A set of RightScripts for MySQL promote operations. 

# This sleep is required for the EBS snapshot to settle from prior backup.  
# Assuming 5 minutes already passed while booting
    Then I should sleep 500 seconds
    When I run a rightscript named "restore" on server "1"
    Then the rightscript should complete successfully
    Then the servers should have monitoring enabled
    Then I should check for errors in the mysql logfiles
    Then I should check that mysqltmp is setup properly

# This sleep is required for the EBS volume snapshot to settle. 
# The sleep time can vary so if slave init fails with no snapshot, this is a likely culprit
    Then I should sleep 900 seconds
    When I run a rightscript named "slave_init" on server "2"
    Then the rightscript should complete successfully
    When I run a rightscript named "promote" on server "2"
    Then the rightscript should complete successfully

#
# PHASE 3)
#

    Then I should reboot the servers
    Then I should wait for the servers to be operational with dns
# This sleep is for waiting for the slave to catch up to the master since they both reboot at once
    Then I should sleep 120 seconds
    When I run a rightscript named "backup" on server "1"
    Then the rightscript should complete successfully
#
# PHASE 4) cleanup
# 
    Then I should release the dns records for use with other deployments

#TODO: spot check for operational mysql
