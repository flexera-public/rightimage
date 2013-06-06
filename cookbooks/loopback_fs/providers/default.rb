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

  umount $mount_point/dev/pts || true

  if [ "#{node[:platform]}" = "ubuntu" ]; then
    mkdir -p $mount_point/dev
    cd $mount_point/dev 
    /sbin/MAKEDEV null ptmx console zero urandom
  else
    /sbin/MAKEDEV -d $mount_point/dev -x console
    /sbin/MAKEDEV -d $mount_point/dev -x null
    /sbin/MAKEDEV -d $mount_point/dev -x zero
    /sbin/MAKEDEV -d $mount_point/dev ptmx
    /sbin/MAKEDEV -d $mount_point/dev urandom

  fi


  mkdir -p $mount_point/dev/pts
  mkdir -p $mount_point/sys/block
    # not necessary?
    #test -e /dev/ptmx  && chroot $mount_point mount -t devpts none /dev/pts || true
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
      root_label="#{new_resource.label}"
      mount_point="#{new_resource.mount_point}"
      source="#{new_resource.source}"

      dd if=/dev/zero of=$source bs=1M count=$calc_mb
      losetup $loop_dev $source

      sfdisk $loop_dev << EOF
0,,L,*
EOF
      kpartx -a $loop_dev
      loop_map="/dev/mapper/loop#{new_resource.device_number}p1"
      mke2fs -F -j $loop_map
      tune2fs -L $root_label $loop_map
      rm -rf $mount_point
      mkdir -p $mount_point
      mount $loop_map $mount_point

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
      mount_point="#{new_resource.mount_point}"

      sync

      if [ "#{node[:platform]}" = "ubuntu" ]; then
        if [ -e $mount_point/dev ]; then 
          pushd $mount_point/dev 
          /sbin/MAKEDEV -d null ptmx console zero urandom
          popd
        fi
      fi
      umount -lf $mount_point/dev/pts || true
      umount -lf $mount_point/dev || true
      umount -lf $mount_point/proc || true
      umount -lf $mount_point/sys || true

      umount -lf $mount_point || true


      [ -e "$loop_map" ] && kpartx -d $loop_dev
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
      mount_point="#{new_resource.mount_point}"
      source="#{new_resource.source}"

      losetup $loop_dev $source

      kpartx -a $loop_dev
      loop_map="/dev/mapper/loop#{new_resource.device_number}p1"

      mkdir -p $mount_point
      mount $loop_map $mount_point

      # Handle binding of special files
      #{bind_devices_script}
    EOH
  end
end
