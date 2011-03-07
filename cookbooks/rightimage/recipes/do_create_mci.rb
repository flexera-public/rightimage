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

# Create MCI from image
ruby_block "Create EC2 MCI" do
    block do

     if node[:rightimage][:arch] == "i386"
        @instance_type = "m1.small"
     else
        @instance_type = "m1.large"
     end

     config_rest_connection
     images = RightImage::IdList.new(Chef::Log).to_hash
     raise "FATAL: no image ids found. aborting." if images.empty?
     images.each do |id, params|
       
       # Create the MCIs, if they don't exist.
       mci_name = image_name
       mci_name << "_EBS" if params["storage_type"] == "EBS"
       Chef::Log.info("Create or add to MCI for #{mci_name} on cloud id #{cloud_id}.")
       if @mci = MultiCloudImage.find_by(:name) {|n| n == mci_name }.first
         Chef::Log.info("Found Existing MCI with same name, re-using.. #{@mci.href}")
       else
         @mci = MultiCloudImageInternal.create(:name => "#{mci_name}", :description => "Development Build")
         mci_util = RightImage::MCI.new(Chef::Log)
         mci_util.add_rightlink_tag(@mci)
       end
  
       # Add cloud setting for this image    
       resource_href = Tag.connection.settings[:api_url] + "/ec2_images/#{id}?cloud_id=#{cloud_id}"
       new_setting = MultiCloudImageCloudSettingInternal.create(:multi_cloud_image_href => @mci.href, :cloud_id => cloud_id.to_i, :ec2_image_href => resource_href, :aws_instance_type => @instance_type)
      end
    end  
end
