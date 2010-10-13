class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

package "euca2ools" if node[:rightimage][:platform] == "ubuntu" 

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

## copy the generic image 
bash "copy_image" do 
  code <<-EOC
#!/bin/bash  -ex
  set -x
  set -e
  unmount /mnt/euca/proc || true
  ## copy the gneric image
  rm -rf /mnt/euca
  mkdir -p /mnt/euca
  rsync -a --exclude=tmp --exclude=proc #{node[:rightimage][:mount_dir]}/ /mnt/euca/
  mkdir -p /mnt/euca/proc
  rm -rf /mnt/euca_tmp
  mkdir /mnt/euca_tmp
  cd /mnt/euca_tmp

  ## insert keys
  echo -n "#{node[:rightimage][:euca][:x509_key]}" > /mnt/euca_tmp/euca_x509_key
  echo -n "#{node[:rightimage][:euca][:x509_cert]}" > /mnt/euca_tmp/euca_x509_cert
  echo -n "#{node[:rightimage][:euca][:x509_key_admin]}" > /mnt/euca_tmp/euca_x509_key_admin
  echo -n "#{node[:rightimage][:euca][:x509_cert_admin]}" > /mnt/euca_tmp/euca_x509_cert_admin
  echo -n "#{node[:rightimage][:euca][:euca_cert]}" > /mnt/euca_tmp/euca_cert

  ## insert cloud file
  mkdir -p /mnt/euca/etc/rightscale.d
  echo -n "eucalyptus" > /mnt/euca/etc/rightscale.d/cloud

  # install euca tools

 
  if [ "#{node[:rightimage][:platform]}" == "centos" ]; then 
    cd /tmp
    tar -xzvf  euca2ools-1.2-centos-#{node[:kernel][:machine]}.tar.gz 
    cd  euca2ools-1.2-centos-#{node[:kernel][:machine]}
    rpm -i --force * 

    cp /tmp/euca2ools-1.2-centos-#{node[:rightimage][:arch]}.tar.gz /mnt/euca/tmp/.
    cd /mnt/euca/tmp/.
    tar -xzvf euca2ools-1.2-centos-#{node[:rightimage][:arch]}.tar.gz
    chroot /mnt/euca rpm -i --force /tmp/euca2ools-1.2-centos-#{node[:rightimage][:arch]}/*
    cd /mnt/euca_tmp
  fi
   


## bundle kernel and ramdisk. Need to do this as the admin user

  ## bundle kernel
  euca-bundle-image  \
    -i /mnt/euca/boot/$(ls #{node[:rightimage][:mount_dir]}/boot/ | grep vmlinuz | tail -n 1) \
    -u #{node[:rightimage][:euca][:user_admin]} \
    -c euca_x509_cert_admin  \
    -k euca_x509_key_admin   \
    -d . \
    --ec2cert euca_cert  \
    -r #{node[:rightimage][:arch]} \
    -a #{node[:rightimage][:euca][:access_key_id_admin]} \
    -s #{node[:rightimage][:euca][:secret_access_key_admin]} \
    -U #{node[:rightimage][:euca][:euca_url]} \
    -p #{image_name}.kernel \
    --kernel true

  ## bundle ramdisk
  euca-bundle-image  \
    -i /mnt/euca/boot/$(ls #{node[:rightimage][:mount_dir]}/boot/ | grep initrd | tail -n 1) \
    -u #{node[:rightimage][:euca][:user_admin]} \
    -c euca_x509_cert_admin  \
    -k euca_x509_key_admin   \
    -d . --ec2cert euca_cert  \
    -r #{node[:rightimage][:arch]} \
    -a #{node[:rightimage][:euca][:access_key_id_admin]} \
    -s #{node[:rightimage][:euca][:secret_access_key_admin]} \
    -U #{node[:rightimage][:euca][:euca_url]} \
    -p #{image_name}.initrd \
    --ramdisk true

  ## upload kernel
  euca-upload-bundle  \
    -b #{image_name}_admin \
    -m #{image_name}.kernel.manifest.xml  \
    --ec2cert euca_cert \
    -a #{node[:rightimage][:euca][:access_key_id_admin]} \
    -s #{node[:rightimage][:euca][:secret_access_key_admin]} \
    -U #{node[:rightimage][:euca][:walrus_url]} 

  ## upload ramdisk
  euca-upload-bundle  \
    -b #{image_name}_admin \
    -m #{image_name}.initrd.manifest.xml  \
    --ec2cert euca_cert \
    -a #{node[:rightimage][:euca][:access_key_id_admin]} \
    -s #{node[:rightimage][:euca][:secret_access_key_admin]} \
    -U #{node[:rightimage][:euca][:walrus_url]} 

  ## register kernel
  kernel_output=`euca-register  #{image_name}_admin/#{image_name}.kernel.manifest.xml \
    -a #{node[:rightimage][:euca][:access_key_id_admin]} \
    -s #{node[:rightimage][:euca][:secret_access_key_admin]}   \
    -U  http://174.46.234.42:8773/services/Eucalyptus`
  echo $kernel_optput

  ## register ramdisk
  ramdisk_output=`euca-register  #{image_name}_admin/#{image_name}.initrd.manifest.xml \
    -a #{node[:rightimage][:euca][:access_key_id_admin]} \
    -s #{node[:rightimage][:euca][:secret_access_key_admin]}   \
    -U  http://174.46.234.42:8773/services/Eucalyptus`
  echo $ramdisk_output

  ## collect kernel and ramdisk id's
  kernel_id=`echo -n $kernel_output | awk '{ print $2 }'`
  ramdisk_id=`echo -n $ramdisk_output | awk '{ print $2 }'`

  ## install euca2ools into image
  #chroot /mnt/euca apt-get update 
  #chroot /mnt/euca apt-get install -y euca2ools
  rm -rf /mnt/euca/tmp/*
  rm -rf /mnt/euca/proc/*

  cp /mnt/euca_tmp/euca* /mnt/euca/tmp/.

  ## have to bind /dev to make the euca2ools happy  for centos
  if [ "#{node[:rightimage][:platform]}" == "centos" ]; then 
    mount --bind /dev/ /mnt/euca/dev/
  fi

chroot /mnt/euca euca-bundle-vol  \
  --arch #{node[:rightimage][:arch]} \
  --privatekey /tmp/euca_x509_key \
  --cert /tmp/euca_x509_cert \
  --ec2cert /tmp/euca_cert \
  --user #{node[:rightimage][:euca][:user]} \
  --kernel $kernel_id \
  --ramdisk $ramdisk_id \
  --url #{node[:rightimage][:euca][:euca_url]} \
  --exclude /tmp \
  --destination /tmp/.  \
  --prefix #{image_name}
  #--generate-fstab \

  cp /mnt/euca/tmp/#{image_name}* .

  ## unmount bind
  if [ "#{node[:rightimage][:platform]}" == "centos" ]; then 
    umount /mnt/euca/dev/
  fi


euca-upload-bundle \
  --bucket #{image_name} \
  --manifest #{image_name}.manifest.xml \
  --access-key #{node[:rightimage][:euca][:access_key_id]} \
  --secret-key #{node[:rightimage][:euca][:secret_access_key]} \
  --url #{node[:rightimage][:euca][:walrus_url]} 

## register image
image_out=`euca-register \
  #{image_name}/#{image_name}.manifest.xml \
  --url #{node[:rightimage][:euca][:euca_url]} \
  -a #{node[:rightimage][:euca][:access_key_id]}  \
  -s #{node[:rightimage][:euca][:secret_access_key]} `
  echo $image_out


# parse out image id
image_id=`echo -n $image_out | awk '{ print $2 }'`
echo new image id = $image_id

  EOC
end
