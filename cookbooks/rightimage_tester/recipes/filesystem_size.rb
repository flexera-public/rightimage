#
# Cookbook Name:: rightimage_tester
# Recipe:: filesystem_size
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

# EBS images end up at 7.9GB due to adding a swap partition
bash "Verify root filesystem size" do
  flags "-ex"
  code <<-EOH
    size=$(df -P /|grep /|awk '{print $2}')
    echo "SIZE: $size"

    # Input set in GB. Give a leeway of 2GB each way. Convert input to GB.
    test_size="#{node[:rightimage_tester][:root_size]}"
    if [ -z "$test_size" -o "$test_size" == "0" ]; then
      echo "Root filesystem size set to 0.  Skipping test"
    else
      test_size_lower="$(($test_size - 2))"
      test_size_upper="$(($test_size + 2))"
      [ "$size" -ge ${test_size_lower}000000 ] && [ "$size" -le ${test_size_upper}000000 ]
    fi
  EOH
end

rightscale_marker :end
