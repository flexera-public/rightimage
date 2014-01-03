
action :package do
  qemu_package = el6? ? "qemu-img" : "qemu"
  package qemu_package

  bash "package image" do 
    cwd target_raw_root
    flags "-ex"
    code <<-EOH
      
      BUNDLED_IMAGE="#{image_name}.qcow2"
      BUNDLED_IMAGE_PATH="#{target_raw_root}/$BUNDLED_IMAGE"
      
      qemu-img convert -O qcow2 #{loopback_file} $BUNDLED_IMAGE_PATH

      if [ "#{node[:rightimage][:cloud]}" != "openstack" ]; then
        [ -f $BUNDLED_IMAGE_PATH.bz2 ] && rm -f $BUNDLED_IMAGE_PATH.bz2
        bzip2 $BUNDLED_IMAGE_PATH
      fi
    EOH
  end
end
