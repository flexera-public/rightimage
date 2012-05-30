
action :package do
  qemu_package = el6? ? "qemu-img" : "qemu"
  package qemu_package

  bash "package image" do 
    cwd target_raw_root
    flags "-ex"
    code <<-EOH
      
      BUNDLED_IMAGE="#{image_name}.vhd"
      BUNDLED_IMAGE_PATH="#{target_raw_root}/$BUNDLED_IMAGE"
      
      qemu-img convert -O vhd #{target_raw_root}/#{loopback_filename(partitioned?)} $BUNDLED_IMAGE_PATH
      [ -f $BUNDLED_IMAGE_PATH.bz2 ] && rm -f $BUNDLED_IMAGE_PATH.bz2
      bzip2 -k $BUNDLED_IMAGE_PATH
    EOH
  end
end
