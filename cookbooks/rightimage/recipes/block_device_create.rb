# Cookbook Name:: rightimage
#
# Copyright (c) 2011 RightScale Inc
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
rightscale_marker :begin

class Chef::Recipe
  include RightScale::RightImage::Helper
end
class Chef::Resource::BlockDevice
  include RightScale::RightImage::Helper
end

# the mounted? check can't be in a not_if, it errors out Marshal.dump->node 
# when the persist flag is set because its can't serialize the Proc
if mounted?
  Chef::Log::info("Block device already mounted")
else
  block_device ri_lineage do
    cloud "ec2"
    mount_point target_raw_root
    vg_data_percentage "95"
    max_snapshots "1000"
    keep_daily "1000"
    keep_weekly "1000"
    keep_monthly "1000"
    keep_yearly "1000"
    volume_size "23"
    stripe_count "1"
    lineage ri_lineage
    action :create
    persist true
  end
end

rightscale_marker :end
