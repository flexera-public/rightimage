class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

source_image = "#{node.rightimage.mount_dir}" 
target_mnt = "/mnt/euca"
loop_name="loop0"
loop_dev="/dev/#{loop_name}"

#  - add fstab
template "#{node[:rightimage][:mount_dir]}/etc/fstab" do
  source "fstab.erb"
  backup false
end

remote_file "/tmp/euca2ools-1.2-centos-i386.tar.gz" do 
  source "euca2ools-1.2-centos-i386.tar.gz"
  backup false
end

remote_file "/tmp/euca2ools-1.2-centos-x86_64.tar.gz" do 
  source "euca2ools-1.2-centos-x86_64.tar.gz"
  backup false
end

bash "create eucalyptus loopback fs" do 
  code <<-EOH
    set -e 
    set -x
  
    source_image="#{node.rightimage.mount_dir}" 
    target_mnt="#{target_mnt}"

    umount -lf #{source_image}/proc || true 
    umount -lf #{target_mnt}/proc || true 
    umount -lf #{target_mnt} || true
    rm -rf $target_mnt
      
    mkdir $target_mnt  
    rsync -a $source_image/ $target_mnt/

  EOH
end

bash "mount proc & dev" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{target_mnt}
    mount -t proc none $target_mnt/proc
    mount --bind /dev $target_mnt/dev
  EOH
end


package "euca2ools" do
  only_if { node[:rightimage][:platform] == "ubuntu" }
end

bash "install euca tools for centos" do 
  only_if { node[:rightimage][:platform] == "centos" }
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{target_mnt}
      
    # install on host
    cd /tmp
    tar -xzvf euca2ools-1.2-centos-#{node[:kernel][:machine]}.tar.gz 
    cd  euca2ools-1.2-centos-#{node[:kernel][:machine]}
    rpm -i --force * 

    # install on guest image
    cp /tmp/euca2ools-1.2-centos-#{node[:rightimage][:arch]}.tar.gz $target_mnt/tmp/.
    cd $target_mnt/tmp/.
    tar -xzvf euca2ools-1.2-centos-#{node[:rightimage][:arch]}.tar.gz
    chroot $target_mnt rpm -i --force /tmp/euca2ools-1.2-centos-#{node[:rightimage][:arch]}/*
    
  EOH
end

bash "configure for eucalyptus" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{target_mnt}

    ## insert cloud file
    mkdir -p /mnt/euca/etc/rightscale.d
    echo -n "eucalyptus" > /mnt/euca/etc/rightscale.d/cloud

    # clean out packages
    yum -c /tmp/yum.conf --installroot=$target_mnt -y clean all
    
    rm ${target_mnt}/var/lib/rpm/__*
    chroot $target_mnt rpm --rebuilddb

  EOH
end

bash "unmount proc & dev" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{target_mnt}
    umount -lf $target_mnt/proc
    umount -lf $target_mnt/dev
  EOH
end

# Clean up guest image
rightimage target_mnt do
  action :sanitize
end

bash "package guest image" do 
  cwd "/mnt"
  code <<-EOH
    tar czvf #{image_name}.tgz #{target_path}/* 
  EOH
end

