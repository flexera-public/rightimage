#
# Cookbook Name:: rightimage_tester
# Recipe:: bashrc 
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

bash "Verify bashrc is sourced" do
  flags "-ex"
  code <<-EOH
# SLES is a special case here
#
if [[ "#{node[:platform]}" = *suse* ]]; then
  [ -f "/etc/bash.bashrc" ] || exit 1
  exit 0  
fi

# generate a random number and from that, a random variable name
random_number=$RANDOM
random_variable=var${random_number}

# append that random variable name and number to the global bashrc
echo "${random_variable}=${random_number}" >> /etc/bashrc

# exit if there is no /root/.bashrc; source otherwise
if test ! -f /root/.bashrc; then 
  echo "###############################################"
  echo /root/.bashrc does not exist
  echo "###############################################"
  exit 1
fi

# fake like we have an interactive shell
export PS1="foo"

cat <<"EOF" >>/usr/local/bin/source_bashrc_test
#!/bin/bash -ex
source /root/.bashrc
# bail if we can't read the variable that we inserted into /etc/bashrc
if test ! "${!random_variable:-123456789}" -eq "$random_number" ; then 
  echo "###############################################"
  echo /root/.bashrc is not sourcing /etc/bashrc
  echo "###############################################"
  exit 1
fi
EOF

chmod +x /usr/local/bin/source_bashrc_test

cat <<"EOF" >>/usr/local/bin/daemonize
#!/bin/sh

cd /
( exec "/usr/local/bin/source_bashrc_test" <&- >&- 2>&- )&
EOF

chmod +x /usr/local/bin/daemonize
/usr/local/bin/daemonize
  EOH
end

rightscale_marker :end
