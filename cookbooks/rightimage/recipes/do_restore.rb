class Chef::Recipe
  include RightScale::RightImage::Helper
end
class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end
class Chef::Resource::BlockDevice
  include RightScale::RightImage::Helper
end

block_device target_raw_root do
  provider "block_device_volume"
  cloud "ec2"
  lineage ri_lineage

  action :restore
end

bash "resize fs" do
  flags "-x"
  not_if node[:rightimage][:root_size_gb] == "10"
  code <<-EOH
    calc_mb="#{calc_mb}"
    target_raw_path="#{target_raw_path}"

    e2fsck -cn -f $target_raw_path
    resize2fs $target_raw_path ${calc_mb}M
  EOH
end

bash "mount image" do
  flags "-ex"
  code <<-EOH
    loop_dev="#{loop_dev}"
    source_image="#{source_image}"
    target_raw_path="#{target_raw_path}"

    losetup $loop_dev $target_raw_path

    if [ "#{partitioned?}" == "true" ]; then
      kpartx -a $loop_dev
      loop_map="#{loop_map}"
    else
      loop_map=$loop_dev
    fi

    mkdir -p $source_image
    mount $loop_map $source_image
  EOH
end
