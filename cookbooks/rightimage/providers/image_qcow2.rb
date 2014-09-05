
action :package do
  qemu_package = (el? && el_ver >= 6.0) ? "qemu-img" : "qemu"
  package qemu_package

  bash "package image" do 
    cwd target_raw_root
    flags "-ex"
    code <<-EOH
      
      BUNDLED_IMAGE="#{image_name}.qcow2"
      BUNDLED_IMAGE_PATH="#{target_raw_root}/$BUNDLED_IMAGE"

      set +e
      # Detect if compat option exists. https://lists.fedoraproject.org/pipermail/virt/2014-April/004041.html
      qemu-img create -f qcow2 -o ? blah.qcow2 | grep 'compat'
      compat_check=$?
      compat=""
      set -e

      if [ "$compat_check" == "0" ]; then
        compat="-o compat=0.10"
      fi
      
      qemu-img convert -O qcow2 $compat #{loopback_file} $BUNDLED_IMAGE_PATH

      if [ "#{node[:rightimage][:cloud]}" != "openstack" ]; then
        [ -f $BUNDLED_IMAGE_PATH.bz2 ] && rm -f $BUNDLED_IMAGE_PATH.bz2
        bzip2 $BUNDLED_IMAGE_PATH
      fi
    EOH
  end
end
