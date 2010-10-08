Feature: mysql_db premium resources and master/slave cluster operations
  Tests the RightScale premium ServerTemplate Mysql Chef (alpha)

  Scenario: Basic cluster failover operations
    Given A deployment. 
    And "2" operational servers
    Then I should run a mysql query "drop database mynewtest" on server "1"
    Then I should run a mysql query "drop database mynewtest" on server "2"
    When I run a recipe named "db_mysql::do_restore_and_become_master" on server "1". 
    Then it should converge successfully

    Then I should sleep 10 seconds

    When I run a recipe named "db_mysql::do_init_slave" on server "2"
    Then it should converge successfully
    When I run a recipe named "db_mysql::do_backup" on server "2"
    Then it should converge successfully
    When I run a recipe named "db_mysql::do_disable_backup" on server "2"
    Then it should converge successfully
    When I run a recipe named "db_mysql::do_enable_backup" on server "2"
    Then it should converge successfully
    When I run a recipe named "db_mysql::do_promote_to_master" on server "2"
    Then it should converge successfully
    When I run a recipe named "db_mysql::do_disable_backup" on server "2"
    Then it should converge successfully
    When I run a recipe named "db_mysql::do_enable_backup" on server "2"
    Then it should converge successfully
