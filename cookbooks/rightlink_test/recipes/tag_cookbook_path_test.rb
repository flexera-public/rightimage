
COOKBOOK_PATH = "/root/my_cookbooks"
TAG = "rs_agent_dev:cookbooks_path=#{COOKBOOK_PATH}/cookbooks"
UUID = node[:rightscale][:instance_uuid]
UUID_TAG = "rs_instance:uuid=#{UUID}"

log "============ tag_cookbook_path_test =============="

log "Add our instance UUID as a tag: #{UUID_TAG}"
right_link_tag UUID_TAG

log "Query servers for our tags..."
server_collection UUID do
  tags UUID_TAG
end

# Check query results to see if we have our TAG set.
ruby_block "Query for cookbook path" do
  block do
    Chef::Log.info("Checking server collection for tag...")
    h = node[:server_collection][UUID]
    tags = h[h.keys[0]]
    Chef::Log.info("Tags:#{tags}")
    result = tags.select { |s| s == TAG }
    unless result.empty?
      Chef::Log.info("  Tag found!")
      node[:devmode_test][:loaded_custom_cookbooks] = true
    else
      Chef::Log.info("  No tag found -- set and reboot!") 
    end
  end
end

# if not, add tag to instance and...
right_link_tag TAG do
  not_if do node[:devmode_test][:loaded_custom_cookbooks] end
end

# ...copy test cookbooks to COOKBOOK_PATH, then...
ruby "copy this repo" do
  not_if do node[:devmode_test][:loaded_custom_cookbooks] end
  code <<-EOH
    Chef::Log.info "Rebooting so coobook_path tag will take affect."
    `mkdir #{COOKBOOK_PATH}`
    `cp -r #{::File.join(File.dirname(__FILE__), "..", "..", "..","*")} #{COOKBOOK_PATH}`
  EOH
end

#TODO: add a reboot count check and fail if count > 3

# Reboot, if not set
execute "Rebooting so breakpoint tag will take affect." do
  command "init 6"
  not_if do node[:devmode_test][:loaded_custom_cookbooks] end
end


log "TODO: Check that were using local cookbook repo (somehow)"