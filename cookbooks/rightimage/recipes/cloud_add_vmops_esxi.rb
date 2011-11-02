# cloud_add_vmops_esxi.rb
#
# Converts a previously generated and mounted disk image and converts it to a stream optimized vmdk in an OVA package
# 
# 1. Create loopback filesystem for new disk image.
# 2. rsync base OS from $source_image -> $target
# 3. Update grub, fstab and modify kernels & modules if needed.
# 4. Install vmware tools
# 5. Add any special CloudStack tweeks
# 6. Convert raw image to flat vmdk
# 7. Covert to archived OVF format using ovftool
#

class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

class Chef::Recipe
  include RightScale::RightImage::Helper
end

class Erubis::Context
  include RightScale::RightImage::Helper
end


raise "ERROR: you must set your virtual_environment to esxi!"  if node[:rightimage][:virtual_environment] != "esxi"


bundled_image = "#{image_name}.vmdk"

loop_name="loop0"
loop_dev="/dev/#{loop_name}"
loop_map="/dev/mapper/#{loop_name}p1"

package "qemu"

bash "create cloudstack-esxi loopback fs" do 
  code <<-EOH
    set -e 
    set -x

    DISK_SIZE_GB=#{node[:rightimage][:root_size_gb]}  
    BYTES_PER_MB=1024
    DISK_SIZE_MB=$(($DISK_SIZE_GB * $BYTES_PER_MB))

    base_root="#{base_root}"
    guest_root="#{guest_root}"
    source_image="#{source_image}" 
    target_raw_root="#{target_raw_root}"
    target_raw_path="#{target_raw_path}"

    umount -lf #{source_image}/proc || true 
    umount -lf #{guest_root}/proc || true
    umount -lf $guest_root/sys || true 
    umount -lf #{guest_root} || true
    rm -rf $base_root
    mkdir -p $target_raw_root

    dd if=/dev/zero of=$target_raw_path bs=1M count=$DISK_SIZE_MB    

    umount -lf #{loop_map} || true
    kpartx -d  #{loop_dev} || true
    losetup -d #{loop_dev} || true

    losetup #{loop_dev} $target_raw_path

    sfdisk #{loop_dev} << EOF
0,1304,L
EOF
   
    kpartx -a #{loop_dev}
    mke2fs -F -j #{loop_map}
    
    # setup uuid for our root partition
    tune2fs -U #{node[:rightimage][:root_mount][:uuid]} #{loop_map}
    
    mkdir -p $guest_root
    mount #{loop_map} $guest_root

    rsync -a $source_image/ $guest_root/

  EOH
end

bash "mount proc & dev" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    guest_root=#{guest_root}
    mount -t proc none $guest_root/proc
    mount --bind /dev $guest_root/dev
    mount --bind /sys $guest_root/sys
  EOH
end

# add fstab
template "#{guest_root}/etc/fstab" do
  source "fstab.erb"
  backup false
end

rightimage_kernel "Install Ramdisk" do
  provider "rightimage_kernel_#{node[:rightimage][:virtual_environment]}"
#  guest_root guest_root
#  version node[:rightimage][:kernel_id]
  action :install
end

# insert grub conf
template "#{guest_root}/boot/grub/grub.conf" do 
  source "menu.lst.erb"
  backup false 
end

bash "setup grub" do 
  code <<-EOH
    set -e 
    set -x

    target_raw_path="#{target_raw_path}"
    guest_root="#{guest_root}"

    chroot $guest_root mkdir -p /boot/grub

    case "#{node.rightimage.platform}" in
      "ubuntu" )
        grub_command="/usr/sbin/grub"
        ;;

      "centos"|* )
        chroot $guest_root cp -p /usr/share/grub/x86_64-redhat/* /boot/grub
        grub_command="/sbin/grub"
        ;;
    esac

    chroot $guest_root ln -sf /boot/grub/grub.conf /boot/grub/menu.lst

    echo "(hd0) #{node[:rightimage][:grub][:root_device]}" > $guest_root/boot/grub/device.map
    echo "" >> $guest_root/boot/grub/device.map

    cat > device.map <<EOF
(hd0) #{target_raw_path}
EOF
    ${grub_command} --batch --device-map=device.map <<EOF
root (hd0,0)
setup (hd0)
quit
EOF 

  EOH
end

include_recipe "rightimage::bootstrap_common"

bash "install vmware tools" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    guest_root=#{guest_root}
    TMP_DIR=/tmp/vmware_tools

# TODO: THIS NEEDS TO BE CLEANED UP
  case "#{node.rightimage.platform}" in 
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
   yum -c /tmp/yum.conf --installroot=$guest_root -y clean all
   yum -c $guest_root/etc/yum.conf --installroot=$guest_root -y install vmware-tools-esx-nox
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

#
# Add additional CloudStack specific configuration changes here
#
bash "configure for cloudstack" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    guest_root=#{guest_root}

  case "#{node.rightimage.platform}" in
    "centos" )
      # clean out packages
      yum -c /tmp/yum.conf --installroot=$guest_root -y clean all

      # configure dns timeout 
      echo 'timeout 300;' > $guest_root/etc/dhclient.conf

      rm ${guest_root}/var/lib/rpm/__*
      chroot $guest_root rpm --rebuilddb
      ;;

    "ubuntu" )
      echo 'timeout 300;' > $guest_root/etc/dhcp3/dhclient.conf
      rm $guest_root/var/lib/dhcp3/*
      ;;
     
  esac 

    mkdir -p $guest_root/etc/rightscale.d
    echo "cloudstack" > $guest_root/etc/rightscale.d/cloud
  EOH
end

bash "unmount proc & dev" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    guest_root=#{guest_root}
    umount -lf $guest_root/proc
    umount -lf $guest_root/dev
    umount -lf $guest_root/sys
  EOH
end

remote_file "/tmp/rightimage.patch" do
  source "rightimage.patch"
end

bash "Patch /etc/init.d/rightimage" do
  code <<-EOH
    patch #{guest_root}/etc/init.d/rightimage /tmp/rightimage.patch
  EOH
end



# Clean up guest image
rightimage guest_root do
  action :sanitize
end

bash "sync fs" do 
  code <<-EOH
    set -x
    sync
  EOH
end

bash "unmount target filesystem" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    guest_root=#{guest_root}

    umount -lf #{loop_map}
    kpartx -d  #{loop_dev}
    losetup -d #{loop_dev}
  EOH
end

# TODO: Need to fix this up.
bash "cleanup working directories" do 
  code <<-EOH
    set -e
    set -x
      [ -e "/tmp/ovftool.sh" ] && rm -f "/tmp/ovftool.sh"
      [ -d "/tmp/ovftool" ] && rm -rf /tmp/ovftool
      [ -d "/mnt/ova/" ] && rm -rf /mnt/ova
      [ -e "/mnt/temp.ovf" ] && rm -f /mnt/temp.ovf  
      rm -fv /mnt/*.vmdk
  EOH
end

bash "convert raw image to VMDK flat file" do 
  cwd target_raw_root
  code <<-EOH
    set -e
    set -x

    BUNDLED_IMAGE="#{bundled_image}"
    BUNDLED_IMAGE_PATH="#{target_raw_root}/$BUNDLED_IMAGE"

    qemu-img convert -O vmdk #{target_raw_path} $BUNDLED_IMAGE_PATH
  EOH
end

remote_file "/tmp/ovftool.sh" do
  source "VMware-ovftool-2.0.1-260188-lin.x86_64.sh"
  mode "0744"
end

bash "Install ovftools" do
  cwd "/tmp"
  code <<-EOH
    set -e
    set -x
    mkdir -p /tmp/ovftool
    ./ovftool.sh --silent /tmp/ovftool AGREE_TO_EULA 
  EOH
end

directory "#{target_raw_root}/ova" do
  action :create
end

ovf_filename = bundled_image
ovf_image_name = bundled_image
ovf_vmdk_size = `ls -l1 #{target_raw_root}/#{bundled_image} | awk '{ print $5; }'`.chomp
ovf_capacity = node[:rightimage][:root_size_gb] 
ovf_ostype = "other26xLinux64Guest"

template "#{target_raw_root}/temp.ovf" do
  source "ovf.erb"
  variables({
    :ovf_filename => ovf_filename,
    :ovf_image_name => ovf_image_name,
    :ovf_vmdk_size => ovf_vmdk_size,
    :ovf_capacity => ovf_capacity,
    :ovf_ostype => ovf_ostype
  })
end

bash "Create create vmdk and create ovf/ova files" do
  cwd "/tmp/ovftool"

  code <<-EOH
    set -ex
    ./ovftool #{target_raw_root}/temp.ovf #{target_raw_root}/ova/#{bundled_image}.ovf  > /dev/null 2>&1
    cd #{target_raw_root}/ova
    tar -cf #{bundled_image}.ova #{bundled_image}.ovf #{bundled_image}.mf *.vmdk
  EOH
end
