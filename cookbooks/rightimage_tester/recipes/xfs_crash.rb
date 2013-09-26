#
# Cookbook Name:: rightimage_tester
# Recipe:: xfs_crash
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

bash "XFS crash bug detect" do
  only_if { node[:platform] == "centos" && node[:cloud][:provider] == "ec2" }
  flags "-ex"
  code <<-EOH

yum -y install xfsprogs

device=/dev/loop0
loopback_file=/root/loopfile
test_dir=/mnt/xfs_test

dd if=/dev/zero of=$loopback_file bs=1024 count=30720

set +e
losetup -d $device
set -e

losetup $device $loopback_file
mkfs.xfs -l version=2 -f $device

[ ! -d $test_dir ] && mkdir $test_dir

echo "Attempting to mount and test an xfs volume-- may trigger panic"

mount $device $test_dir
cd $test_dir
touch file
rm file
cd /

umount $test_dir
rm -f $loopback_file
rm -rf $test_dir
losetup -d $device

  EOH
end

rightscale_marker :end
