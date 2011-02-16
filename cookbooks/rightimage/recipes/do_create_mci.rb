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
    only_if { node[:rightimage][:cloud] == "ec2" }
    block do

     ami_id = (::File.exists?("/var/tmp/image_id")) ? IO.read("/var/tmp/image_id") : nil

     # Create the MCIs, if they don't exist.
     if node[:rightimage][:arch] == "i386"
        @instance_type = "m1.small"
     else
        @instance_type = "m1.large"
     end

    if ami_id
      config_rest_connection
      Chef::Log.info("Create or add MCI for S3 image_name.")
      if @mci = MultiCloudImage.find_by(:name) {|n| n =~ /#{image_name}/ }.first
        Chef::Log.info("Found Existing MCI with same name, re-using.. #{@mci.href}")
      else
        @mci = MultiCloudImageInternal.create(:name => "#{image_name}", :description => "")
      end
      
      resource_href = Tag.connection.settings[:api_url] + "/ec2_images/#{ami_id}?cloud_id=#{cloud_id}"
      new_setting = MultiCloudImageCloudSettingInternal.create(:multi_cloud_image_href => @mci.href, :cloud_id => cloud_id.to_i, :ec2_image_href => resource_href, :aws_instance_type => @instance_type)
    end
  
  end
end
