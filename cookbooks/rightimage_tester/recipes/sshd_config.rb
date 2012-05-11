#
# Cookbook Name:: rightimage_tester
# Recipe:: sshd_config
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

config = "/etc/ssh/sshd_config"

rightimage_tester "Verify SSHd security settings" do
  only_if { node[:rightimage_tester][:test_ssh_security] == "true" }
  command "config=\"#{config}\" && egrep -H \"^PermitRootLogin without-password\" $config && egrep -H \"^PasswordAuthentication no\" $config"
  action :test
end

rightimage_tester "Verify SSHd security settings - Rhosts" do
  command "config=\"#{config}\" && egrep -H \"^IgnoreRhosts no\" $config && exit 1 || exit 0"
  action :test
end

rightscale_marker :end
