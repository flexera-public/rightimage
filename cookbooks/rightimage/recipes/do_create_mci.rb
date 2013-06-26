
rightscale_marker :begin

class Chef::Resource
  include RightScale::RightImage::Helper
  include Chef::Mixin::ShellOut
end



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

ri_tools_dir="/tmp/rightimage_tools"

directory ri_tools_dir

cookbook_file "#{ri_tools_dir}/rightimage_tools.tar.gz" do
  source "rightimage_tools.tar.gz"
  mode "0644"
  backup false
end

cookbook_file "#{ri_tools_dir}/setup_rightimage_tools.sh" do
  source "setup_rightimage_tools.sh"
  mode "0755"
  backup false
end

execute "#{ri_tools_dir}/setup_rightimage_tools.sh" do
  environment(node[:rightimage][:script_env])
end


# Create MCI from image
ruby_block "Create MCI or Add to MCI" do
  block do
    cloud_id = node[:rightscale][:cloud_id]

    raise "You must specify a cloud_id" unless cloud_id =~ /^\d+$/
    images = RightImage::IdList.new(Chef::Log).to_hash
    raise "FATAL: no image ids found. aborting." if images.empty?

    images.each do |id, params|
      if node[:rightscale][:mci_name] =~ /^\d+$/
        mci_id = node[:rightscale][:mci_name].to_s.dup
        mci_param = "--id '#{mci_id}'"
      elsif node[:rightscale][:mci_name] =~ /./
        mci_name = node[:rightscale][:mci_name].to_s.dup
        mci_param = "--name '#{mci_name}'"
      else
        mci_name = node[:rightimage][:image_name].to_s.dup
        if params["storage_type"] == "EBS"
          mci_name << "_EBS" unless mci_name =~ /_EBS/
        end
        mci_param = "--name '#{mci_name}'"
      end

      if mci_param.include? "''"
        raise "You must specify a mci_name or an image_name. mci_name may be a string corresponding to the name of the mci to add the image to, or a integer to add it to a specific MCI"
      end

      cmd = "bundle exec bin/mci_add #{mci_param} --cloud-id '#{cloud_id}' --image-id '#{id}' --rightlink-version '#{node[:rightimage][:rightlink_version]}'"
      Chef::Log.info("In '#{ri_tools_dir}', running cmd: #{cmd}")
      shell_out!(cmd, :cwd=>ri_tools_dir, :environment=>node[:rightimage][:script_env])      
    end
  end
end
rightscale_marker :end
