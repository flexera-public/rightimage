rightscale_marker :begin

class Chef::Resource
  include RightScale::RightImage::Helper
end


SANDBOX_BIN_DIR = "/opt/rightscale/sandbox/bin"

# Lay down the RightScale API credentials
directory "/root/.rest_connection"
template "/root/.rest_connection/rest_api_config.yaml" do
  source "rest_api_config.yaml.erb"
  variables(
    :user => node[:rightscale][:api_user],
    :password => node[:rightscale][:api_password],
    :api_url => node[:rightscale][:api_url]
  )
  backup false
end

# Create MCI from image
script "Create MCI or Add to MCI" do
  interpreter "#{SANDBOX_BIN_DIR}/ruby"
  cloud_id = node[:rightscale][:cloud_id]
  if node[:rightscale][:mci_name] =~ /./
    mci_base_name = node[:rightscale][:mci_name]
  else
    mci_base_name = node[:rightimage][:image_name]
  end
  raise "You must specify a mci_name or an image_name!" unless mci_base_name =~ /./
  raise "You must specify a cloud_id" unless cloud_id =~ /^\d+$/

  code <<-EOF
    require 'rubygems'
    require 'rest_connection'
    require 'rightimage_tools'

    mci_tool = RightImageTools::MCI.new()

    images = RightImage::IdList.new.to_hash
    raise "FATAL: no image ids found. aborting." if images.empty?
    images.each do |id, params|
      mci_name = '#{mci_base_name}'
      if params["storage_type"] == "EBS"
        mci_name << "_EBS" unless mci_name =~ /_EBS/
      end
      mci_tool.add_image_to_mci(
        :cloud_id=>#{cloud_id},
        :image_id=>id,
        :rightlink_version=>"#{node[:rightimage][:rightlink_version]}",
        :name=>mci_name)
    end
  EOF
end
rightscale_marker :end
