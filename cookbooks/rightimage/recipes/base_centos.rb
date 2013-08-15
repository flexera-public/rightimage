rs_utils_marker :begin
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

node[:rightimage][:host_packages].split.each { |p| package p }

include_recipe "rightimage::clean"
include_recipe "rightimage::rightscale_install"

## Required for OS to automatically update grub.conf upon installation of new kernel (w-4932) ##
remote_file "#{guest_root}/etc/sysconfig/kernel" do
  source "sysconfig-kernel"
  backup false
end

# Make sure that sendmail is set to run on startup.
execute "chroot #{guest_root} chkconfig --add sendmail"

rs_utils_marker :end
