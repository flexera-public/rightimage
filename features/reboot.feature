@reboot_test

Feature: Reboot Server Test
  Tests the Reboot servers

Scenario: Reboot server test

  Given A deployment

  When I launch the "frontend" servers
  Then the "frontend" servers become operational

  When I launch the "app" servers
  Then the "frontend" servers become operational

  Given I am testing the "frontend"
  When I reboot the servers
  And the "frontend" servers become operational

  Given I am testing the "app"
  When I reboot the servers
  And the "app" servers become operational

