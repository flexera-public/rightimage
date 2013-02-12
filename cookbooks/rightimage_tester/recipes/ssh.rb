#
# Cookbook Name:: rightimage_tester
# Recipe:: ssh 
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

directory "/root/.ssh" do
  owner "root"
  group "root"
  mode "0700"
  action :create
end 

bash "Create keys" do
  not_if "test -f /root/.ssh/id_rsa_tester"
  flags "-ex"
  code <<-EOH
    # Generate unique key (w-5395)
    ssh-keygen -b 1024 -f /root/.ssh/id_rsa_tester -N '' -q -t rsa

    # Add key to authorized_keys to allow connections to self
    echo "" >> /root/.ssh/authorized_keys # Ensure new-line before adding
    cat /root/.ssh/id_rsa_tester.pub >> /root/.ssh/authorized_keys
  EOH
end

bash "Test ssh" do
  flags "-ex"
  code <<-EOH
    ssh -t -t -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa_tester localhost tty
  EOH
end

bash "Test ssh part 2" do
  only_if { node[:cloud][:provider] == "ec2" }
  flags "-ex"
  code <<-EOH
    # Make sure that the RS bash special sauce is in the ENV for non-interactive
    # shells.  This is required for bundling images via the dashboard.
    case "#{node[:platform]}" in
      suse*)
        #
        # SLES Doesn't set EC2_HOME but the EC2 tools are installed
        #
        ssh -i /root/.ssh/id_rsa_tester localhost -C 'ec2-instance-id || exit 1'
        ;;
      *) 
        ssh -i /root/.ssh/id_rsa_tester localhost -C 'if [[ -z "$EC2_HOME" ]]; then exit 1; fi'
        ;;
    esac
  EOH
end

rightscale_marker :end
