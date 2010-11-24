class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end
class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

# configure an image for a particular cloud. 
# we need to:
#  - configure ssh settings (do we want to disable passwd based root access for vmops?)
#  - insert proper init scripts (rackspace needs lvm hack)

# TODO: add uuca tools for centos 
#  - create /etc/rightscale.d/cloud
execute "echo -n #{node[:rightimage][:cloud]} > #{node[:rightimage][:mount_dir]}/etc/rightscale.d/cloud" do 
  creates "#{node[:rightimage][:mount_dir]}/etc/rightscale.d/cloud"
end


#  - add fstab
template "#{node[:rightimage][:mount_dir]}/etc/fstab" do 
  source "fstab.erb" 
  backup false
end

#  - add get_ssh_key script


template "#{node[:rightimage][:mount_dir]}/etc/init.d/getsshkey" do 
  source "getsshkey.erb" 
  mode "0544"
  backup false
end

execute "link_getsshkey" do 
  command  node[:rightimage][:getsshkey_cmd] 
end


#  - add cloud tools
bash "install_ec2_tools" do 
  creates "#{node[:rightimage][:mount_dir]}/home/ec2/bin"
  code <<-EOH
#!/bin/bash -ex
    ROOT=#{node[:rightimage][:mount_dir]}
    rm -rf #{node[:rightimage][:mount_dir]}/home/ec2 || true
    mkdir -p #{node[:rightimage][:mount_dir]}/home/ec2
    curl -o #{node[:rightimage][:mount_dir]}/tmp/ec2-api-tools.zip http://s3.amazonaws.com/ec2-downloads/ec2-api-tools.zip
    curl -o #{node[:rightimage][:mount_dir]}/tmp/ec2-ami-tools.zip http://s3.amazonaws.com/ec2-downloads/ec2-ami-tools.zip
    unzip #{node[:rightimage][:mount_dir]}/tmp/ec2-api-tools.zip -d #{node[:rightimage][:mount_dir]}/tmp/
    unzip #{node[:rightimage][:mount_dir]}/tmp/ec2-ami-tools.zip -d #{node[:rightimage][:mount_dir]}/tmp/
    cp -r #{node[:rightimage][:mount_dir]}/tmp/ec2-api-tools-*/* #{node[:rightimage][:mount_dir]}/home/ec2/.
    rsync -av #{node[:rightimage][:mount_dir]}/tmp/ec2-ami-tools-*/ #{node[:rightimage][:mount_dir]}/home/ec2
    rm -r #{node[:rightimage][:mount_dir]}/tmp/ec2-a*
    echo 'export PATH=$PATH:/home/ec2/bin' >> #{node[:rightimage][:mount_dir]}/etc/profile.d/ec2.sh
    echo 'export EC2_HOME=/home/ec2' >> #{node[:rightimage][:mount_dir]}/etc/profile.d/ec2.sh
  EOH
end if node[:rightimage][:cloud] == "ec2"

package "euca2ools" if node[:rightimage][:cloud] == "eucalyptus" && node[:rightimage][:platform] == "ubuntu" 



#  - insert kernel mods (for centos)
bash "insert_kernel_mods" do 
  code <<-EOH
#!/bin/bash -ex
set -e
set -x
    echo "installing kernel modules..."
    if [ "#{node[:rightimage][:arch]}" == "i386" ]; then
      curl -s http://s3.amazonaws.com/ec2-downloads/linux-2.6.16-ec2.tgz | tar -xzC #{node[:rightimage][:mount_dir]}/usr/src/
      curl -s http://s3.amazonaws.com/rightscale_scripts/kernel-modules.2.6.16-xenU.tgz | tar -xzC #{node[:rightimage][:mount_dir]}/lib/modules/
      curl -s http://ec2-downloads.s3.amazonaws.com/ec2-modules-2.6.18-xenU-ec2-v1.0-i686.tgz | tar -xzC #{node[:rightimage][:mount_dir]}/
      curl -s http://s3.amazonaws.com/ec2-downloads/ec2-modules-2.6.21-2952.fc8xen-i686.tgz | tar -xzC #{node[:rightimage][:mount_dir]}/
    elif [ "#{node[:rightimage][:arch]}" == "x86_64" ]; then
      curl -s http://s3.amazonaws.com/ec2-downloads/ec2-modules-2.6.16.33-xenU-x86_64.tgz | tar -xzC #{node[:rightimage][:mount_dir]}/
      curl -s http://s3.amazonaws.com/rightscale_scripts/kernel-modules.2.6.16-xenU.tgz | tar -xzC #{node[:rightimage][:mount_dir]}/lib/modules
      curl -s http://ec2-downloads.s3.amazonaws.com/ec2-modules-2.6.18-xenU-ec2-v1.0-x86_64.tgz | tar -xzC #{node[:rightimage][:mount_dir]}/
      curl -s http://s3.amazonaws.com/ec2-downloads/ec2-modules-2.6.21-2952.fc8xen-x86_64.tgz | tar -xzC #{node[:rightimage][:mount_dir]}/
    else
      echo >&2 "architecture is not set properly: #{node[:rightimage][:arch]}"
      echo >&2 "exiting..."
      exit 2
    fi
    mv #{node[:rightimage][:mount_dir]}/lib/modules/2.6.21-2952.fc8xen #{node[:rightimage][:mount_dir]}/lib/modules/2.6.21.7-2.fc8xen
  EOH
end if node[:rightimage][:platform] == "centos"

# drop in amazon's recompiled xfs module 
#remote_file "#{node[:rightimage][:mount_dir]}/lib/modules/2.6.21.7-2.fc8xen/kernel/fs/xfs/xfs.ko" do 
  #source "xfs.ko.#{node[:rightimage][:arch]}"
  #backup false
#end if node[:rightimage][:platform] == "centos"

bash "do_depmod" do 
  code <<-EOH
#!/bin/bash -ex
  for module_version in $(cd #{node[:rightimage][:mount_dir]}/lib/modules; ls); do
    chroot #{node[:rightimage][:mount_dir]} depmod -a $module_version
  done

  EOH
end if node[:rightimage][:platform] == "centos"


#  - configure mirrors
template "#{node[:rightimage][:mount_dir]}#{node[:rightimage][:mirror_file_path]}" do 
  source node[:rightimage][:mirror_file] 
  backup false
end unless node[:rightimage][:platform] == "centos"


#  - bundle and upload
bash "bundle_upload_ec2" do 
    only_if { node[:rightimage][:cloud] == "ec2" }
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

    umount "#{node[:rightimage][:mount_dir]}/proc" || true
    
    kernel_opt=""
    if [ -n "#{node[:rightimage][:kernel_id]}" ]; then
      kernel_opt="--kernel #{node[:rightimage][:kernel_id]}"
    fi 

    ramdisk_opt=""
    if [ -n "#{node[:rightimage][:ramdisk_id]}" ]; then
      ramdisk_opt="--ramdisk #{node[:rightimage][:ramdisk_id]}"
    fi
    
    #create keyfiles for bundle
    echo "#{node[:rightimage][:aws_509_key]}" > /tmp/AWS_X509_KEY.pem
    echo "#{node[:rightimage][:aws_509_cert]}" > /tmp/AWS_X509_CERT.pem
    
    rm -rf "#{node[:rightimage][:mount_dir]}"_temp
    mkdir -p "#{node[:rightimage][:mount_dir]}"_temp

    ## so it looks like the ec2 tools are borken as they are bundling /tmp even if --exclude is set, so:
    rm -rf #{node[:rightimage][:mount_dir]}/tmp/*

    ## it looks like /tmp perms are not getting set correctly, so do:
    chroot #{node[:rightimage][:mount_dir]} chmod 1777 /tmp

    echo bundling...
    ec2-bundle-vol -r #{node[:rightimage][:arch]} -d "#{node[:rightimage][:mount_dir]}"_temp -k  /tmp/AWS_X509_KEY.pem -c  /tmp/AWS_X509_CERT.pem -u #{node[:rightimage][:aws_account_number]} -p #{image_name}  -v #{node[:rightimage][:mount_dir]} $kernel_opt $ramdisk_opt -B "ami=sda1,root=/dev/sda1,ephemeral0=sdb,swap=sda3" --exclude /tmp     #--generate-fstab
    
    echo "Uploading..." 
    echo y | ec2-upload-bundle -b #{node[:rightimage][:image_upload_bucket]} -m "#{node[:rightimage][:mount_dir]}"_temp/#{image_name}.manifest.xml -a #{node[:rightimage][:aws_access_key_id]} -s #{node[:rightimage][:aws_secret_access_key]} --retry --batch
    
    echo registering... 
    image_out_s3=`ec2-register #{node[:rightimage][:image_upload_bucket]}/#{image_name}.manifest.xml -K  /tmp/AWS_X509_KEY.pem -C  /tmp/AWS_X509_CERT.pem -n "#{image_name}" --url #{node[:rightimage][:ec2_endpoint]} `

    echo "Doing EBS"

# switch to a random directory for the build
    random_dir="/mnt/$RANDOM"
    mkdir $random_dir
    cd $random_dir
    ebs_mount=${random_dir}/ebs_mount
      mkdir -p $ebs_mount
# This /mnt/image is where the image creator creates the image
    image_mount=/mnt/image

## calculate ec2 region
    length=`echo -n #{node[:ec2][:placement_availability_zone]} | wc -c`
    length_minus_one=$((length -1))
    region=`echo  #{node[:ec2][:placement_availability_zone]} | cut -c -$length_minus_one`

      ## create EBS volume
    vol_out=`ec2-create-volume \
      --private-key /tmp/AWS_X509_KEY.pem \
      --cert /tmp/AWS_X509_CERT.pem \
      --size 10 \
      --url #{node[:rightimage][:ec2_endpoint]} \
      --availability-zone #{node[:ec2][:placement_availability_zone]} `

# parse out volume id
    vol_id=`echo -n $vol_out | awk '{ print $2 }'`

## attach an EBS volume here
    ec2-attach-volume $vol_id \
      --private-key /tmp/AWS_X509_KEY.pem \
      --cert /tmp/AWS_X509_CERT.pem \
      --device /dev/sdj \
      --url #{node[:rightimage][:ec2_endpoint]} \
      --instance #{node[:ec2][:instance_id]} 

    sleep 10

## loop and wait for volume to become available
    while [ 1 ]; do 
      vol_status=`ec2-describe-volumes $vol_id  --private-key /tmp/AWS_X509_KEY.pem --cert /tmp/AWS_X509_CERT.pem --url #{node[:rightimage][:ec2_endpoint]}`
      if `echo $vol_status | grep -q "attached"` ; then break; fi
      sleep 1
    done 

    sleep 10
## format and mount volume
    mkfs.ext3 -F /dev/sdj
    mount /dev/sdj $ebs_mount

## mount EBS volume, rsync, and unmount ebs volume
    rsync -a $image_mount/ $ebs_mount/
    umount $ebs_mount

## snapshot the ebs volume and save the snapshot id
    snap_out=`ec2-create-snapshot $vol_id \
      --private-key /tmp/AWS_X509_KEY.pem \
      --cert /tmp/AWS_X509_CERT.pem \
      --url #{node[:rightimage][:ec2_endpoint]} \
      --description "This snapshot will be used to create #{image_name}"`
      
# parse out snapshot id
    snap_id=`echo -n $snap_out | awk '{ print $2 }'`

    sleep 10

## loop and wait for snapshot to become available
    while [ 1 ]; do 
      snap_status=`ec2-describe-snapshots $snap_id --private-key /tmp/AWS_X509_KEY.pem --cert /tmp/AWS_X509_CERT.pem --url #{node[:rightimage][:ec2_endpoint]} `
      if `echo $snap_status | grep -q "completed"` ; then break; fi
      sleep 5
    done 

    image_out_ebs=`ec2-register \
      --private-key /tmp/AWS_X509_KEY.pem \
      --cert /tmp/AWS_X509_CERT.pem \
      --region $region \
      --url #{node[:rightimage][:ec2_endpoint]}\
      --architecture #{node[:rightimage][:arch]} \
      -b "sdb=ephemeral0" \
      --description "#{image_name}_EBS" \
      --name "#{image_name}_EBS" \
      --snapshot $snap_id \
      $kernel_opt \
      $ramdisk_opt \
      --root-device-name /dev/sda1 `
   
   # parse out image id
    image_id_s3=`echo -n $image_out_s3 | awk '{ print $2 }'`
    image_id_ebs=`echo -n $image_out_ebs | awk '{ print $2 }'`

    echo "$image_id_s3,$image_id_ebs" > /var/tmp/tag_these_images.csv

## detach volume
    ec2-detach-volume $vol_id \
      --private-key /tmp/AWS_X509_KEY.pem \
      --cert /tmp/AWS_X509_CERT.pem \
      --region $region \
      --url #{node[:rightimage][:ec2_endpoint]} \
      --force

    sleep 10

## delete volume
    ec2-delete-volume $vol_id \
      --private-key /tmp/AWS_X509_KEY.pem \
      --cert /tmp/AWS_X509_CERT.pem \
      --url #{node[:rightimage][:ec2_endpoint]} \
      --region $region 
   
    #remove keys
    rm -f /tmp/AWS_X509_KEY.pem
    rm -f  /tmp/AWS_X509_CERT.pem

    EOH
end 

include_recipe "rightimage::do_tag_images"