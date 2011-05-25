class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

target_mnt = "/mnt/euca"
tmp_mnt = "/mnt/euca_tmp"

## copy the generic image 
bash "copy_image" do 
  code <<-EOC
#!/bin/bash  -ex
  set -x
  set -e
  target_mnt=#{target_mnt}
  tmp_mnt=#{tmp_mnt}

  rm -rf $tmp_mnt
  mkdir $tmp_mnt
  cd $tmp_mnt

  ## insert keys
  echo -n "#{node[:rightimage][:euca][:x509_key]}" > $tmp_mnt/euca_x509_key
  echo -n "#{node[:rightimage][:euca][:x509_cert]}" > $tmp_mnt/euca_x509_cert
  echo -n "#{node[:rightimage][:euca][:x509_key_admin]}" > $tmp_mnt/euca_x509_key_admin
  echo -n "#{node[:rightimage][:euca][:x509_cert_admin]}" > $tmp_mnt/euca_x509_cert_admin
  echo -n "#{node[:rightimage][:euca][:euca_cert]}" > $tmp_mnt/euca_cert

## bundle kernel and ramdisk. Need to do this as the admin user

  ## bundle kernel
  euca-bundle-image  \
    -i $target_mnt/boot/$(ls #{node[:rightimage][:mount_dir]}/boot/ | grep vmlinuz | tail -n 1) \
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
    -i $target_mnt/boot/$(ls #{node[:rightimage][:mount_dir]}/boot/ | grep initrd | tail -n 1) \
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
    -U #{node[:rightimage][:euca][:euca_url]}`
  echo $kernel_optput

  ## register ramdisk
  ramdisk_output=`euca-register  #{image_name}_admin/#{image_name}.initrd.manifest.xml \
    -a #{node[:rightimage][:euca][:access_key_id_admin]} \
    -s #{node[:rightimage][:euca][:secret_access_key_admin]}   \
    -U #{node[:rightimage][:euca][:euca_url]}`
  echo $ramdisk_output

  ## collect kernel and ramdisk id's
  kernel_id=`echo -n $kernel_output | awk '{ print $2 }'`
  ramdisk_id=`echo -n $ramdisk_output | awk '{ print $2 }'`

  rm -rf $target_mnt/tmp/*
  rm -rf $target_mnt/proc/*

  cp $tmp_mnt/euca* $target_mnt/tmp/.

  ## have to bind /dev to make the euca2ools happy for centos
  if [ "#{node[:rightimage][:platform]}" == "centos" ]; then 
    mount --bind /dev/ $target_mnt/dev/
  fi

chroot $target_mnt euca-bundle-vol  \
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

  cp $target_mnt/tmp/#{image_name}* .

  ## unmount bind
  if [ "#{node[:rightimage][:platform]}" == "centos" ]; then 
    umount $target_mnt/dev/
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

# parse out image id to tmp file
image_id=`echo -n $image_out | awk '{ print $2 }'`
echo new image id = $image_id
echo $image_id > /var/tmp/image_id

  EOC
end

ruby_block "store image id" do
  block do
    image_id = nil
    
    # read id which was written in previous stanza
    ::File.open("/var/tmp/image_id", "r") { |f| image_id = f.read() }
    
    # add to global id store for use by other recipes
    id_list = RightImage::IdList.new(Chef::Log)
    id_list.add(image_id)
  end
end
