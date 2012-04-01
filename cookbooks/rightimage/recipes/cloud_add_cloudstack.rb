rs_utils_marker :begin
#
# Cookbook Name:: rightimage
# Recipe:: cloud_add_cloudstack
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



class Chef::Resource
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end
class Erubis::Context
  include RightScale::RightImage::Helper
end


include_recipe "cloud_add_begin"

rightimage_hypervisor "Install PV kernel for hypervisor" do
  provider "rightimage_hypervisor_#{node[:rightimage][:virtual_environment]}"
  action :install_kernel
end

rightimage_hypervisor "Install software toolchain for hypervisor" do
  provider "rightimage_hypervisor_#{node[:rightimage][:virtual_environment]}"
  action :install_tools
end

bash "configure for cloudstack" do
  flags "-ex" 
  code <<-EOH
    guest_root=#{guest_root}

    case "#{node[:rightimage][:platform]}" in
    "ubuntu")
      case "#{node[:rightimage][:virtual_environment]}" in
      "xen")
        # enable console access
        cp $guest_root/etc/init/tty1.conf* $guest_root/etc/init/hvc0.conf
        sed -i "s/tty1/hvc0/g" $guest_root/etc/init/hvc0.conf
        echo "hvc0" >> $guest_root/etc/securetty

        for i in $guest_root/etc/init/tty*; do
          mv $i $i.disabled;
        done
        ;;
      "kvm"|"esxi")
        # Disable all ttys except for tty1 (console)
        for i in `ls $guest_root/etc/init/tty[2-9].conf`; do
          mv $i $i.disabled;
        done
        ;;
      esac
    "centos"|"rhel")
      # clean out packages
      chroot $guest_root yum -y clean all

      # clean centos RPM data
      rm -rf ${guest_root}/var/lib/rpm/__*
      chroot $guest_root rpm --rebuilddb

      # configure dhcp timeout
      echo 'timeout 300;' > $guest_root/etc/dhclient.conf

      case "#{node[:rightimage][:virtual_environment]}" in
      "xen")
        # enable console access
        echo "2:2345:respawn:/sbin/mingetty xvc0" >> $guest_root/etc/inittab
        echo "xvc0" >> $guest_root/etc/securetty
        ;;
      "esxi")
        ;;
      "kvm")
        # following found on functioning CDC test image Centos 64bit using KVM hypervisor
        echo "alias scsi_hostadapter ata_piix"     > $guest_root/etc/modprobe.conf
        echo "alias scsi_hostadapter1 virtio_blk" >> $guest_root/etc/modprobe.conf
        echo "alias eth0 virtio_net"              >> $guest_root/etc/modprobe.conf

        # modprobe acpiphp at startup - required for CDC KVM hypervisor to detect attaching/detaching volumes
        echo "/sbin/modprobe acpiphp" >> $guest_root/etc/rc.local

        # enable console access
        echo "2:2345:respawn:/sbin/mingetty tty2" >> $guest_root/etc/inittab
        echo "tty2" >> $guest_root/etc/securetty
        ;;
      esac
      ;;
    esac

    # set hwclock to UTC
    echo "UTC" >> $guest_root/etc/adjtime
  EOH
end


include_recipe "cloud_add_end"

bash "backup raw image" do 
  cwd target_raw_root
  code <<-EOH
    raw_image=$(basename #{target_raw_path})
    target_temp_root=#{target_temp_root}
    cp -v $raw_image $target_temp_root 
  EOH
end

rightimage_hypervisor "Package image for hypervisor" do
  provider "rightimage_hypervisor_#{node[:rightimage][:virtual_environment]}"
  action :package_image
end

rs_utils_marker :end
