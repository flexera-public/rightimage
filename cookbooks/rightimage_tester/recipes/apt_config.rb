#
# Cookbook Name:: rightimage_tester
# Recipe:: apt_config 
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

bash "apt config" do
  only_if { node[:platform] == "ubuntu" }
  flags "-ex"
  code <<-EOH
    opt=0
    eval $(apt-config shell opt APT::Install-Recommends)
    if [ -z $opt ]; then echo "Invalid options: APT::Install-Recommends"; exit 1; fi
    if [ $opt -eq 1 ]; then echo "ERROR: wrong setting for APT::Install-Recommends"; exit 1; fi
  EOH
end

rightscale_marker :end
