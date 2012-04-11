rs_utils_marker :begin
class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

packages = case node[:platform]
           when "centos" then
             if node[:platform_version].to_f >= 6.0
               %w(python-setuptools python-devel python-libs)
             else
               %w(python26-distribute python26-devel python26-libs)
             end
           when "ubuntu" then
             %w(python2.6-dev python-setuptools)
           end

packages.each do |p|
  r = package p do
    action :nothing
  end
  r.run_action(:install)
end

bash "install python modules" do
  flags "-ex"
  code <<-EOH
    easy_install-2.6 sqlalchemy eventlet routes webob paste pastedeploy glance argparse xattr httplib2 kombu iso8601
  EOH
end

ruby_block "upload to cloud" do
  block do
    require 'json'
    filename = "#{image_name}.qcow2"
    local_file = "#{target_temp_root}/#{filename}"

    openstack_user = node[:rightimage][:openstack][:user]
    openstack_password = node[:rightimage][:openstack][:password]
    openstack_host = node[:rightimage][:openstack][:hostname].split(":")[0]
    openstack_api_port = node[:rightimage][:openstack][:hostname].split(":")[1] || "5000"
    openstack_glance_port = "9292"

    Chef::Log.info("Getting openstack api token for user #{openstack_user}@#{openstack_host}:#{openstack_api_port}")
    auth_resp = `curl -d '{"auth":{"passwordCredentials":{"username": "#{openstack_user}", "password": "#{openstack_password}"}}}' -H "Content-type: application/json" http://#{openstack_host}:#{openstack_api_port}/v2.0/tokens` 
    Chef::Log.info("got response for auth req: #{auth_resp}")
    auth_hash = JSON.parse(auth_resp)
    access_token = auth_hash["access"]["token"]["id"]

    # Don't use location=file://path/to/file like you might think, thats the name of the location to store the file on the server that hosts the images, not this machine
    cmd = %Q(env PATH=$PATH:/usr/local/bin glance add --auth_token=#{access_token} --url=http://#{openstack_host}:#{openstack_glance_port}/v2.0 name=#{image_name} is_public=true disk_format=qcow2 container_format=ovf < #{local_file})
    Chef::Log.debug(cmd)
    upload_resp = `#{cmd}`
    Chef::Log.info("got response for upload req: #{upload_resp} to cloud.")

    if upload_resp =~ /added/i 
      image_id = upload_resp.scan(/ID:\s(\d+)/i).first
      Chef::Log.info("Successfully uploaded image #{image_id} to cloud.")
      
      # add to global id store for use by other recipes
      id_list = RightImage::IdList.new(Chef::Log)
      id_list.add(image_id)
    else
      raise "ERROR: could not upload image to cloud at #{node[:rightimage][:openstack][:hostname]} due to #{upload_resp.inspect}"
    end
  end
end
rs_utils_marker :end
