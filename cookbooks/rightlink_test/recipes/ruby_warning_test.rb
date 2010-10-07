#
# Cookbook Name:: rightlink_test
# Recipe:: ruby_warning_test
#
# Copyright 2010, RightScale, Inc.
#
# All rights reserved - Do Not Redistribute
#

log "============ ruby_warning_test =============="

# Create a ruby warning to make sure that rightlink does not see it as a failure.

puts ("warn outside a resource")  # spaces between method calls and parens creates a warning

ruby_block "warn_test" do
  block do
    puts ("warn inside a resource")  # spaces between method calls and parens creates a warning
  end
end
