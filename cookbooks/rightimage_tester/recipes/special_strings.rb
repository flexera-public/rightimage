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

el = ((node[:platform] == "centos" || node[:platform] == "redhatenterpriseserver") && node[:platform_version].to_i < 6 )
grep_bin = (el ? "/tmp/grep/bin/grep" : "grep")

file "/tmp/badfiles" do
  action :delete
end

directory "/tmp/grep" do
  only_if { el }
  action :create
end 

cookbook_file "/tmp/grep/grep.rpm" do
  only_if { el }
  source "grep-2.5.3-1.x86_64.rpm"
  backup false
end

execute "rpm2cpio /tmp/grep/grep.rpm | cpio -id" do
  only_if { el }
  cwd "/tmp/grep"
  creates "/tmp/grep/bin/grep"
end

bash "Check for special strings" do
  flags "-e"
  code <<-EOH
# No -x as the script outputs what it's doing
shopt -s nocasematch

grep_bin=#{grep_bin}

# NOTES: CentOS 5.x ships with grep 2.5.1 which doesn't support --exclude-dir (2.5.3+)
# egrep doesn't return the matched files for some reason.. using grep -E instead...

# List of search strings, this is a regular expression so don't forget
# to | the strings
regexp="\
BEGIN RSA PRIVATE KEY|\
#{node[:rightimage_tester][:aws_access_key_id]}|#{node[:rightimage_tester][:aws_secret_access_key]}"

# List of directories to ignore.
skip_dirs=(
/dev
/etc/ssh
/etc/ssl
/lib
/lib64
/opt/rightscale/certs
/opt/rightscale/right_link/certs
/opt/rightscale/sandbox/lib/ruby/gems/1.8/gems
/opt/rightscale/sandbox/man
/proc
/root/.ssh
/sys
/tmp/rubygems/test
/usr/lib
/usr/lib64
/usr/share/doc
/var/cache/rightscale
/var/lib/rightscale/right_link/certs
/var/lib/ureadahead
)

# List of files to ignore.
skip_files=(
/tmp/id_rsa
/var/log/decommission
/var/log/install
/var/log/messages
/var/log/syslog
/var/log/user.log
)

# Ignore this script during the search
skip_files=( "${skip_files[@]}" "$0" "$0.rb" )

for (( i=0; i<${#skip_dirs[@]}; i++ ))
do
 skip_dir="$skip_dir --exclude-dir=${skip_dirs[$i]}"
done

for (( i=0; i<${#skip_files[@]}; i++ ))
do
 skip_file="$skip_file --exclude=`basename ${skip_files[$i]}`"
done

logger -s -t RightScale "Going to search entire file system for $regexp, but \
${skip_dirs[@]} ${skip_files[@]}"

set +ex
# No -e as we want to control error exiting; grep will exit non-zero if anything is found.

# Massive grep on all files looking for suspicious strings.
# --devices=skip
#   skip means that devices, FIFOs and sockets are silently skipped.
# --binary-files=without-match
#   assumes that a binary file does not match so skips it.
$grep_bin -E --ignore-case --files-with-matches --devices=skip \
      --directories=recurse --no-messages $skip_dir $skip_file \
      --binary-files=without-match --regexp="$regexp" / > /tmp/badfiles
[ "$?" == "127" ] && logger -st RightScale "grep didn't run" && exit 1

if [ -s /tmp/badfiles ]; then
  logger -s -t RightScale "Warning: found suspicious strings. Output in /tmp/badfiles"
  cat /tmp/badfiles
  if [ "$CONTINUE_ON_FAILURE" == "true" ]; then
    exit 0
  fi
  exit 1
else
  logger -s -t RightScale "No suspicious strings found."
  exit 0
fi

logger -s -t RightScale "/tmp/badfiles doesn't exist.. hmm?"
exit 1
  EOH
end

rightscale_marker :end
