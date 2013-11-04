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
# Cylinders is the second param to sfdisk, however it doesn't
# seem to be necessary, if its blank it'll just calculate it itself
# and use all the space
#    size_bytes = new_resource.size_gb*1024*1024*1024
#    cylinders = size_bytes/(255*63*512)



    code <<-EOH
      calc_mb="#{new_resource.size_gb*1024}"
      loop_dev="/dev/loop#{new_resource.device_number}"
      loop_map="/dev/mapper/loop#{new_resource.device_number}p1"
      fake_dev="/dev/mapper/sda#{new_resource.device_number}"
      fake_map="/dev/mapper/sda#{new_resource.device_number}p1"
      root_label="#{new_resource.label}"
      mount_point="#{new_resource.mount_point}"
      source="#{new_resource.source}"

      dd if=/dev/zero of=$source bs=1M count=$calc_mb
      losetup $loop_dev $source
      parted -s ${loop_dev} mklabel msdos
      parted -s ${loop_dev} mkpart primary ext2 1024k 100% -a minimal
      parted -s ${loop_dev} set 1 boot on

      # So this bit of indirection helps the grub2 install to work - grub2 
      # normally freaks out if the partition is in /dev/mapper and the loopback
      # device itself is mounted in /dev, so keep them both in the same place
      # so that grub2-install can link them together properly
      echo "0 $[#{new_resource.size_gb}*2097152] linear $loop_dev 0" | dmsetup create `basename $fake_dev`
      # use synchonous flag to avoid any later race conditions
      kpartx -s -a $fake_dev

      mke2fs -F -j $fake_map
      tune2fs -L $root_label $fake_map
      rm -rf $mount_point
      mkdir -p $mount_point
      mount -t ext2 $fake_map $mount_point

      # Handle binding of special files
      #{bind_devices_script}
    EOH
  end
end

action :unmount do
  bash "unmount loopback fs #{new_resource.source}" do
    flags "-ex"
    code <<-EOH
      loop_dev="/dev/loop#{new_resource.device_number}"
      loop_map="/dev/mapper/loop#{new_resource.device_number}p1"
      fake_dev="/dev/mapper/sda#{new_resource.device_number}"
      fake_map="/dev/mapper/sda#{new_resource.device_number}p1"

      mount_point="#{new_resource.mount_point}"

      sync

      umount -lf $mount_point/dev/pts || true
      umount -lf $mount_point/dev || true
      umount -lf $mount_point/proc || true
      umount -lf $mount_point/sys || true

      umount -lf $mount_point || true


      [ -e "$fake_map" ] && kpartx -d $fake_dev
      [ -e "$fake_dev" ] && dmsetup remove $fake_dev
      set +e
      losetup -a | grep $loop_dev
      if [ "$?" == "0" ]; then
        set -e
        losetup -d $loop_dev
      fi
      set -e
    EOH
  end
end

action :mount do
  bash "mount loopback fs #{new_resource.source}" do
    not_if { `mount`.split("\n").any? {|line| line.include? new_resource.mount_point} }
    flags "-ex"
    code <<-EOH
      loop_dev="/dev/loop#{new_resource.device_number}"
      loop_map="/dev/mapper/loop#{new_resource.device_number}p1"
      loop_map_link=${loop_dev}p1
      fake_dev="/dev/mapper/sda#{new_resource.device_number}"
      fake_map="/dev/mapper/sda#{new_resource.device_number}p1"

      mount_point="#{new_resource.mount_point}"
      source="#{new_resource.source}"

      losetup $loop_dev $source

      echo "0 $[#{new_resource.size_gb}*2097152] linear $loop_dev 0" | dmsetup create `basename $fake_dev`
      # use synchonous flag to avoid any later race conditions
      kpartx -s -a $fake_dev

      mkdir -p $mount_point
      mount $fake_map $mount_point

      # Handle binding of special files
      if [ "#{new_resource.bind_devices}" == "true" ]; then
        #{bind_devices_script}
      fi
    EOH
  end
end
