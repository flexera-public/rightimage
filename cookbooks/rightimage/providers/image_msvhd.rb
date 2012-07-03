action :package do
  execute "virtualbox install" do
    not_if "rpm -qa VirtualBox*|grep VirtualBox"
    command "yum -y install http://download.virtualbox.org/virtualbox/4.1.18/VirtualBox-4.1-4.1.18_78361_rhel6-1.x86_64.rpm"
  end

  bash "package image" do
    flags "-ex"
    cwd target_raw_root
    code <<-EOH
      image="#{image_name}.vhd"

      echo "Remove old image"
      rm -f $image

      VBoxManage convertfromraw #{loopback_filename(partitioned?)} $image --format VHD
    EOH
  end
end
