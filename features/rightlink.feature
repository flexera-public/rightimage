@rightlink
Feature: RightLink Feature Tests
  
  Make sure rightlink supports the expected functionality 
  Currently using
  export DEPLOYMENT="Regression Test CHEF - unit test - rightlink"
  export SERVER_TAG="RightLink"

  Scenario: The RightLink Test template should go operational
    Given A deployment.
    Then all servers should go operational.
    
  Scenario: The RightLink Test template should go operational
    Given A deployment.
    Then all servers should go operational.
    Then all servers should successfully run a recipe named "rightlink_test::state_test_check_value".
      
  Scenario: Verify remote_recipe and rightlink_tag work using ping-pong cookbook
    Given A deployment.
    Then all servers should go operational.
    When I run a recipe named "rightlink_test::resource_remote_recipe_test_start" on server "1". 
    Then it should converge successfully.   
    Then I should sleep 10 seconds.
    Then I should see "resource_remote_recipe_ping" in the log on server "2".   
  