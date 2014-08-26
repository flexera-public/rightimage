#
# Cookbook Name:: rightimage_tester
# Recipe:: sftp 
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

# Ensure SSH test has run that generated the SSH key to use here.
include_recipe "rightimage_tester::ssh"

bash "Verify SFTP" do
  flags "-x"
  code <<-EOH
    # Verify path in sshd config is correct.
    path=`grep sftp /etc/ssh/sshd_config |  awk '{ print $3 }'`
    if [ ! -f "$path" ]; then
      echo "SSHd config points to invalid path: $path";
      exit 1
    fi

    # Test SFTP.
    set -e
    echo "blah" > /tmp/sftptest
    scp -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa_tester /tmp/sftptest localhost:/tmp/sftptest2
    set +e

    # Should have errored out if an issue, but double-check that file is there.
    if [ ! -f /tmp/sftptest2 ]; then
      echo "SFTP test file did not arrive."
      exit 1
    fi
  EOH
end
