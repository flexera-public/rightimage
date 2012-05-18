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

class Chef::Recipe
  include RightScale::RightImage::Helper
end

node[:rightimage_tester][:root] = guest_root
node[:rightimage_tester][:run_static_tests] = true
node[:rightimage_tester][:aws_access_key_id] = node[:rightimage][:aws_access_key_id]
node[:rightimage_tester][:aws_secret_access_key] = node[:rightimage][:aws_secret_access_key]

include_recipe "rightimage_tester::bad_files"
include_recipe "rightimage_tester::special_strings"

rightscale_marker :end
