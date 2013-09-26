#
# Cookbook Name:: rightimage_tester
# Recipe:: crontab 
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

ruby_block "Verify crontab has a newline" do
  block do
    crontab = `tail -n 1 /etc/crontab`
    
    unless crontab[-1] == 10 || crontab[-1] == "\n"
      Chef::Log.info "************************************************"
      Chef::Log.info "*** ERROR: /etc/crontab does not end in a newline!!!"
      Chef::Log.info "************************************************"
      exit 1 
    end
  end
end

rightscale_marker :end
