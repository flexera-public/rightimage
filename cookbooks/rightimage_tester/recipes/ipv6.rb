#
# Cookbook Name:: rightimage_tester
# Recipe:: ipv6 
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

rightimage_tester "Verify IPv6 disabled" do
  command 'ifconfig lo | grep inet6; if [ "$?" == "0" ]; then exit 1; else exit 0; fi'
  action :test
end

rightscale_marker :end
