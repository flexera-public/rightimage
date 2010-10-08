@haproxy

Feature: haproxy test
  Tests the RightScale LB stack

  Scenario: Basic test

    Given A deployment name
    And "2" operational frontends
    And A server running on "80"
    And "2" operational servers named "fe"
    And with ssh private key
    And with a known OS

    When I query "/" on all servers 
    Then I should see "html serving succeeded." in all the responses

    When I query "/appserver" on all servers
    Then I should see "configuration=succeeded" in all the responses 

    When I query "/dbread" on all servers
    Then I should see "I am in the db" in all the responses

    When I check the haproxy status on all servers
    Then it should exit successfully on all servers

    When I check the apache status on all servers
    Then it should exit successfully on all servers

    When I run "service haproxy restart" on all servers
    Then it should exit successfully on all servers

    When I run "pgrep haproxy" on all servers
    Then it should exit successfully on all servers

