
action :package do
  qemu_package = (el? && el_ver >= 6.0) ? "qemu-img" : "qemu"
  package qemu_package

  bash "cleanup working directories" do
    flags "-ex" 
    code <<-EOH
      rm -rf /tmp/ovftool.sh /tmp/ovftool #{target_raw_root}/temp.ovf #{target_raw_root}/#{image_name}*
    EOH
  end

  bundled_image = "#{image_name}"
  bash "convert raw image to VMDK flat file" do
    cwd target_raw_root
    flags "-ex"
    code <<-EOH
      BUNDLED_IMAGE="#{bundled_image}"
      BUNDLED_IMAGE_PATH="#{target_raw_root}/$BUNDLED_IMAGE"

      qemu-img convert -O vmdk #{loopback_file} $BUNDLED_IMAGE_PATH
    EOH
  end

  remote_file "/tmp/ovftool.sh" do
    source "#{node[:rightimage][:s3_base_url]}/files/VMware-ovftool-2.0.1-260188-lin.x86_64.sh"
    mode "0744"
    action :create_if_missing
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

  template "#{target_raw_root}/temp.ovf" do
    source "ovf.erb"
    variables({
      :ovf_filename => ovf_filename,
      :ovf_image_name => ovf_image_name,
      :ovf_capacity => ovf_capacity,
      :ovf_ostype => ovf_ostype
    })
  end

  bash "Create create vmdk and create ovf/ova files" do
    cwd target_raw_root
    flags "-ex"
    code <<-EOH
      /tmp/ovftool/ovftool #{target_raw_root}/temp.ovf #{target_raw_root}/#{bundled_image}.ovf  > /dev/null 2>&1
      tar -cf #{bundled_image}.ova #{bundled_image}.ovf #{bundled_image}.mf #{image_name}*-disk*.vmdk
    EOH
  end
end
