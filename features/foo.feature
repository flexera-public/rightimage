@php_test

Feature: PHP Server Test
  Tests the PHP servers

Scenario: PHP server test

  Given an operational app deployment
   When I reboot the frontends
  Then the frontends become non-operational
  Then the frontends become operational

  When I reboot the appservers
  Then the appservers become non-operational
  Then the appservers become operational
