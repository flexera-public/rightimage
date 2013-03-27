
action :package do
  qemu_package = el6? ? "qemu-img" : "qemu"
  package qemu_package

  bash "cleanup working directories" do
    flags "-ex" 
    code <<-EOH
      rm -rf /tmp/ovftool.sh /tmp/ovftool #{target_raw_root}/temp.ovf #{target_raw_root}/#{image_name}\* #{target_raw_root}/box\*
    EOH
  end

  bundled_image = "box"
  bash "convert raw image to VMDK flat file" do
    cwd target_raw_root
    flags "-ex"
    code <<-EOH
      BUNDLED_IMAGE="#{bundled_image}"
      BUNDLED_IMAGE_PATH="#{target_raw_root}/$BUNDLED_IMAGE"

      qemu-img convert -O vmdk #{loopback_file} $BUNDLED_IMAGE_PATH
    EOH
  end

  cookbook_file "/tmp/ovftool.sh" do
    cookbook 'rightimage' # Shared with image_vmdk
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

  template "#{target_raw_root}/temp.ovf" do
    # Need this cookbook line so templates get looked for in the right place.  Even though this
    # provider is provided by the rightimage_image_virtualbox cookbook, the resource lives in the
    # rightimage cookbook and the resources the template search path.  Manually override here
    cookbook 'rightimage_image_virtualbox' 
    source "ovf-vbox.erb"
    variables({
      :ovf_filename => ovf_filename,
      :ovf_image_name => ovf_image_name,
      :ovf_capacity => ovf_capacity,
      :ovf_ostype => ovf_ostype
    })
  end

  cookbook_file "#{target_raw_root}/Vagrantfile" do
    cookbook 'rightimage_image_virtualbox'
    source "Vagrantfile"
    mode "0644"
  end

  bash "Create create vmdk and create ovf/ova files" do
    cwd target_raw_root
    flags "-ex"
    code <<-EOH
      /tmp/ovftool/ovftool #{target_raw_root}/temp.ovf #{bundled_image}.ovf  > /dev/null 2>&1
      mv box box.vmdk
      tar -cf #{image_name}.box #{bundled_image}.ovf #{bundled_image}-disk*.vmdk Vagrantfile
    EOH
  end
end
