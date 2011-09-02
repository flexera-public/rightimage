# cloud_add_vmops_esx.rb
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

raise "ERROR: you must set your virtual_environment to esxi!"  if node[:rightimage][:virtual_environment] != "esxi"


source_image = "#{node.rightimage.mount_dir}" 

target_raw = "target.raw"
target_raw_path = "/mnt/#{target_raw}"
target_mnt = "/mnt/target"

bundled_image = "RightImage_#{node.rightimage.platform}_#{node.rightimage.release}_#{node.rightimage.rightlink_version}_dev.vmdk"
bundled_path = "/mnt"
bundled_image_path = "#{bundled_path}/#{bundled_image}"

loop_name="loop0"
loop_dev="/dev/#{loop_name}"
loop_map="/dev/mapper/#{loop_name}p1"

image_size_gb=10

package "qemu"

bash "create cloudstack-esxi loopback fs" do 
  code <<-EOH
    set -e 
    set -x

    DISK_SIZE_GB=#{image_size_gb}
    BYTES_PER_MB=1024
    DISK_SIZE_MB=$(($DISK_SIZE_GB * $BYTES_PER_MB))

    source_image="#{node.rightimage.mount_dir}" 
    target_raw_path="#{target_raw_path}"
    target_mnt="#{target_mnt}"

    umount -lf #{source_image}/proc || true 
    umount -lf #{target_mnt}/proc || true 
    umount -lf #{target_mnt} || true
    rm -rf $target_raw_path $target_mnt

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
    
    mkdir $target_mnt
    mount #{loop_map} $target_mnt

    rsync -a $source_image/ $target_mnt/

  EOH
end

bash "mount proc & dev" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{target_mnt}
    mount -t proc none $target_mnt/proc
    mount --bind /dev $target_mnt/dev
  EOH
end

# add fstab
template "#{target_mnt}/etc/fstab" do
  source "fstab.erb"
  backup false
end

# insert grub conf
template "#{target_mnt}/boot/grub/grub.conf" do 
  source "grub.conf"
  backup false 
end

bash "setup grub" do 
  code <<-EOH
    set -e 
    set -x

    target_raw_path="#{target_raw_path}"
    target_mnt="#{target_mnt}"

    chroot $target_mnt mkdir -p /boot/grub

    case "#{node.rightimage.platform}" in
      "ubuntu" )
        grub_command="/usr/sbin/grub"
        ;;

      "centos"|* )
        chroot $target_mnt cp -p /usr/share/grub/x86_64-redhat/* /boot/grub
        grub_command="/sbin/grub"
        ;;
    esac

    chroot $target_mnt ln -sf /boot/grub/grub.conf /boot/grub/menu.lst

    echo "(hd0) #{node[:rightimage][:grub][:root_device]}" > $target_mnt/boot/grub/device.map
    echo "" >> $target_mnt/boot/grub/device.map

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

bash "create custom initrd" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{target_mnt}

  case "#{node.rightimage.virtual_environment}" in
      "ec2" )
      rm -f $target_mnt/boot/initrd*
      chroot $target_mnt mkinitrd --with=mptbase --with=mptscsih --with=mptspi --with=scsi_transport_spi --with=ata_piix \
         --with=ext3 -v initrd-#{node[:rightimage][:kernel_id]} #{node[:rightimage][:kernel_id]}
      mv $target_mnt/initrd-#{node[:rightimage][:kernel_id]}  $target_mnt/boot/.
      ;;

     "esxi" )

     # These don't seem necessary.  Remove in the future?
       rm -f $target_mnt/boot/initrd*
      modules="mptbase mptscsih mptspi scsi_transport_spi apa_piix ext3"
      for mod in $modules
       do
        echo "$mod" >> $target_mnt/etc/initramfs-tools/modules
       done 
      chroot $target_mnt update-initramfs -c -k all
      ;;
     "kvm" )
        # NOTE: Do we really need to build our own ramdisk since we are using vmbuilder?
      ;;
  esac

  EOH
end

bash "install vmware tools" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{target_mnt}
    TMP_DIR=/tmp/vmware_tools

# TODO: THIS NEEDS TO BE CLEANED UP
  case "#{node.rightimage.platform}" in 
    "centos" )
      chroot $target_mnt mkdir -p $TMP_DIR
      chroot $target_mnt curl http://packages.vmware.com/tools/keys/VMWARE-PACKAGING-GPG-DSA-KEY.pub -o $TMP_DIR/dsa.pub
      chroot $target_mnt curl http://packages.vmware.com/tools/keys/VMWARE-PACKAGING-GPG-RSA-KEY.pub -o $TMP_DIR/rsa.pub
      chroot $target_mnt rpm --import $TMP_DIR/dsa.pub
      chroot $target_mnt rpm --import $TMP_DIR/rsa.pub
      cat > $target_mnt/etc/yum.repos.d/vmware-tools.repo <<EOF
[vmware-tools] 
name=VMware Tools 
baseurl=http://packages.vmware.com/tools/esx/latest/rhel5/x86_64
enabled=1 
gpgcheck=1
EOF
   yum -c /tmp/yum.conf --installroot=$target_mnt -y clean all
   yum -c $target_mnt/etc/yum.conf --installroot=$target_mnt -y install vmware-tools-nox
    ;;

  "ubuntu" )
    # https://help.ubuntu.com/community/VMware/Tools#Installing VMware tools on an Ubuntu guest
   #  chroot $target_mnt apt-get install -y --no-install-recommends open-vm-dkms
   #  chroot $target_mnt apt-get install -y --no-install-recommends open-vm-tools 
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
    target_mnt=#{target_mnt}

  case "#{node.rightimage.platform}" in
    "centos" )
      # clean out packages
      yum -c /tmp/yum.conf --installroot=$target_mnt -y clean all

      # configure dns timeout 
      echo 'timeout 300;' > $target_mnt/etc/dhclient.conf

      rm ${target_mnt}/var/lib/rpm/__*
      chroot $target_mnt rpm --rebuilddb
      ;;

    "ubuntu" )
      echo 'timeout 300;' > $target_mnt/etc/dhcp3/dhclient.conf
      rm $target_mnt/var/lib/dhcp3/*
      ;;
     
  esac 

    mkdir -p $target_mnt/etc/rightscale.d
    echo "cloudstack" > $target_mnt/etc/rightscale.d/cloud
  EOH
end

bash "unmount proc & dev" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{target_mnt}
    umount -lf $target_mnt/proc
    umount -lf $target_mnt/dev
  EOH
end

remote_file "/tmp/rightimage.patch" do
  source "rightimage.patch"
end

bash "Patch /etc/init.d/rightimage" do
  code <<-EOH
    patch #{target_mnt}/etc/init.d/rightimage /tmp/rightimage.patch
  EOH
end



# Clean up guest image
rightimage target_mnt do
  action :sanitize
end

bash "unmount target filesystem" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{target_mnt}

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
  cwd File.dirname target_raw_path
  code <<-EOH
    set -e
    set -x
    qemu-img convert -O vmdk #{target_raw_path} #{bundled_image}
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

directory "#{bundled_path}/ova" do
  action :create
end

ovf_filename = bundled_image
ovf_image_name = bundled_image
ovf_vmdk_size = `ls -l1 #{bundled_path}/#{bundled_image} | awk '{ print $5; }'`.chomp
ovf_capacity = "10"
ovf_ostype = "ubuntu64Guest"

template "#{bundled_path}/temp.ovf" do
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
  ./ovftool #{bundled_path}/temp.ovf #{bundled_path}/ova/#{bundled_image}.ovf  > /dev/null 2>&1
  cd #{bundled_path}/ova
  tar -cf #{bundled_image}.ova #{bundled_image}.ovf #{bundled_image}.mf *.vmdk
 EOH
end
