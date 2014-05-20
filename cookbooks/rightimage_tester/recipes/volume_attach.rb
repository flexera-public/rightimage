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

volume_name = "volume"
temp_directory = "/tmp/volume"

unless node['virtualization']['system'] == "vmware"
  directory temp_directory do
    action :create
  end 
  
  package "lvm2" if node[:platform] == "ubuntu"
end

ruby_block "create volume" do
  not_if { node['virtualization']['system'] == "vmware" }
  block do

    require 'rubygems'
    require 'rightscale_tools'
  
    handle = RightScale::Tools::BlockDevice.factory(:lvm, node['cloud']['provider'].to_sym, temp_directory, volume_name, node[:rightscale][:instance_uuid], {:disable_backup_options=>true})

    volume_opts = { :stripe_count => 1, :vg_data_percentage => 80, :volume_size => 1 }
    if node['cloud']['provider'] =~ /rackspace/
      volume_opts[:volume_size] = 100
      volume_opts[:volume_type] = "SATA"
    end

    Chef::Log.info("Creating volume #{volume_name}")
    handle.create(volume_opts)

    Chef::Log.info("Detatching volume #{volume_name}")
    handle.reset
  end
end

rightscale_marker :end
