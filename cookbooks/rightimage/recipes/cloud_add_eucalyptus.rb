rs_utils_marker :begin
class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end
class Erubis::Context
  include RightScale::RightImage::Helper
end
class Chef::Resource::Execute
  include RightScale::RightImage::Helper
end


raise "ERROR: you must set your virtual_environment to xen!"  if node[:rightimage][:virtual_environment] != "xen"


include_recipe "cloud_add_begin"

rightimage_hypervisor "Install PV Kernel for Hypervisor" do
  provider "rightimage_hypervisor_#{node[:rightimage][:virtual_environment]}"
  guest_root guest_root
  action :install_kernel
end

euca_tools_version = "1.3.1"

bash "clean yum" do
  only_if { node[:platform] == "centos" }
  flags "-x"
  code <<-EOH
    yum clean all
  EOH
end

remote_file "/tmp/euca2ools-#{euca_tools_version}-centos-i386.tar.gz" do 
  source "euca2ools-#{euca_tools_version}-centos-i386.tar.gz"
  backup false
end

remote_file "/tmp/euca2ools-#{euca_tools_version}-centos-x86_64.tar.gz" do 
  source "euca2ools-#{euca_tools_version}-centos-x86_64.tar.gz"
  backup false
end

package "euca2ools" do
  only_if { node[:rightimage][:platform] == "ubuntu" }
end

bash "install euca tools for centos" do 
  only_if { node[:rightimage][:platform] == "centos" }
  flags "-ex"
  code <<-EOH
    VERSION=#{euca_tools_version}  
    guest_root=#{guest_root}
      
    # install on host
    cd /tmp
    export ARCH=#{node[:kernel][:machine]}
    tar -xzvf euca2ools-$VERSION-centos-$ARCH.tar.gz 
    cd  euca2ools-$VERSION-centos-$ARCH
    rpm -i --force * 

    # install on guest_root image
    cd $guest_root/tmp/.
    export ARCH=#{node[:rightimage][:arch]}
    cp /tmp/euca2ools-$VERSION-centos-$ARCH.tar.gz $guest_root/tmp/.
    tar -xzvf euca2ools-$VERSION-centos-$ARCH.tar.gz
    chroot $guest_root rpm -i --force /tmp/euca2ools-$VERSION-centos-$ARCH/*
    
  EOH
end

# Need to cleanup for ubuntu?
bash "configure for eucalyptus" do
  flags "-ex"
  only_if { node[:rightimage][:platform] == "centos" }
  code <<-EOH
    guest_root=#{guest_root}

    # clean out packages
    chroot $guest_root yum -y clean all
    
    rm ${guest_root}/var/lib/rpm/__*
    chroot $guest_root rpm --rebuilddb

  EOH
end


# TODO REFACTOR, DELETE, PART OF HYPERVISOR XEN STUFF?
bash "package guest image" do 
  cwd "/mnt"
  flags "-ex"
  code <<-EOH
    guest_root=#{guest_root}
    image_name=#{image_name}
    cloud_package_root=#{target_temp_root}
    package_dir=$cloud_package_root/$image_name
    KERNEL_VERSION=$(ls -t $guest_root/lib/modules|awk '{ printf "%s ", $0 }'|cut -d ' ' -f1-1)

    rm -rf $package_dir
    mkdir -p $package_dir
    cd $cloud_package_root
    mkdir $package_dir/xen-kernel
    cp $guest_root/boot/vmlinuz-$KERNEL_VERSION $package_dir/xen-kernel
    cp $guest_root/boot/initrd-$KERNEL_VERSION $package_dir/xen-kernel
    cp #{target_raw_path} $package_dir/$image_name.img
    tar czvf $image_name.tar.gz $image_name 
  EOH
end

include_recipe "cloud_add_end"

