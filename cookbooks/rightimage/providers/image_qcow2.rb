
action :package do
  package "qemu"
  bash "package image" do 
    cwd target_temp_root
    flags "-ex"
    code <<-EOH
      
      BUNDLED_IMAGE="#{image_name}.qcow2"
      BUNDLED_IMAGE_PATH="#{target_temp_root}/$BUNDLED_IMAGE"
      
      qemu-img convert -O qcow2 #{target_temp_path} $BUNDLED_IMAGE_PATH
      [ -f $BUNDLED_IMAGE_PATH.bz2 ] && rm -f $BUNDLED_IMAGE_PATH.bz2
      bzip2 -k $BUNDLED_IMAGE_PATH
    EOH
  end
end
