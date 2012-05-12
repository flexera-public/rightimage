#
# Cookbook Name:: rightimage_tester
# Recipe:: ephemeral 
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

ruby_block "ensure ephemeral mounted" do
  only_if { node[:cloud][:provider] == "ec2" && node[:ec2][:instance_type] != "t1.micro" && node[:platform] != /suse/ }
  block do
    unless `mount | grep " on /mnt "` =~ /\/dev\/(sd|xvd)/
      Chef::Log.info "***********************************************************"
      Chef::Log.info "*** ERROR: do not see the ephemeral 0 drive mounted on /mnt"
      Chef::Log.info "***********************************************************"
      exit 1
    end
  end
end

rightscale_marker :end
