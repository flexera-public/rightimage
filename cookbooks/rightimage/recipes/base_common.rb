rs_utils_marker :begin
#
# Cookbook Name:: rightimage
# Recipe:: base_common
#
# Copyright 2011, RightScale, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
class Chef::Resource
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end

remote_file "/etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL#{epel_key_name}" do
   source "RPM-GPG-KEY-EPEL#{epel_key_name}"
   backup false
end

directory target_temp_root do
  owner "root"
  group "root"
  recursive true
end

packages = case node[:platform]
           when "ubuntu" then %w(libxml2-dev libxslt1-dev)
           when "centos", /redhat/ then %w(libxml2-devel libxslt-devel)
           end

packages.each do |p|
  r = package p do
    action :nothing
  end
  r.run_action(:install)
end

node[:rightimage][:host_packages].split.each { |p| package p }

include_recipe "rightimage::clean"
include_recipe "rightimage::rightscale_install"

log "Add RightLink cloud file"
execute "echo -n #{rightlink_cloud} > #{guest_root}/etc/rightscale.d/cloud" do
  creates "#{guest_root}/etc/rightscale.d/cloud"
end

log "Add RightLink 5.6 backwards compatibility symlink"
bash "rightlink56 symlink" do
#  not_if "test -L #{guest_root}/var/spool/#{node[:rightimage][:cloud]}"
  code <<-EOH
    file=/var/spool/#{node[:rightimage][:cloud]}
    rm -rf #{guest_root}$file
    chroot #{guest_root} ln -s /var/spool/cloud $file
  EOH
end
rs_utils_marker :end
