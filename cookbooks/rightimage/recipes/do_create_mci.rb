rs_utils_marker :begin
class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

SANDBOX_BIN_DIR = "/opt/rightscale/sandbox/bin"

# Newer rest connection gem, have to set mirror freeze date to too old a value
# for the rest connection we want
RC_VERSION = "0.1.2"
RC_GEM = ::File.join(::File.dirname(__FILE__), "..", "files", "default", "rest_connection-#{RC_VERSION}.gem")

r = gem_package RC_GEM do
  gem_binary "#{SANDBOX_BIN_DIR}/gem"
  version RC_VERSION
  action :nothing
end
r.run_action(:install)

Gem.clear_paths


# Create MCI from image
ruby_block "Create MCI or Add to MCI" do
  block do
    config_rest_connection
    require 'rightimage_tools'
    mci_tool = ::RightImageTools::MCI.new(:logger=>Chef::Log)

    images = RightImage::IdList.new(Chef::Log).to_hash
    raise "FATAL: no image ids found. aborting." if images.empty?
    images.each do |id, params|
      mci_name = mci_base_name.dup
      if params["storage_type"] == "EBS"
        mci_name << "_EBS"
      end
      mci_tool.add_image_to_mci(
        :cloud_id=>cloud_id,
        :image_id=>id,
        :name=>mci_name)
    end
  end
end
rs_utils_marker :end
