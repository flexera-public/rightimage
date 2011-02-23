class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

# This is needed until rest_connection pins it's activesupport dependency version
# If you are reading this, you can prolly remove this.
r = gem_package "activesupport" do
  gem_binary "/opt/rightscale/sandbox/bin/gem"
  version "2.3.10"
  action :nothing
end
r.run_action(:install)

# Install RestConnection (in compile phase)
r = gem_package "rest_connection" do
  gem_binary "/opt/rightscale/sandbox/bin/gem"
  version "0.0.15"
  action :nothing
end
r.run_action(:install)
Gem.clear_paths

# Tag EC2 images
ruby_block "tag EC2 images" do
    block do
      TIMEOUT_LIMIT = 90      
      images = RightImage::IdList.new(Chef::Log).to_hash
      raise "FATAL: no image ids found. aborting." if images.empty?
      config_rest_connection
      images.each do |id, params|
        resource_href = Tag.connection.settings[:api_url] + "/ec2_images/#{id}?cloud_id=#{cloud_id}"
        Chef::Log.info("Setting image TAG for #{resource_href}")
        timeout = 0
        while(timeout <= TIMEOUT_LIMIT)
          begin
            Tag.set(resource_href, ["provides:rs_agent_type=right_link"])
            break
          rescue Exception => e
            Chef::Log.info(e.to_s)
            Chef::Log.info("retrying TAG after #{timeout} minute.")
            timeout += 0.5
            sleep 30
          end
        end
        raise "FATAL: could not tag image id=#{id} after #{timeout} minutes. Aborting" if timeout >= TIMEOUT_LIMIT
      end   
    end
end


