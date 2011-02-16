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
  action :nothing
end
r.run_action(:install)
Gem.clear_paths

# Tag EC2 images
ruby_block "tag EC2 images" do
    block do

      TIMEOUT_LIMIT = 90

      image_id_file = "/var/tmp/image_id"
      Chef::Log.info("Looking for image ids in #{image_id_file}...")
      ami_list = (::File.exists?(image_id_file)) ? IO.read(image_id_file) : nil
      tag_these = ami_list.split
      raise "FATAL: no amis found in file. aborting." if tag_these.empty?

      tag_these.each do |ami|
        ami.chomp!
        raise "FATAL: could not find ami, aborting." if ami.blank?
        config_rest_connection
        resource_href = Tag.connection.settings[:api_url] + "/ec2_images/#{ami}?cloud_id=#{cloud_id}"
        Chef::Log.info("setting image TAG for #{resource_href}")
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
        raise "FATAL: could not tag image after #{timeout} minutes. Aborting" if timeout >= TIMEOUT_LIMIT
      end
       
  end
end


