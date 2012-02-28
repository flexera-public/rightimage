rs_utils_marker :begin
class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

bash "install python modules" do
  code <<-EOH
    set -ex
    easy_install-2.6 sqlalchemy eventlet routes webob paste pastedeploy glance argparse xattr httplib2 kombu
  EOH
end

ruby_block "upload to cloud" do
  block do
    require 'json'
    filename = "#{image_name}.qcow2"
    local_file = "#{target_temp_root}/#{filename}"

    openstack_user = node[:rightimage][:openstack][:user]
    openstack_password = node[:rightimage][:openstack][:password]
    openstack_hostname = node[:rightimage][:openstack][:hostname]

    Chef::Log.info("Getting openstack api token for user #{openstack_user}@#{openstack_hostname}")
    auth_resp = `curl -d '{"auth":{"passwordCredentials":{"username": "#{openstack_user}", "password": "#{openstack_pass}"}}}' -H "Content-type: application/json" http://#{openstack_hostname}:5000/v2.0/tokens` 
    Chef::Log.info("got response #{auth_resp}")
    auth_data = JSON.parse(auth_resp)

#    result = `glance-upload -A --host #{node[:rightimage][:openstack][:hostname]} --disk-format qcow2 --container-format ovf #{local_file} #{image_name}`

    if result =~ /Stored image/ 
      image_id = result.scan(/u'id':\s(\d+)/).first
      Chef::Log.info("Successfully uploaded image #{image_id} to cloud.")
      
      # add to global id store for use by other recipes
      id_list = RightImage::IdList.new(Chef::Log)
      id_list.add(image_id)
    else
      raise "ERROR: could not upload image to cloud at #{node[:rightimage][:openstack][:hostname]} due to #{result.inspect}"
    end
  end
end
rs_utils_marker :end
