#
# Cookbook Name:: rightimage_tester
# Recipe:: reboot 
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

bash "Test reboot" do
  flags "-ex"
  code <<-EOH
#set up a script to wait and reboot
cat << EOF > /root/reboot.sh
#!/bin/bash 
sleep 30
init 6
EOF
chmod +x /root/reboot.sh

if test -e /root/reboot2 ; then
  echo already rebooted twice. Continuing...
else 
  if test -e /root/reboot1 ; then
    echo already rebooted once. Rebooting again...
    touch /root/reboot2
    nohup /root/reboot.sh &
  else
    echo About to reboot for the first time...
    touch /root/reboot1
    nohup /root/reboot.sh &
  fi
fi
  EOH
end

rightscale_marker :end
