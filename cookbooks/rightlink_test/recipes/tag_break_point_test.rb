TAG = "rs_agent_dev:break_point=rightlink_test::tag_break_point_test_should_never_run"
UUID = node[:rightscale][:instance_uuid]
UUID_TAG = "rs_instance:uuid=#{UUID}"

log "============ tag_break_point_test =============="

log "Add our instance UUID as a tag: #{UUID_TAG}"
right_link_tag UUID_TAG

log "Verify tag exists"
wait_for_tag UUID_TAG do
  collection_name UUID
end

log "Query servers for our tags..."
server_collection UUID do
  tags UUID_TAG
end

# Check query results to see if we have our TAG set.
ruby_block "Query for breakpoint" do
  block do
    Chef::Log.info("Checking server collection for tag...")
    h = node[:server_collection][UUID]
    tags = h[h.keys[0]]
    Chef::Log.info("Tags:#{tags}")
    result = tags.select { |s| s == TAG }
    unless result.empty?
      Chef::Log.info("  Tag found!")
      node[:devmode_test][:has_breakpoint] = true
      node[:devmode_test][:initial_pass] = false if node[:devmode_test][:initial_pass]
      node[:devmode_test][:disable_breakpoint_test] = true unless node[:devmode_test][:initial_pass]
    else
      Chef::Log.info("  No tag found -- set and reboot!") 
    end
  end
end

# Set breakpoint if not set.
right_link_tag TAG do
  not_if do node[:devmode_test][:has_breakpoint] end
end

#TODO: add a reboot count check and fail if count > 3

# Reboot, if not set
execute "Rebooting so breakpoint tag will take affect." do
  command "init 6"
  not_if do node[:devmode_test][:has_breakpoint] end
end

