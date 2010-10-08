@grid

Feature: Grid Server Test
  Tests the Reboot servers

Scenario: Grid server test

  Given A deployment with "16" servers

  When I launch all servers
  Then the "all" servers become operational

  Given I am testing the "all"
  When I reboot the servers
  And the "all" servers become operational

# Just reboot the controllers - the workers will terminate if rebooted
#
# Run the Grid macro - then update the rsgrid.json with the input for the new deployment
