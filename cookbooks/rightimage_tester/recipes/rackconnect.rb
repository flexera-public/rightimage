#
# Cookbook Name:: rightimage_tester
# Recipe:: rackconnect 
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

bash "rackconnect" do
  only_if { node[:cloud][:provider] == "rackspace-ng" }
  code <<-EOH
    # Check if RackConnect is enabled on the account.
    xenstore-read vm-data/provider_data/roles | grep "rack_connect"

    if [ $? -eq 0 ]; then
      # RackConnect is enabled, so the rackconnect user should exist.
      id rackconnect

      if [ $? -eq 0 ]; then
        echo "Rackspace automation appears to have SUCCEEDED"
        exit 0
      else
        echo "Rackspace automation appears to have FAILED (rackconnect user does not exist)"
        exit 1
      fi
    else
      echo "RackConnect is not enabled on this account"
      exit 0
    fi
  EOH
end

rightscale_marker :end
