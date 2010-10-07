Feature: mysql_db premium resources and master/slave cluster operations
  Tests the RightScale premium ServerTemplate Mysql Chef (alpha). Starting from a fresh database (no prior backup required)

  Scenario: Basic cluster failover operations and backup from scratch
    Given A deployment
    Then I should set a variation lineage
    Then I should set a variation bucket
    And "2" operational servers
    Then I should run a mysql query "create database mynewtest" on server "1"

    When I run a recipe named "db_mysql::setup_admin_privileges" on server "1"
    Then it should converge successfully
    Then the audit entry should NOT contain "Found buggy mysql"
    
    When I run a recipe named "db_mysql::setup_replication_privileges" on server "1"
    Then it should converge successfully
    
    When I run a recipe named "db_mysql::do_tag_as_master" on server "1"
    Then it should converge successfully

    When I run a recipe named "db_mysql::do_backup" on server "1"
    Then it should converge successfully

    Then I should sleep 10 seconds
    
    When I run a recipe named "db_mysql::do_init_slave" on server "2"
    Then it should converge successfully

    When I run a recipe named "db_mysql::do_promote_to_master" on server "2"
    Then it should converge successfully

    When I run a recipe named "db_mysql::do_enable_backup" on server "2"
    Then it should converge successfully

    When I run a recipe named "db_mysql::do_disable_backup" on server "2"
    Then it should converge successfully
    
