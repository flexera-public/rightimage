#
# Cookbook Name:: loopback
# Recipe:: default
#
# Copyright 2012, RightScale, Inc.
#

packages = value_for_platform(
  "ubuntu" => {"default" => %w(kpartx qemu-utils)},
  "default" => %w(qemu-img)
)

packages.each do |p| 
  package p
end

remote_file "/tmp/qemu-common.rpm" do
  source "http://rightscale-rightimage.s3.amazonaws.com/packages/el6/qemu-common-0.12.3-8.el6.x86_64.rpm"
  not_if "which qemu-nbd"
  only_if { el6? }
  notifies :install, "package[install qemu common]", :immediately
end

package "install qemu common" do
  source "/tmp/qemu-common.rpm"
  only_if { ::File.exists?("/tmp/qemu-common.rpm") }
  action :nothing
end

remote_file "/tmp/kmod-nbd.rpm" do
  source "http://rightscale-rightimage.s3.amazonaws.com/packages/el6/kmod-nbd-0.1-1.onapp.el6.x86_64.rpm"
  not_if { ::File.exists?("/dev/nbd0") || !el6? }
  notifies :install, "package[install kmod nbd]", :immediately
end

package "install kmod nbd" do
  source "/tmp/kmod-nbd.rpm"
  only_if { ::File.exists?("/tmp/kmod-nbd.rpm") }
  action :nothing
end