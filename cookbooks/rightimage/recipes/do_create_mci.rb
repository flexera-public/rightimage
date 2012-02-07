rs_utils_marker :begin
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
