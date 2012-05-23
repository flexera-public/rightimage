#
# Cookbook Name:: rightimage_tester
# Recipe:: dupe_mounts 
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

ruby_block "Check for duplicate mounts" do
  block do
    # create some arrays to keep track of what devices and mount points we have
    # seen and query the mount command
    devices = Array.new
    mount_points = Array.new
    mounts = `mount`.split "\n"
    
    # simple function to print out an error message and exit
    def error_and_exit(dup)
      return if dup == "none"
      Chef::Log.info "#########################"
      Chef::Log.info "ERROR: #{dup} is mounted twice!!!"
      Chef::Log.info "#########################"
      exit 1
    end
    
    # iterate through each line returned by the mount command and check to 
    # see if we have seen a device or mount point befeore. Exit if so
    mounts.each do |line| 
      elements = line.split 
      error_and_exit elements[0] if devices.include? elements[0]
      error_and_exit elements[2] if mount_points.include? elements[2]
      devices.push elements[0]
      mount_points.push elements[2]
    end
  end
end

rightscale_marker :end
