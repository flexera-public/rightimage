# TBD, don't use bash blocks, just execute the code w/err handling since we're in a provider already

def bind_devices_script
  <<-EOF
  mount_point="#{new_resource.mount_point}"
  mkdir -p $mount_point/proc
  umount $mount_point/proc || true
  mount --bind /proc $mount_point/proc

  mkdir -p $mount_point/sys
  umount $mount_point/sys || true
  mount --bind /sys $mount_point/sys

  umount $mount_point/dev || true
  umount $mount_point/dev/pts || true

  mkdir -p $mount_point/dev
  mount -t devtmpfs none $mount_point/dev
  
  EOF
end


action :create do
  # Subtle bug: chef will reuse resources based on the string passed in, so 
  # add in new_resource.source into the bash block name to make it unique
  # TBD: get away from unnecessary bash blocks
  bash "create loopback fs #{new_resource.source}" do
    not_if { ::File.exists? new_resource.source }
    flags "-ex"

    code <<-EOH
      loop_dev="#{loopback_device}#{new_resource.device_number}"
      loop_size="#{new_resource.size_gb}"
      fake_dev="/dev/mapper/sda#{new_resource.device_number}"
      fake_map="/dev/mapper/sda#{new_resource.device_number}p1"
      root_label="#{new_resource.label}"
      mount_point="#{new_resource.mount_point}"
      source="#{new_resource.source}"

      qemu-img create -f qcow2 $source ${loop_size}G
      # Only run modprobe if not done already, otherwise will cause I/O errors.
      [ ! -e /dev/nbd0 ] && modprobe nbd max_part=16
      qemu-nbd -n -c $loop_dev $source
      sleep 1
      parted -s ${loop_dev} mklabel msdos
      parted -s ${loop_dev} mkpart primary ext2 1024k 100% -a minimal
      parted -s ${loop_dev} set 1 boot on

      # So this bit of indirection helps the grub2 install to work - grub2 
      # normally freaks out if the partition is in /dev/mapper and the loopback
      # device itself is mounted in /dev, so keep them both in the same place
      # so that grub2-install can link them together properly
      echo "0 $[#{new_resource.size_gb}*2097152] linear $loop_dev 0" | dmsetup create `basename $fake_dev`
      if [ "#{new_resource.partitioned}" == "true" ]; then
        # use synchonous flag to avoid any later race conditions
        kpartx -s -a $fake_dev
      else
        fake_map=$fake_dev
      fi

      mke2fs -F -j $fake_map
      tune2fs -L $root_label $fake_map
      rm -rf $mount_point
      mkdir -p $mount_point
      mount -t ext2 $fake_map $mount_point

      # Handle binding of special files
      # No need to do this if doing a create as part of resize action, since we
      # just want to copy what is already on the other loopback.
      if [ "#{new_resource.bind_devices}" == "true" ]; then
        #{bind_devices_script}
      fi
    EOH
  end
end

action :unmount do
  bash "unmount loopback fs #{new_resource.source}" do
    flags "-ex"
    code <<-EOH
      loop_dev="#{loopback_device}#{new_resource.device_number}"
      fake_dev="/dev/mapper/sda#{new_resource.device_number}"
      fake_map="/dev/mapper/sda#{new_resource.device_number}p1"

      mount_point="#{new_resource.mount_point}"

      sync

      umount -lf $mount_point/dev/pts || true
      umount -lf $mount_point/dev || true
      umount -lf $mount_point/proc || true
      umount -lf $mount_point/sys || true

      umount -lf $mount_point || true

      [ -e "$fake_map" ] && kpartx -s -d $fake_dev
      [ -e "$fake_dev" ] && dmsetup remove $fake_dev
      qemu-nbd -d $loop_dev
	    killall qemu-nbd || killall5 qemu-nbd || true
    EOH
  end
end

action :mount do
  package "parted"
  
  bash "mount loopback fs #{new_resource.source}" do
    not_if { `mount`.split("\n").any? {|line| line.include? new_resource.mount_point} }
    flags "-ex"
    code <<-EOH
      loop_dev="#{loopback_device}#{new_resource.device_number}"
      fake_dev="/dev/mapper/sda#{new_resource.device_number}"
      fake_map="/dev/mapper/sda#{new_resource.device_number}p1"

      mount_point="#{new_resource.mount_point}"
      source="#{new_resource.source}"

      [ ! -e /dev/nbd0 ] && modprobe nbd max_part=16

      # Turn off cache (-n) as it causes qemu-nbd to crash and throw I/O errors.
      qemu-nbd -n -c $loop_dev $source
  	  sleep 1
      partprobe $loop_dev

      echo "0 $[#{new_resource.size_gb}*2097152] linear $loop_dev 0" | dmsetup create `basename $fake_dev`
      # use synchonous flag to avoid any later race conditions
      if [ "#{new_resource.partitioned}" == "true" ]; then
        # use synchonous flag to avoid any later race conditions
        kpartx -s -a $fake_dev
      else
        fake_map=$fake_dev
      fi

      mkdir -p $mount_point
      mount $fake_map $mount_point

      # Handle binding of special files
      if [ "#{new_resource.bind_devices}" == "true" ]; then
        #{bind_devices_script}
      fi
    EOH
  end
end

action :clone do
  execute "qemu-img create -f qcow2 -o backing_file=#{loopback_file_base} #{loopback_file_backup}" do
    cwd target_raw_root
  end
end
