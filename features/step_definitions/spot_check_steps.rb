Then /^I should run a command "([^\"]*)" on server "([^\"]*)"$/ do |command, server_index|
  human_index = server_index.to_i - 1
  @servers[human_index].spot_check(command) { |result| puts result }
end

When /^I run "([^\"]*)"$/ do |command|
  @response = @server.spot_check_command?(command)
end

When /^I run "([^\"]*)" on all servers$/ do |command|
  @all_servers.each_with_index do |s,i|
    @all_responses[i] = s.spot_check_command?(command)
  end
end


#
# Checking for request sucess/error
#
Then /^it should exit successfully$/ do
  @response.should be true
end

Then /^it should exit successfully on all servers$/ do
  @all_responses.each do |response|
    response.should be true
  end
end

Then /^it should not exit successfully on any server$/ do
  @all_responses.each do |response|
    response.should_not be true
  end
end

