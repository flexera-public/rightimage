class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

# configure an image for a particular cloud. 
# we need to:
#  - configure ssh settings (do we want to disable passwd based root access for vmops?)
#  - insert proper init scripts (rackspace needs lvm hack)

# TODO: add uuca tools for centos 



#  - create /etc/rightscale.d/cloud
execute "echo -n #{node[:right_image_creator][:cloud]} > #{node[:right_image_creator][:mount_dir]}/etc/rightscale.d/cloud" do 
  creates "#{node[:right_image_creator][:mount_dir]}/etc/rightscale.d/cloud"
end


#  - add fstab
template "#{node[:right_image_creator][:mount_dir]}/etc/fstab" do 
  source "fstab.erb" 
  backup false
end

#  - add get_ssh_key script


template "#{node[:right_image_creator][:mount_dir]}/etc/init.d/getsshkey" do 
  source "getsshkey.erb" 
  mode "0544"
  backup false
end

execute "link_getsshkey" do 
  command  node[:right_image_creator][:getsshkey_cmd] 
end


#  - add cloud tools
bash "install_ec2_tools" do 
  creates "#{node[:right_image_creator][:mount_dir]}/home/ec2/bin"
  code <<-EOH
#!/bin/bash -ex
    ROOT=#{node[:right_image_creator][:mount_dir]}
    rm -rf #{node[:right_image_creator][:mount_dir]}/home/ec2 || true
    mkdir -p #{node[:right_image_creator][:mount_dir]}/home/ec2
    curl -o #{node[:right_image_creator][:mount_dir]}/tmp/ec2-api-tools.zip http://s3.amazonaws.com/ec2-downloads/ec2-api-tools.zip
    curl -o #{node[:right_image_creator][:mount_dir]}/tmp/ec2-ami-tools.zip http://s3.amazonaws.com/ec2-downloads/ec2-ami-tools.zip
    unzip #{node[:right_image_creator][:mount_dir]}/tmp/ec2-api-tools.zip -d #{node[:right_image_creator][:mount_dir]}/tmp/
    unzip #{node[:right_image_creator][:mount_dir]}/tmp/ec2-ami-tools.zip -d #{node[:right_image_creator][:mount_dir]}/tmp/
    cp -r #{node[:right_image_creator][:mount_dir]}/tmp/ec2-api-tools-*/* #{node[:right_image_creator][:mount_dir]}/home/ec2/.
    rsync -av #{node[:right_image_creator][:mount_dir]}/tmp/ec2-ami-tools-*/ #{node[:right_image_creator][:mount_dir]}/home/ec2
    rm -r #{node[:right_image_creator][:mount_dir]}/tmp/ec2-a*
    echo 'export PATH=$PATH:/home/ec2/bin' >> #{node[:right_image_creator][:mount_dir]}/etc/profile.d/ec2.sh
    echo 'export EC2_HOME=/home/ec2' >> #{node[:right_image_creator][:mount_dir]}/etc/profile.d/ec2.sh
  EOH
end if node[:right_image_creator][:cloud] == "ec2"

package "euca2ools" if node[:right_image_creator][:cloud] == "eucalyptus" && node[:right_image_creator][:platform] == "ubuntu" 



#  - insert kernel mods (for centos)
bash "insert_kernel_mods" do 
  code <<-EOH
#!/bin/bash -ex
set -e
set -x
    echo "installing kernel modules..."
    if [ "#{node[:right_image_creator][:arch]}" == "i386" ]; then
      curl -s http://s3.amazonaws.com/ec2-downloads/linux-2.6.16-ec2.tgz | tar -xzC #{node[:right_image_creator][:mount_dir]}/usr/src/
      curl -s http://s3.amazonaws.com/rightscale_scripts/kernel-modules.2.6.16-xenU.tgz | tar -xzC #{node[:right_image_creator][:mount_dir]}/lib/modules/
      curl -s http://ec2-downloads.s3.amazonaws.com/ec2-modules-2.6.18-xenU-ec2-v1.0-i686.tgz | tar -xzC #{node[:right_image_creator][:mount_dir]}/
      curl -s http://s3.amazonaws.com/ec2-downloads/ec2-modules-2.6.21-2952.fc8xen-i686.tgz | tar -xzC #{node[:right_image_creator][:mount_dir]}/
    elif [ "#{node[:right_image_creator][:arch]}" == "x86_64" ]; then
      curl -s http://s3.amazonaws.com/ec2-downloads/ec2-modules-2.6.16.33-xenU-x86_64.tgz | tar -xzC #{node[:right_image_creator][:mount_dir]}/
      curl -s http://s3.amazonaws.com/rightscale_scripts/kernel-modules.2.6.16-xenU.tgz | tar -xzC #{node[:right_image_creator][:mount_dir]}/lib/modules
      curl -s http://ec2-downloads.s3.amazonaws.com/ec2-modules-2.6.18-xenU-ec2-v1.0-x86_64.tgz | tar -xzC #{node[:right_image_creator][:mount_dir]}/
      curl -s http://s3.amazonaws.com/ec2-downloads/ec2-modules-2.6.21-2952.fc8xen-x86_64.tgz | tar -xzC #{node[:right_image_creator][:mount_dir]}/
    else
      echo >&2 "architecture is not set properly: #{node[:right_image_creator][:arch]}"
      echo >&2 "exiting..."
      exit 2
    fi
    mv #{node[:right_image_creator][:mount_dir]}/lib/modules/2.6.21-2952.fc8xen #{node[:right_image_creator][:mount_dir]}/lib/modules/2.6.21.7-2.fc8xen
  EOH
end if node[:right_image_creator][:platform] == "centos"

# drop in amazon's recompiled xfs module 
#remote_file "#{node[:right_image_creator][:mount_dir]}/lib/modules/2.6.21.7-2.fc8xen/kernel/fs/xfs/xfs.ko" do 
  #source "xfs.ko.#{node[:right_image_creator][:arch]}"
  #backup false
#end if node[:right_image_creator][:platform] == "centos"

bash "do_depmod" do 
  code <<-EOH
#!/bin/bash -ex
  for module_version in $(cd #{node[:right_image_creator][:mount_dir]}/lib/modules; ls); do
    chroot #{node[:right_image_creator][:mount_dir]} depmod -a $module_version
  done

  EOH
end if node[:right_image_creator][:platform] == "centos"


#  - configure mirrors
template "#{node[:right_image_creator][:mount_dir]}#{node[:right_image_creator][:mirror_file_path]}" do 
  source node[:right_image_creator][:mirror_file] 
  backup false
end unless node[:right_image_creator][:platform] == "centos"


#  - bundle and upload
bash "bundle_upload_ec2" do 
  #action :nothing

## remember to move this down if you comment it out
#cat <<-EOS > /tmp/script
  code <<-EOH
#!/bin/bash -ex
  set -e
  set -x

  . /etc/profile
  
  export JAVA_HOME=/usr
  export PATH=$PATH:/usr/local/bin:/home/ec2/bin
  export EC2_HOME=/home/ec2

  umount "#{node[:right_image_creator][:mount_dir]}/proc" || true
  
  kernel_opt=""
  if [ -n "#{node[:right_image_creator][:kernel_id]}" ]; then
    kernel_opt="--kernel #{node[:right_image_creator][:kernel_id]}"
  fi 

  ramdisk_opt=""
  if [ -n "#{node[:right_image_creator][:ramdisk_id]}" ]; then
    ramdisk_opt="--ramdisk #{node[:right_image_creator][:ramdisk_id]}"
  fi
  
  #create keyfiles for bundle
  echo "#{node[:right_image_creator][:aws_509_key]}" > /tmp/AWS_X509_KEY.pem
  echo "#{node[:right_image_creator][:aws_509_cert]}" > /tmp/AWS_X509_CERT.pem
  
  rm -rf "#{node[:right_image_creator][:mount_dir]}"_temp
  mkdir -p "#{node[:right_image_creator][:mount_dir]}"_temp

  ## so it looks like the ec2 tools are borken as they are bundling /tmp even if --exclude is set, so:
  rm -rf #{node[:right_image_creator][:mount_dir]}/tmp/*

  ## it looks like /tmp perms are not getting set correctly, so do:
  chroot #{node[:right_image_creator][:mount_dir]} chmod 1777 /tmp

  echo bundling...
  ec2-bundle-vol -r #{node[:right_image_creator][:arch]} -d "#{node[:right_image_creator][:mount_dir]}"_temp -k  /tmp/AWS_X509_KEY.pem -c  /tmp/AWS_X509_CERT.pem -u #{node[:right_image_creator][:aws_account_number]} -p #{image_name}  -v #{node[:right_image_creator][:mount_dir]} $kernel_opt $ramdisk_opt -B "ami=sda1,root=/dev/sda1,ephemeral0=sdb,swap=sda3" --exclude /tmp     #--generate-fstab
  
  echo "Uploading..." 
  echo y | ec2-upload-bundle -b #{node[:right_image_creator][:image_upload_bucket]} -m "#{node[:right_image_creator][:mount_dir]}"_temp/#{image_name}.manifest.xml -a #{node[:right_image_creator][:aws_access_key_id]} -s #{node[:right_image_creator][:aws_secret_access_key]} --retry --batch
  
  echo registering... 
  ec2-register #{node[:right_image_creator][:image_upload_bucket]}/#{image_name}.manifest.xml -K  /tmp/AWS_X509_KEY.pem -C  /tmp/AWS_X509_CERT.pem -n "#{image_name}" --url #{node[:right_image_creator][:ec2_endpoint]}
  
  #remove keys
  rm -f /tmp/AWS_X509_KEY.pem
  rm -f  /tmp/AWS_X509_CERT.pem

#EOS
  #chmod +x /tmp/script

  EOH
end if node[:right_image_creator][:cloud] == "ec2"



      
