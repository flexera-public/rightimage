#
# Cookbook Name:: rightimage_tester
# Recipe:: ldconfig
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

bash "Verify ldconfig runs" do
  flags "-e"
  code <<-EOH
    ldconfig=$(ldconfig 2>&1)
    res=$?

    # ldconfig will still exit 0 in the case of I/O errors loading libraries (IV-1382)
    if [ "$res" == "0" ]; then
      set +e
      echo "$ldconfig" | grep "error"
      res2=$?
      set -e

      if [ "$res2" == "0" ]; then
        exit 1
      else
        exit 0
      fi
    else
      # This shouldn't get called if -e flag is on.
      exit $res
    fi
  EOH
end

rightscale_marker :end
