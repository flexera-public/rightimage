rs_utils_marker :begin
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

class Chef::Resource
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

bash "mount proc & dev" do
  flags "-ex" 
  code <<-EOH
    guest_root=#{guest_root}

    umount -lf $guest_root/proc || true 
    umount -lf $guest_root/sys || true 

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
  action :install
end

# insert grub conf
template "#{guest_root}/boot/grub/grub.conf" do 
  source "menu.lst.erb"
  backup false 
end

bash "setup grub" do
  flags "-ex" 
  code <<-EOH
    target_raw_path="#{target_raw_path}"
    guest_root="#{guest_root}"

    chroot $guest_root mkdir -p /boot/grub

    case "#{node[:rightimage][:platform]}" in
      "ubuntu" )
        chroot $guest_root cp -p /usr/lib/grub/x86_64-pc/* /boot/grub
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

include_recipe "rightimage::bootstrap_common_debug"

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

#
# Add additional CloudStack specific configuration changes here
#
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

      # Setup console
      [ -f $guest_root/etc/sysconfig/init ] && sed -i "s/ACTIVE_CONSOLES=.*/ACTIVE_CONSOLES=\\/dev\\/tty1/" $guest_root/etc/sysconfig/init
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

bash "unmount proc & dev" do
  flags "-ex"
  code <<-EOH
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
  flags "-x"
  code <<-EOH
    output=`patch --forward #{guest_root}/etc/init.d/rightimage /tmp/rightimage.patch`
    # Patch applied cleanly, first time
    if [ "$?" == "0" ]; then
      exit 0
    fi

    # Patch already applied from a previous run
    [[ $output =~ 'previously applied' ]]
    res=$?
    echo "OUTPUT: $output"

    exit $res
  EOH
end



# Clean up guest image
rightimage guest_root do
  action :sanitize
end

include_recipe "rightimage::do_destroy_loopback"

bash "cleanup working directories" do
  flags "-ex" 
  code <<-EOH
    rm -rf /tmp/ovftool.sh /tmp/ovftool #{target_temp_root}/temp.ovf #{target_temp_root}/#{image_name}*
  EOH
end

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
