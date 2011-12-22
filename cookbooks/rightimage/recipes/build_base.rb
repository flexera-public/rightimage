#
# Cookbook Name:: rightimage
# Recipe:: build_base
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

include_recipe "rightimage::setup_loopback"
include_recipe "rightimage::bootstrap_#{node[:platform].downcase}"
include_recipe "rightimage::bootstrap_common"
include_recipe "rightimage::copy_image"
include_recipe "rightimage::do_destroy_loopback"
include_recipe "rightimage::do_backup"
include_recipe "rightimage::base_upload"
