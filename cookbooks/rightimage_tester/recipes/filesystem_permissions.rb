#
# Cookbook Name:: rightimage_tester
# Recipe:: filesystem_permissions
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

rightimage_tester "Verify postfix permissions" do
  cmd = value_for_platform(
    /suse/i => { "default" => 'find /var/spool/postfix -group maildrop' },
    "default" => 'find /var/spool/postfix -group postdrop'
  )
  command cmd
  action :test
end

temp_perms="1777"
rightimage_tester "Verify /tmp permissions = #{temp_perms}" do
  command "perms=$(stat --format=%a /tmp) && echo \"PERMS: $perms\"; [ \"$perms\" == \"#{temp_perms}\" ]"
  action :test
end

file = ((File.symlink?"/etc/resolv.conf") ? "/run/resolvconf/resolv.conf" : "/etc/resolv.conf")
resolv_perms="644"
rightimage_tester "Verify resolv.conf permissions = #{resolv_perms}" do
  command "perms=$(stat --format=%a #{file}) && echo \"PERMS: $perms\"; [ \"$perms\" == \"#{resolv_perms}\" ]"
  action :test
end

rightscale_marker :end
