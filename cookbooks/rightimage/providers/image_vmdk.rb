
action :package do
  qemu_package = el6? ? "qemu-img" : "qemu"
  package qemu_package

  bash "cleanup working directories" do
    flags "-ex" 
    code <<-EOH
      rm -rf /tmp/ovftool.sh /tmp/ovftool #{temp_root}/temp.ovf #{temp_root}/#{image_name}*
    EOH
  end

  bundled_image = "#{image_name}.vmdk"
  bash "convert raw image to VMDK flat file" do
    cwd temp_root
    flags "-ex"
    code <<-EOH
      BUNDLED_IMAGE="#{bundled_image}"
      BUNDLED_IMAGE_PATH="#{temp_root}/$BUNDLED_IMAGE"

      qemu-img convert -O vmdk #{loopback_file(partitioned?)} $BUNDLED_IMAGE_PATH
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

  template "#{temp_root}/temp.ovf" do
    source "ovf.erb"
    variables({
      :ovf_filename => ovf_filename,
      :ovf_image_name => ovf_image_name,
      :ovf_capacity => ovf_capacity,
      :ovf_ostype => ovf_ostype
    })
  end

  bash "Create create vmdk and create ovf/ova files" do
    cwd temp_root
    flags "-ex"
    code <<-EOH
      /tmp/ovftool/ovftool #{temp_root}/temp.ovf #{temp_root}/#{bundled_image}.ovf  > /dev/null 2>&1
      tar -cf #{bundled_image}.ova #{bundled_image}.ovf #{bundled_image}.mf #{image_name}.vmdk-disk*.vmdk
    EOH
  end
end
