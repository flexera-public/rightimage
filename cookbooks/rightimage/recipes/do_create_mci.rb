rightscale_marker :begin

class Chef::Resource
  include RightScale::RightImage::Helper
end


SANDBOX_BIN_DIR = "/opt/rightscale/sandbox/bin"
# Not necesary, rightimage_tools install in default should take care
# of all this
##{SANBDBOX_BIN_DIR}/gem install rest_connection -v 0.1.9
##{SANBDBOX_BIN_DIR}/gem install rightimage_tools -v 0.2.2

# Lay down the RightScale API credentials
directory "/root/.rest_connection"
template "/root/.rest_connection/rest_api_config.yaml" do
  source "rest_api_config.yaml.erb"
  variables(
    :user => node[:rest_connection][:user],
    :password => node[:rest_connection][:pass],
    :api_url => node[:rest_connection][:api_url]
  )
  backup false
end

# Create MCI from image
script "Create MCI or Add to MCI" do
  interpreter "#{SANDBOX_BIN_DIR}/ruby"
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
        :name=>mci_name)
    end
  EOF
end
rightscale_marker :end
