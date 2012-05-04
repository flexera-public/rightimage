#
# Cookbook Name:: rightimage_tester
# Recipe:: java
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

rs_utils_marker :begin

dependencies = %w{vim ssh cron}
cmd = value_for_platform(
  /suse/i => { "default" => 'zypper search -i' },
  "ubuntu" => { "default" => 'dpkg-query -W' },
  "default" => 'rpm -qa'
)

dependencies.each do |package|
  rightimage_tester "Verify dependency installed: #{package}" do
    command "#{cmd} *#{package}* | grep #{package}"
    action :test
  end
end

rs_utils_marker :end
