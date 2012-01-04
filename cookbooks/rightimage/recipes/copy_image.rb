class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

bash "create nonpartitioned image" do
  flags "-ex"
  code <<-EOH
    calc_mb="#{calc_mb}"
    loop_dev="/dev/loop1"
    root_label="#{node[:rightimage][:root_mount][:dev]}"
    source_image="#{source_image}"
    source_image2="/mnt/image2"
    target_raw_path="#{target_raw_path}"

    dd if=/dev/zero of=$target_raw_path bs=1M count=$calc_mb 
    losetup $loop_dev $target_raw_path
    mke2fs -F -j $loop_dev
    tune2fs -L $root_label $loop_dev
    rm -rf $source_image2
    mkdir -p $source_image2
    mount $loop_dev $source_image2
    rsync -a $source_image/ $source_image2/
    umount -lf $source_image2
    losetup -d $loop_dev
  EOH
end
