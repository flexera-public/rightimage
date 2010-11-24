class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end
class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

# Install RestConnection (in compile phase)
r = gem_package "rest_connection" do
  gem_binary "/opt/rightscale/sandbox/bin/gem"
  action :nothing
end
r.run_action(:install)
Gem.clear_paths


# Tag EC2 images
ruby_block "tag EC2 images" do
    only_if { rightimage[:cloud] == "ec2" }
    block do
      @cloud_names = { "us-east" => "1", "eu-west" => "2", "us-west" => "3","ap-southeast" => "4"}
      @region = nil
      @cloud_names.each do |cloud_name, cloud_id|
        @region = cloud_id if node[:ec2][:placement_availability_zone].include?(cloud_name)
      end
require 'fileutils'
restcon_config =<<EOF
---
:pass: #{node[:rest_connection][:pass]}
:user: #{node[:rest_connection][:user]}
:api_url: #{node[:rest_connection][:api_url]}
:common_headers: 
  X_API_VERSION: "1.0"
EOF
ENV['REST_CONNECTION_LOG'] = "/tmp/rest_connection.log"
	restcondir = ::File.join(::File.expand_path("~"), ".rest_connection")
	FileUtils.mkdir_p(restcondir)
      ::File.open(File.join(restcondir, "rest_api_config.yaml"),"w") {|f| f.write(restcon_config)}
      require 'rubygems'
      require 'rest_connection'
# incase of RACE, let's sleep randomly here lol
      sleep rand(120)

# Create the MCIs, if they don't exist.
      if @mci_s3 = MultiCloudImageInternal.find_by(:name) {|n| n =~ /#{image_name}/ }.first
        Chef::Log.info("Found Existing MCI with same name, re-using.. #{@mci_s3.href}")
      else
        @mci_s3 = MultiCloudImageInternal.create(:name => "#{image_name}", :description => "")
      end

      if @mci_ebs = MultiCloudImageInternal.find_by(:name) {|n| n =~ /#{image_name}_EBS/}.first
        Chef::Log.info("Found Existing MCI with same name, re-using..")
      else
        @mci_ebs = MultiCloudImageInternal.create(:name => "#{image_name}_EBS", :description => "")
      end

      if node[:rightimage][:arch] == "i386"
        @instance_type = "m1.small"
      else
        @instance_type = "m1.large"
      end

      tag_these = IO.read("/var/tmp/tag_these_images.csv").split(",")
      tag_these.each do |ami|
        ami.chomp!
        resource_href = Tag.connection.settings[:api_url] + "/ec2_images/#{ami}?cloud_id=#{@region}"
        Chef::Log.info("setting image TAG for #{resource_href}")
        raise "FATAL: could not find ami, aborting." if ami.blank?
        timeout = 0
        TIMEOUT_LIMIT = 90
        while(timeout <= TIMEOUT_LIMIT)
          begin
            Tag.set(resource_href, ["provides:rs_agent_type=right_link"])
            break
          rescue Exception => e
            Chef::Log.info(e.to_s)
            timeout += 1
            sleep 60
            Chef::Log.info("retrying TAG for #{timeout}s")
          end
        end
        raise "FATAL: could not tag image after #{timeout} minutes. Aborting" if timeout >= TIMEOUT_LIMIT
      end

        resource_href = Tag.connection.settings[:api_url] + "/ec2_images/#{tag_these[0]}?cloud_id=#{@region}"
	new_setting = MultiCloudImageCloudSettingInternal.create(:multi_cloud_image_href => @mci_s3.href, :cloud_id => @region.to_i, :ec2_image_href => resource_href, :aws_instance_type => @instance_type)

        resource_href = Tag.connection.settings[:api_url] + "/ec2_images/#{tag_these[1]}?cloud_id=#{@region}"
	new_setting = MultiCloudImageCloudSettingInternal.create(:multi_cloud_image_href => @mci_ebs.href, :cloud_id => @region.to_i, :ec2_image_href => resource_href, :aws_instance_type => @instance_type)
  end
end

