#
# Cookbook Name:: rightimage_tester
# Recipe:: blank_passwords 
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

ruby_block "Ensure no blank passwords" do
  block do
    def error_and_exit(user)
      Chef::Log.info "######################"
      Chef::Log.info "User: #{user} does not have a password set!!!"
      Chef::Log.info "######################"
      Kernel.exit 1
    end
    
    File.open("/etc/shadow","r") do |shadow_file|
      while line = shadow_file.gets
        line_array = line.split ":"
        error_and_exit line_array[0] if line_array[1] == ""    
      end
    end
  end
end

rightscale_marker :end
