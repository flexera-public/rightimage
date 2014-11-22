#
# Cookbook Name:: rightimage_tester
# Recipe:: special_strings 
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

file "/tmp/badfiles" do
  backup false
  action :delete
end

bash "Check for special strings" do
  flags "-ef"
  code <<-EOH
# NOTES: CentOS 5.x ships with grep 2.5.1 which doesn't support --exclude-dir (2.5.3+)
# egrep doesn't return the matched files for some reason.. using grep -E instead...

# List of search strings, this is a regular expression so don't forget
# to | the strings
regexp="\
BEGIN RSA PRIVATE KEY|\
BEGIN CERTIFICATE|\
#{node[:rightimage_tester][:aws_access_key_id]}|\
#{node[:rightimage_tester][:aws_secret_access_key]}"

# List of directories to ignore.
skip_dirs=(
/dev
/etc/pki
/etc/ssh
/etc/ssl
/home/ec2
/lib
/lib64
/proc
/root/.npm
/sys
/usr/java
/usr/lib
/usr/lib64
/usr/local/lib
/usr/share/doc
/var/cache/rightscale
/var/lib/rightscale/right_link/certs
/var/lib/ureadahead
/usr/local/gsutil
/usr/local/gcutil
/usr/share
/var/lib/gems
/var/lib/ureadahead
/usr/local/lib/python2.7/dist-packages/boto
/usr/local/share/gems
/opt/rightscale/sandbox/lib/ruby
/opt/rightscale/right_link/certs
/opt/rightscale/right_link/lib/instance/cook
/opt/rightscale/sandbox/man
/opt/rightscale/sandbox/ssl/man
)

# List of files to ignore.
skip_files=(
)

# Ignore this script during the search
skip_files=( "${skip_files[@]}" "$0" )

# Prepend exclusion
skip_dirs=( "${skip_dirs[@]/#/-not -path #{node[:rightimage_tester][:root]}}" )
# Append /*
skip_dirs=( "${skip_dirs[@]/%//*}" )

# Prepend exclusion
skip_files=( "${skip_files[@]/#/-not -path }" )

echo "Going to search entire file system for $regexp, but \
${skip_dirs[@]} ${skip_files[@]}"

set +ex
# No -e as we want to control error exiting; grep will exit non-zero if anything is found.

# Massive grep on all files looking for suspicious strings.
# --devices=skip
#   skip means that devices, FIFOs and sockets are silently skipped.
# --binary-files=without-match
#   assumes that a binary file does not match so skips it.
find #{node[:rightimage_tester][:root]} -type f ${skip_dirs[@]} ${skip_files[@]} -exec grep -E --ignore-case --files-with-matches --devices=skip \
      --directories=recurse --no-messages  \
      --binary-files=without-match --regexp="$regexp" {} + > /tmp/badfiles
[ "$?" == "127" ] && echo "grep didn't run" && exit 1

if [ -s /tmp/badfiles ]; then
  echo "Warning: found suspicious strings. Output in /tmp/badfiles"
  cat /tmp/badfiles
  if [ "#{node[:rightimage_tester][:run_static_tests]}" == "true" ]; then
    exit 1
  fi
  exit 0
else
  echo "No suspicious strings found."
  exit 0
fi
  EOH
end

rightscale_marker :end
