#
# Cookbook Name:: rightimage
# Recipe:: default
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

lineage_split = node[:block_device][:lineage].split("_")
node[:rightimage][:platform] = lineage_split[0]
node[:rightimage][:release] = lineage_split[1]
node[:rightimage][:arch] = lineage_split[2]
node[:rightimage][:timestamp] = lineage_split[3]
node[:rightimage][:build] = lineage_split[4] if lineage_split[4]

unless node[:rightimage][:manual_mode] == "true"
  if node[:rightimage][:install_mirror_date]
    include_recipe "rightimage::build_image"
  else
    node[:rightimage][:install_mirror_date] = node[:rightimage][:timestamp]
    include_recipe "rightimage::build_base"
  end
end
