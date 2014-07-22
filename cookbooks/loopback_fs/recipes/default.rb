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

if platform_family?("rhel")
  if node[:platform_version].to_i == 6
    remote_file "/tmp/qemu-common.rpm" do
      source "http://rightscale-rightimage.s3.amazonaws.com/packages/el6/qemu-common-0.12.3-8.el6.x86_64.rpm"
      not_if "which qemu-nbd"
      notifies :install, "package[install qemu common]", :immediately
    end

    package "install qemu common" do
      source "/tmp/qemu-common.rpm"
      only_if { ::File.exists?("/tmp/qemu-common.rpm") }
      action :nothing
    end
  elsif node[:platform_version].to_i == 7
    package "qemu-common"
  end
end


if platform_family?("rhel")
  if node[:platform_version].to_i == 6
    package_path = "/packages/el6/kmod-nbd-0.1-1.onapp.el6.x86_64.rpm"
  elsif node[:platform_version].to_i == 7
    package_path = "/packages/el7/kmod-nbd-0.1-1.el7.x86_64.rpm"
  end
  remote_file "/tmp/kmod-nbd.rpm" do
    source node[:rightimage][:s3_base_url] + package_path
    not_if { ::File.exists?("/dev/nbd0") }
    notifies :install, "package[install kmod nbd]", :immediately
  end

  package "install kmod nbd" do
    source "/tmp/kmod-nbd.rpm"
    only_if { ::File.exists?("/tmp/kmod-nbd.rpm") }
    action :nothing
  end
end
