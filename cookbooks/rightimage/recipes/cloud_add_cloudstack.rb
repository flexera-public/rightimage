rs_utils_marker :begin
#
# Cookbook Name:: rightimage
# Recipe:: cloud_add_vmops
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

rightimage_kernel "Install PV Kernel for Hypervisor" do
  provider "rightimage_kernel_#{node[:rightimage][:virtual_environment]}"
  action :install
end

##### XEN VERSION
bash "configure for cloudstack" do
  flags "-ex" 
  code <<-EOH
    guest_root=#{guest_root}

    case "#{node[:rightimage][:platform]}" in
    "ubuntu" )
      # enable console access
      cp $guest_root/etc/init/tty1.conf* $guest_root/etc/init/hvc0.conf
      sed -i "s/tty1/hvc0/g" $guest_root/etc/init/hvc0.conf
      echo "hvc0" >> $guest_root/etc/securetty

      for i in $guest_root/etc/init/tty*; do
        mv $i $i.disabled;
      done
      ;;  
    "centos"|"rhel")
      # configure dns timeout 
      echo 'timeout 300;' > $guest_root/etc/dhclient.conf
      rm -f ${guest_root}/var/lib/rpm/__*
      chroot $guest_root rpm --rebuilddb

      # enable console access
      echo "2:2345:respawn:/sbin/mingetty xvc0" >> $guest_root/etc/inittab
      echo "xvc0" >> $guest_root/etc/securetty
      ;;
    esac 
  EOH
end

####### KVM VERSION
bash "configure for cloudstack" do
  flags "-ex" 
  code <<-EOH
    guest_root=#{guest_root}

    case "#{node[:rightimage][:platform]}" in
    "centos")
      # following found on functioning CDC test image Centos 64bit using KVM hypervisor
      echo "alias scsi_hostadapter ata_piix"     > $guest_root/etc/modprobe.conf
      echo "alias scsi_hostadapter1 virtio_blk" >> $guest_root/etc/modprobe.conf
      echo "alias eth0 virtio_net"              >> $guest_root/etc/modprobe.conf

      # modprobe acpiphp at startup - required for CDC KVM hypervisor to detect attaching/detaching volumes
      echo "/sbin/modprobe acpiphp" >> $guest_root/etc/rc.local

      # clean out packages
      chroot $guest_root yum -y clean all

      # clean centos RPM data
      rm ${guest_root}/var/lib/rpm/__*
      chroot $guest_root rpm --rebuilddb

      # enable console access
      echo "2:2345:respawn:/sbin/mingetty tty2" >> $guest_root/etc/inittab
      echo "tty2" >> $guest_root/etc/securetty

      # configure dns timeout 
      echo 'timeout 300;' > $guest_root/etc/dhclient.conf

      [ -f $guest_root/var/lib/rpm/__* ] && rm ${guest_root}/var/lib/rpm/__*
      chroot $guest_root rpm --rebuilddb
      ;;
    "ubuntu")
      # Disable all ttys except for tty1 (console)
      for i in `ls $guest_root/etc/init/tty[2-9].conf`; do
        mv $i $i.disabled;
      done
      ;;
    esac

    mkdir -p $guest_root/etc/rightscale.d
    echo "cloudstack" > $guest_root/etc/rightscale.d/cloud

    # set hwclock to UTC
    echo "UTC" >> $guest_root/etc/adjtime
  EOH
end


########### VMWARE VERSION
#
# Add additional CloudStack specific configuration changes here
#
bash "install vmware tools" do
  flags "-ex"
  code <<-EOH
    guest_root=#{guest_root}
    TMP_DIR=/tmp/vmware_tools

# TODO: THIS NEEDS TO BE CLEANED UP
  case "#{node[:rightimage][:platform]}" in 
    "centos" )
      chroot $guest_root mkdir -p $TMP_DIR
      chroot $guest_root curl --fail http://packages.vmware.com/tools/keys/VMWARE-PACKAGING-GPG-DSA-KEY.pub -o $TMP_DIR/dsa.pub
      chroot $guest_root curl --fail http://packages.vmware.com/tools/keys/VMWARE-PACKAGING-GPG-RSA-KEY.pub -o $TMP_DIR/rsa.pub
      chroot $guest_root rpm --import $TMP_DIR/dsa.pub
      chroot $guest_root rpm --import $TMP_DIR/rsa.pub
      cat > $guest_root/etc/yum.repos.d/vmware-tools.repo <<EOF
[vmware-tools] 
name=VMware Tools 
baseurl=http://packages.vmware.com/tools/esx/5.0/rhel5/x86_64
enabled=1 
gpgcheck=1
EOF
   chroot $guest_root yum -y clean all
   chroot $guest_root yum -y install vmware-tools-esx-nox
   rm -f $guest_root/etc/yum.repos.d/vmware-tools.repo
    ;;

  "ubuntu" )
    # https://help.ubuntu.com/community/VMware/Tools#Installing VMware tools on an Ubuntu guest
   #  chroot $guest_root apt-get install -y --no-install-recommends open-vm-dkms
   #  chroot $guest_root apt-get install -y --no-install-recommends open-vm-tools 
    ;;

 esac
  EOH
end

bash "configure for cloudstack" do
  flags "-ex"
  code <<-EOH
    guest_root=#{guest_root}

    case "#{node[:rightimage][:platform]}" in
    "centos")
      # clean out packages
      chroot $guest_root yum -y clean all

      # clean centos RPM data
      rm ${guest_root}/var/lib/rpm/__*
      chroot $guest_root rpm --rebuilddb

      # configure dhcp timeout
      echo 'timeout 300;' > $guest_root/etc/dhclient.conf

      [ -f $guest_root/var/lib/rpm/__* ] && rm ${guest_root}/var/lib/rpm/__*
      chroot $guest_root rpm --rebuilddb
      ;;
    "ubuntu")
      # Disable all ttys except for tty1 (console)
      for i in `ls $guest_root/etc/init/tty[2-9].conf`; do
        mv $i $i.disabled;
      done
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


##### XEN VERSION
bash "xen convert" do 
  cwd target_temp_root
  flags "-ex"
  code <<-EOH
    raw_image=$(basename #{target_raw_path})
    vhd_image=${raw_image}.vhd
    vhd-util convert -s 0 -t 1 -i $raw_image -o $vhd_image
    vhd-util convert -s 1 -t 2 -i $vhd_image -o #{image_name}.vhd
    rm -f #{image_name}.vhd.bz2
    bzip2 #{image_name}.vhd
  EOH
end


###### KVM VERSION
bash "package image" do 
  cwd target_temp_root
  flags "-ex"
  code <<-EOH
    
    BUNDLED_IMAGE="#{image_name}.qcow2"
    BUNDLED_IMAGE_PATH="#{target_temp_root}/$BUNDLED_IMAGE"
    
    qemu-img convert -O qcow2 #{target_temp_path} $BUNDLED_IMAGE_PATH
    [ -f $BUNDLED_IMAGE_PATH.bz2 ] && rm -f $BUNDLED_IMAGE_PATH.bz2
    bzip2 $BUNDLED_IMAGE_PATH

  EOH
end


########### VMWARE VERSION
bash "cleanup working directories" do
  flags "-ex" 
  code <<-EOH
    rm -rf /tmp/ovftool.sh /tmp/ovftool #{target_temp_root}/temp.ovf #{target_temp_root}/#{image_name}*
  EOH
end

bundled_image = "#{image_name}.vmdk"
bash "convert raw image to VMDK flat file" do
  cwd target_temp_root
  flags "-ex"
  code <<-EOH
    BUNDLED_IMAGE="#{bundled_image}"
    BUNDLED_IMAGE_PATH="#{target_temp_root}/$BUNDLED_IMAGE"

    qemu-img convert -O vmdk #{target_raw_path} $BUNDLED_IMAGE_PATH
  EOH
end

remote_file "/tmp/ovftool.sh" do
  source "VMware-ovftool-2.0.1-260188-lin.x86_64.sh"
  mode "0744"
end

bash "Install ovftools" do
  cwd "/tmp"
  flags "-ex"
  code <<-EOH
    mkdir -p /tmp/ovftool
    ./ovftool.sh --silent /tmp/ovftool AGREE_TO_EULA 
  EOH
end

ovf_filename = bundled_image
ovf_image_name = bundled_image
ovf_capacity = node[:rightimage][:root_size_gb] 
ovf_ostype = "other26xLinux64Guest"

template "#{target_temp_root}/temp.ovf" do
  source "ovf.erb"
  variables({
    :ovf_filename => ovf_filename,
    :ovf_image_name => ovf_image_name,
    :ovf_capacity => ovf_capacity,
    :ovf_ostype => ovf_ostype
  })
end

bash "Create create vmdk and create ovf/ova files" do
  cwd target_temp_root
  flags "-ex"
  code <<-EOH
    /tmp/ovftool/ovftool #{target_temp_root}/temp.ovf #{target_temp_root}/#{bundled_image}.ovf  > /dev/null 2>&1
    tar -cf #{bundled_image}.ova #{bundled_image}.ovf #{bundled_image}.mf #{image_name}.vmdk-disk*.vmdk
  EOH
end


rs_utils_marker :end
