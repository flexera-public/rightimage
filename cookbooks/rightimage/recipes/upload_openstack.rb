rs_utils_marker :begin
class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

package "python2.6-dev" do
  only_if { node[:platform] == "ubuntu" }
  action :install
end
package "python-setuptools" do
  only_if { node[:platform] == "ubuntu" }
  action :install
end

# work around bug, doesn't chef doesn't install noarch packages for centos without arch flag
yum_package "python26-distribute" do
  only_if { node[:platform] =~ /centos|redhat/ }
  action :install
  arch "noarch"
end
package "python26-libs"  if node[:platform] =~ /centos|redhat/
package "python26-devel" if node[:platform] =~ /centos|redhat/

# Switched from easy_install to pip for most stuff, easy_install seems to be
# crapping out complaining about fetching from git urls while pip handles them fine
# Also pip handles all the dependencies better - PS
bash "install python modules" do
  flags "-ex"
  pip_cmd = (node[:platform] =~ /centos|redhat/) ? 'pip-2.6' : 'pip'
  code <<-EOH
    export PATH=$PATH:/usr/local/bin
    easy_install-2.6 pip==1.1
    # For some reason the dependencies aren't getting installed if you don't list them specifically, but at least this will help us lock down versions.
    #{pip_cmd} install glance==2011.3.1 webob==1.0.8 httplib2==0.8 routes==1.13 eventlet==0.13.0 sqlalchemy==0.8.2 paste==1.7.5.1 PasteDeploy==1.5.0 xattr==0.6.4 kombu==2.5.12
  EOH
end

ruby_block "upload to cloud" do
  block do
    require 'json'
    filename = "#{image_name}.qcow2"
    local_file = "#{target_temp_root}/#{filename}"

    ENV['OS_AUTH_USER'] = node[:rightimage][:openstack][:user]
    ENV['OS_AUTH_KEY'] = node[:rightimage][:openstack][:password]
    ENV['OS_AUTH_TENANT'] = ENV['OS_AUTH_USER']
    openstack_host = node[:rightimage][:openstack][:hostname].split(":")[0]
    openstack_api_port = node[:rightimage][:openstack][:hostname].split(":")[1] || "5000"
    ENV['OS_AUTH_URL'] = "http://#{openstack_host}:#{openstack_api_port}/v2.0"
    ENV['OS_AUTH_STRATEGY'] = "keystone"

    Chef::Log.info("Uploading #{local_file} to #{openstack_host}")
    # Don't use location=file://path/to/file like you might think, thats the name of the location to store the file on the server that hosts the images, not this machine
    cmd = %Q(env PATH=$PATH:/usr/local/bin glance add name=#{image_name} is_public=true disk_format=qcow2 container_format=ovf < #{local_file})
    Chef::Log.debug(cmd)
    upload_resp = `#{cmd}`
    Chef::Log.info("got response for upload req: #{upload_resp} to cloud.")

    if upload_resp =~ /added/i 
      image_id = upload_resp.scan(/ID:\s(.+)/i).first
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
