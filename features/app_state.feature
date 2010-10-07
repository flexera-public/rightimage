@app_state

Feature: Unified App Server Test
  Tests the RightScale app servers

Scenario: App server test

  Given A deployment
  When I launch the frontends
  And I hack the frontend rc crap
  Then the frontends become operational  

  When I launch the appservers
  And I hack the appservers rc crap
  Then the appservers become operational  

  When I reboot the frontends
  Then the frontends become non-operational
  Then the frontends become operational  

  When I reboot the appservers
  Then the appservers become non-operational  
  Then the appservers become operational  


