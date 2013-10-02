#
# Cookbook Name:: rightimage_tester
# Recipe:: benchmark 
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
# WITHOUT WARRANTIES OR CONDITIONS ßOF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

rightscale_marker :begin

node.set[:sysbench][:result_file]   = node[:rightimage_tester][:benchmark_results_file]
node.set[:sysbench][:instance_type] = node[:rightimage_tester][:instance_type]


include_recipe "sysbench"
include_recipe "sysbench::run"

rightscale_marker :end


