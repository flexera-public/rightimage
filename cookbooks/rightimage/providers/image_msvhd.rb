action :package do

  package "virtualbox" do
    not_if { node[:platform] == "centos" }
    action :install
  end

  if el7?
    # fedora 18 package throws errors about loading kernel mod on el7, doesn't
    # matter though, we don't use that functionality
    vbox_pkg = "VirtualBox-4.3-4.3.14_95030_fedora18-1.x86_64.rpm"
  else el6?
    vbox_pkg = "VirtualBox-4.1-4.1.18_78361_rhel6-1.x86_64.rpm"
  end

  execute "virtualbox install" do
    only_if { node[:platform] == "centos" }
    not_if "rpm -qa VirtualBox*|grep VirtualBox"
    command "yum -y install #{node[:rightimage][:s3_base_url]}/files/#{vbox_pkg}"
  end

  bash "package image" do
    flags "-ex"
    cwd target_raw_root
    code <<-EOH
      image="#{image_name}.vhd"
      raw_image="#{loopback_rootname}.raw"

      echo "Remove old image"
      rm -f $image

      qemu-img convert -f qcow2 -O raw #{loopback_file} $raw_image
      VBoxManage convertfromraw $raw_image $image --format VHD
    EOH
  end
end
