#
# Cookbook Name:: rightimage
# Recipe:: setup_or_restore
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

# TODO: Have to hard-code for now because block_device inputs aren't available.
unless File.exists?("/mnt/storage")
  if node[:rightimage][:build_mode] == "full"
    include_recipe "block_device::do_restore"
  else
    include_recipe "block_device::setup_block_device"
  end
end
