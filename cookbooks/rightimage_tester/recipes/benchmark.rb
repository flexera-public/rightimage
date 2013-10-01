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

benchmark_results_file = "/tmp/result.json"
node.set[:sysbench][:result_file] = benchmark_results_file

include_recipe "ros_upload"
include_recipe "sysbench"
include_recipe "sysbench::run"

report_name = node[:rightimage_tester][:report_name].dup
report_name << ".json" unless report_name.include?('.json')

ros_upload benchmark_results_file do
  provider "ros_upload_s3"
  user node[:rightimage_tester][:aws_access_key_id]
  password node[:rightimage_tester][:aws_secret_access_key]
  container "rightimage-benchmarks"
  remote_path report_name
  action :upload
end
