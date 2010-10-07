@app_test

Feature: Unified App Server Test
  Tests the RightScale app servers

Scenario: App server test

  Given A deployment

  When I query "/index.html" on all servers
  Then I should see "html serving succeeded." in all the responses

  When I query "/appserver/" on all servers
  Then I should see "configuration=succeeded" in all the responses 

  When I query "/dbread/" on all servers
  Then I should see "I am in the db" in all the responses

  When I query "/serverid/" on all servers
  Then I should see "hostname=" in all the responses

  When I query "/dbread/" on all servers
  Then I should see "I am in the db" in all the responses

