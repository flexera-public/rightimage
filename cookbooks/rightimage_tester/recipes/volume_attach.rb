#
# Cookbook Name:: rightimage_tester
# Recipe:: volume_attach 
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

rightscale_marker :begin

options_hash = {}
options_hash.merge!(volume_type: 'thin') if node[:cloud][:provider] == "vsphere"

rightscale_volume "volume" do
  options options_hash
  size node['cloud']['provider'] == "rackspace" ? 100:1
  action :create
end

rightscale_volume "volume" do
  action :attach
end

rightscale_volume "volume" do
  action [ :detach, :delete ]
end

rightscale_marker :end
