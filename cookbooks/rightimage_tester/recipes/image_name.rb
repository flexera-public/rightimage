#
# Cookbook Name:: rightimage_tester
# Recipe:: image_name 
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

ruby_block "Verify arch in image name" do
  only_if { node[:cloud][:provider] == "ec2" && node[:ec2][:ami_manifest_path] != "(unknown)" }
  block do
    if `uname -m` =~ /64/
       target_string = "x64"
    else
       target_string = "i386"
    end
    
    unless node[:ec2][:ami_manifest_path].include? target_string
      Chef::Log.info "did not find the appropriate arch value in the image name"
      Kernel.exit 1
    end
  end
end

ruby_block "Verify distro in image name" do
  only_if { node[:cloud][:provider] == "ec2" && node[:ec2][:ami_manifest_path] != "(unknown)" }
  block do
    case node[:platform]
    when "centos"
      target_string = "CentOS"
    when "redhatenterpriseserver"
      target_string = "RHEL"
    when "ubuntu"
      target_string = "Ubuntu"
    end
    
    unless node[:ec2][:ami_manifest_path].include? target_string
      Chef::Log.info "did not find the appropriate distro value in the image name"
      Kernel.exit 1
    end
  end
end

rightscale_marker :end
