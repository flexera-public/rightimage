# TBD, don't use bash blocks, just execute the code w/err handling since we're in a provider already

action :create do
  # Subtle bug: chef will reuse resources based on the string passed in, so 
  # add in new_resource.source into the bash block name to make it unique
  # TBD: get away from unnecessary bash blocks
  bash "create loopback fs #{new_resource.source}" do
    not_if { ::File.exists? new_resource.source }
    flags "-ex"
    code <<-EOH
      calc_mb="#{new_resource.size_gb*1024}"
      loop_dev="/dev/loop#{new_resource.device_number}"
      root_label="#{new_resource.label}"
      mount_point="#{new_resource.mount_point}"
      source="#{new_resource.source}"

      dd if=/dev/zero of=$source bs=1M count=$calc_mb
      losetup $loop_dev $source

      sfdisk $loop_dev << EOF
0,1304,L,*
EOF
      if [ "#{new_resource.partitioned}" == "true" ]; then
        kpartx -a $loop_dev
        loop_map="/dev/mapper/loop#{new_resource.device_number}p1"
      else
        loop_map=$loop_dev
      fi
      mke2fs -F -j $loop_map
      tune2fs -L $root_label $loop_map
      rm -rf $mount_point
      mkdir -p $mount_point
      mount $loop_map $mount_point
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

      if [ "#{new_resource.partitioned}" == "true" ]; then
        kpartx -a $loop_dev
        loop_map="/dev/mapper/loop#{new_resource.device_number}p1"
      else
        loop_map=$loop_dev
      fi

      mkdir -p $mount_point
      mount $loop_map $mount_point
    EOH
  end
end

action :resize do
  bash "resize loopback fs #{new_resource.source}" do
    not_if do
      source_size_gb = (::File.size(new_resource.source)/1024/1024/1024).to_f.round
      new_resource.size_gb == source_size_gb
    end
    flags "-x"
    code <<-EOH
      e2fsck -p -f #{new_resource.source}
      resize2fs #{new_resource.source} #{new_resource.size_gb*1024}M
    EOH
  end
end
