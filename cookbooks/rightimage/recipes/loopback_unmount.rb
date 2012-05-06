#
# Cookbook Name:: rightimage
# Recipe:: loopback_unmount
#
# Copyright 2012, RightScale, Inc.
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

# Clean up guest image
rightimage guest_root do
  action :sanitize
end

loopback_fs loopback_file(partitioned?) do
  mount_point guest_root
  action :unmount
end

rightscale_marker :end
