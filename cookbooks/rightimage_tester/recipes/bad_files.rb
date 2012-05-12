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
  code <<-EOH
# No -x as the script outputs what it's doing
# No -e as we want to control error exiting

# TODO: Force continue on failure until refactor is done to test on raw image.
CONTINUE_ON_FAILURE="true"

# The find command is used to search for suspicious files, so anything that is
# supported by find can be used here (e.g -name /path/filename or -name *.ext).
# Don't forget to put -or between the checks and a space after each line
# before the breakline char (apart from the last line).
bad_files="\
-name *.deb -or \
-name *.swp -or \
-name *.git -or \
-name *.svn -or \
-name *.ssh\
"

# List of directories to check for emptiness. The dir and its sub-dirs are
# searched for files.
empty_dirs="\
/var/log \
/var/spool/postfix \
/var/mail\
"

test_passed=true
logger -s -t RightScale "Going to search for these suspicious files: $bad_files"

find_results=`find / \\( -path /var/cache/rightscale -o -path /root/.rightscale \\) -prune -o -size +0 -type f \\( $bad_files \\) -print`
if [ -n "$find_results" ]; then
  logger -s -t RightScale "Warning: found these suspicious files: $find_results"
  test_passed=false
fi

logger -s -t RightScale "Going to check these dirs for emptiness: $empty_dirs"

# Ignore this script during the next search (as it will be in /var/cache)
this_file=`basename $0`
for current_dir in $empty_dirs
do
  find_results=`find $current_dir -type f ! -name "$this_file*"`
  if [ -n "$find_results" ]; then  
    logger -s -t RightScale "Warning: $current_dir is not empty, it has: \
      $find_results"
    test_passed=false
  fi
done

if ! $test_passed ; then
  logger -s -t RightScale "Test failed but check the output, it might be ok."
  if [[ "$CONTINUE_ON_FAILURE" == "true" ]] || [[ "$CONTINUE_ON_FAILURE" == "True" ]]; then
    exit 0
  fi
  exit 1
fi

logger -s -t RightScale "No suspicious files found."
  EOH
end

rightscale_marker :end
