#
# Cookbook Name:: rightimage_tester
# Recipe:: ntp 
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

# w-5970 - liblockfile has a bug resulting in ntp restart to fail on instances
# where the hostname is too long (>36 chars) which might occur somewhat commonly
# on openstack and rackspace instances.  We use a patched version. 
# Also ntp service should exist and be running, rightlink is dependent.
# https://bugs.launchpad.net/ubuntu/+source/liblockfile/+bug/941968/comments/30
rightimage_tester 'Restart ntp service' do
  ntp_service = value_for_platform(
    'ubuntu' => { 'default' => 'ntp' },
    'default' => 'ntpd'
  )
  command "service #{ntp_service} restart"
  action :test
end