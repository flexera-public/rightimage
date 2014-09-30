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
class Chef::Resource::RubyBlock
  include Chef::Mixin::ShellOut
end

package "e2fsprogs"

rightscale_volume "volume" do
  only_if { node[:rightimage][:volume_size] && !mounted? }
  size node[:rightimage][:volume_size].to_i
  action :create
end

rightscale_volume "volume" do
  only_if { node[:rightimage][:volume_size] && !mounted? }
  action :attach
end

ruby_block "format volume" do
  only_if { node[:rightimage][:volume_size] && !mounted? }
  block do
    volume_device = node['rightscale_volume']['volume']['device']
    shell_out!("mkfs.ext4 -F #{volume_device}")
  end
end

directory target_raw_root do
  action :create
end

ruby_block "mount volume" do
  only_if { node[:rightimage][:volume_size] && !mounted? }
  block do
    volume_device = node['rightscale_volume']['volume']['device']
    shell_out!("mount #{volume_device} #{target_raw_root}")
  end
end

rightscale_marker :end
