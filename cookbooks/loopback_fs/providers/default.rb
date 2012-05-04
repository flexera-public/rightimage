action :create do
  bash "create loopback fs" do
    flags "-ex"
    code <<-EOH
      calc_mb="#{new_resource.size_gb*1024}"
      loop_dev="/dev/loop#{new_resource.device_number}"
      root_label="#{new_resource.label}"
      mount_dir="#{new_resource.mount_dir}"
      source="#{new_resource.source}"

      dd if=/dev/zero of=$source bs=1M count=$calc_mb
      losetup $loop_dev $source

      sfdisk $loop_dev << EOF
0,1304,L,*
EOF
      if [ "#{new_resource.partitioned}" == "true" ]; then
        kpartx -a $loop_dev
        loop_map="${loop_dev}p1"
      else
        loop_map=$loop_dev
      fi
      mke2fs -F -j $loop_map
      tune2fs -L $root_label $loop_map
      rm -rf $mount_dir
      mkdir -p $mount_dir
      mount $loop_map $mount_dir
    EOH
  end
end

action :unmount do
  bash "unmount loopback fs" do
    flags "-ex"
    code <<-EOH
      loop_dev="/dev/loop#{new_resource.device_number}"
      loop_map="#{new_resource.loop_device}p1"
      mount_dir="#{new_resource.mount_dir}"

      umount -lf $mount_dir/dev || true
      umount -lf $mount_dir/proc || true
      umount -lf $mount_dir/sys || true
      umount -lf $mount_dir || true

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
  bash "mount loopback fs" do
    flags "-ex"
    code <<-EOH
      loop_dev="/dev/loop#{new_resource.device_number}"
      mount_dir="#{new_resource.mount_dir}"
      source="#{new_resource.source}"

      losetup $loop_dev $source

      if [ "#{new_resource.partitioned}" == "true" ]; then
        kpartx -a $loop_dev
        loop_map="${loop_dev}p1"
      else
        loop_map=$loop_dev
      fi

      mkdir -p $mount_dir
      mount $loop_map $mount_dir
    EOH
  end
end

action :resize do
  bash "resize loopback fs" do
    flags "-x"
    code <<-EOH
      calc_mb="#{new_resource.size_gb*1024}"
      source="#{new_resource.source}"

      e2fsck -cn -f $source
      resize2fs $source ${calc_mb}M
    EOH
  end
