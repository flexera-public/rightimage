@mysql_5.x
Feature: mysql 5.x v2 reboot test
  Tests the RightScale premium ServerTemplate Mysql v2 reboot

  Scenario: Setup 2 server deployment, create stripe, then reboot

    Given A deployment. 
    And A set of RightScripts for MySQL promote operations. 
    Then I should stop the mysql servers
    Then I should set an oldschool variation lineage
    Then I should set a variation stripe count of "1"

    Then all servers should go operational
    Then I should create a MySQL EBS stripe on server "1"
    Then the rightscript should complete successfully
    Then I should run a mysql query "create database mynewtest" on server "1"

    Then I should reboot the servers
    Then I should wait for the servers to be operational with dns
    
    When I run a rightscript named "backup" on server "1"
    Then the rightscript should complete successfully

