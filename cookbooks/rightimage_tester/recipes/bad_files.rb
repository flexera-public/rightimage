#
# Cookbook Name:: rightimage_tester
# Recipe:: bad_files 
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

bash "Check for bad files" do
  # Avoid wildcard glob on bad_files
  cwd "/tmp"
  code <<-EOH
# No -x as the script outputs what it's doing
# No -e as we want to control error exiting

# The find command is used to search for suspicious files, so anything that is
# supported by find can be used here (e.g -name /path/filename or -name *.ext).
# Don't forget to put -or between the checks and a space after each line
# before the breakline char (apart from the last line).
bad_files="\
-name *.chef* -or \
-name *.deb -or \
-name *.swp -or \
-name *.git -or \
-name *.svn -or \
-name *.ssh\
"
bad_files_skip_dirs="\
-path #{node[:rightimage_tester][:root]}/usr/lib/node_modules -or \
-path #{node[:rightimage_tester][:root]}/var/cache/rightscale -or \
-path #{node[:rightimage_tester][:root]}/root/.rightscale\
"


# List of directories to check for emptiness. The dir and its sub-dirs are
# searched for files.
empty_dirs="\
#{node[:rightimage_tester][:root]}/var/log \
#{node[:rightimage_tester][:root]}/var/spool/postfix \
#{node[:rightimage_tester][:root]}/var/mail\
"

test_passed=true
echo "Going to search for these suspicious files: $bad_files"

find_results=`find #{node[:rightimage_tester][:root]}/ \\( $bad_files_skip_dirs \\) -prune -o -size +0 -type f \\( $bad_files \\) -print`
if [ -n "$find_results" ]; then
  echo "Warning: found these suspicious files: $find_results"
  test_passed=false
fi

echo "Going to check these dirs for emptiness: $empty_dirs"

# Ignore this script during the next search (as it will be in /var/cache)
this_file=`basename $0`
for current_dir in $empty_dirs
do
  find_results=`find $current_dir -size +0 -type f ! -name "$this_file*"`
  if [ -n "$find_results" ]; then  
    echo "Warning: $current_dir is not empty, it has: \
      $find_results"
    test_passed=false
  fi
done

if ! $test_passed ; then
  if [ "#{node[:rightimage_tester][:run_static_tests]}" == "true" ]; then
    exit 1
  fi
  echo "Test failed but check the output.  If this test was run on a booted instance these files may be normal."
  exit 0
fi

echo "No suspicious files found."
  EOH
end

rightscale_marker :end
