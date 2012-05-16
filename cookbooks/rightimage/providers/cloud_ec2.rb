action :configure do
  # insert grub conf, and link menu.lst to grub.conf
  directory "#{guest_root}/boot/grub" do
    owner "root"
    group "root"
    mode "0750"
    action :create
    recursive true
  end 

  # Setup grub Version 1, ec2
  template "#{guest_root}/boot/grub/grub.conf" do 
    source "menu.lst.erb"
    backup false 
  end

  file "#{guest_root}/boot/grub/menu.lst" do 
    action :delete
    backup false
  end

  link "#{guest_root}/boot/grub/menu.lst" do 
    link_type :hard # soft symlinks don't work outside chrooted env
    to "#{guest_root}/boot/grub/grub.conf"
  end

  #  - add get_ssh_key script
  template "#{guest_root}/etc/init.d/getsshkey" do 
    source "getsshkey.erb" 
    mode "0544"
    backup false
  end

  execute "link_getsshkey" do 
    command  node[:rightimage][:getsshkey_cmd]
    environment ({'GUEST_ROOT' => guest_root }) 
  end

  #  - add cloud tools
  bash "install_ec2_tools" do 
    creates "#{guest_root}/home/ec2/bin"
    flags "-ex"
    code <<-EOH
      ROOT=#{guest_root}
      rm -rf $ROOT/home/ec2 || true
      mkdir -p $ROOT/home/ec2
      curl -o $ROOT/tmp/ec2-api-tools.zip http://s3.amazonaws.com/ec2-downloads/ec2-api-tools.zip
      curl -o $ROOT/tmp/ec2-ami-tools.zip http://s3.amazonaws.com/ec2-downloads/ec2-ami-tools.zip
      unzip $ROOT/tmp/ec2-api-tools.zip -d $ROOT/tmp/
      unzip $ROOT/tmp/ec2-ami-tools.zip -d $ROOT/tmp/
      cp -r $ROOT/tmp/ec2-api-tools-*/* $ROOT/home/ec2/.
      rsync -av $ROOT/tmp/ec2-ami-tools-*/ $ROOT/home/ec2
      rm -r $ROOT/tmp/ec2-a*
      echo 'export PATH=/home/ec2/bin:${PATH}' >> $ROOT/etc/profile.d/ec2.sh
      echo 'export EC2_HOME=/home/ec2' >> $ROOT/etc/profile.d/ec2.sh
      chroot $ROOT gem install s3sync --no-ri --no-rdoc
    EOH
  end
   
  bash "do_depmod" do 
    flags "-ex"
    only_if { node[:rightimage][:platform] == "centos" }
    code <<-EOH
    for module_version in $(cd #{guest_root}/lib/modules; ls); do
      chroot #{guest_root} depmod -a $module_version
    done
    EOH
  end 
end

action :package do
end


action :upload do
  is_ebs = new_resource.image_type =~ /ebs/i or new_resource.image_name =~ /_EBS/

  bash "setup keyfiles" do
    not_if { ::File.exists? "/tmp/AWS_X509_KEY.pem" }
    code <<-EOH
      echo "#{node[:rightimage][:aws_509_key]}" > /tmp/AWS_X509_KEY.pem
      echo "#{node[:rightimage][:aws_509_cert]}" > /tmp/AWS_X509_CERT.pem
    EOH
  end

  bash "check that image doesn't exist" do
    flags "-e"
    code <<-EOH
      #{setup_ec2_tools_env}
      set -x

      images=`/home/ec2/bin/ec2-describe-images --private-key /tmp/AWS_X509_KEY.pem --cert /tmp/AWS_X509_CERT.pem -o self --url #{node[:rightimage][:ec2_endpoint]} --filter name=#{image_name}`
      if [ -n "$images" ]; then
        echo "Found existing image, aborting:"
        echo $images
        exit 1
      fi 
    EOH
  end

  if is_ebs
    upload_ebs()
  else
    upload_s3()
  end

  bash "remove keys" do
    only_if { ::File.exists? "/tmp/AWS_X509_KEY.pem" }
    code <<-EOH
      #remove keys
      rm -f /tmp/AWS_X509_KEY.pem
      rm -f /tmp/AWS_X509_CERT.pem
    EOH
  end 

  ruby_block "store image id" do
    id_file = is_ebs ? "/var/tmp/image_id_ebs" : "/var/tmp/image_id_s3"
    image_type = is_ebs ? "EBS" : nil
    block do
      image_id = nil
      
      # read id which was written in previous stanza
      ::File.open(id_file, "r") { |f| image_id = f.read() }
      
      # add to global id store for use by other recipes
      id_list = RightImage::IdList.new(Chef::Log)
      id_list.add(image_id, image_type)
    end
  end
end

def upload_ebs
  loopback_fs loopback_file(false) do
    mount_point guest_root
    partitioned false
    action :mount
  end


  bash "create ebs volume" do 
    flags "-e"
    code <<-EOH
      #{setup_ec2_tools_env}
      set -x

  ## create EBS volume
      vol_out=`/home/ec2/bin/ec2-create-volume \
        --private-key /tmp/AWS_X509_KEY.pem \
        --cert /tmp/AWS_X509_CERT.pem \
        --size #{node[:rightimage][:root_size_gb]} \
        --url #{node[:rightimage][:ec2_endpoint]} \
        --availability-zone #{node[:ec2][:placement][:availability_zone]}`

  # parse out volume id
      vol_id=`echo -n $vol_out | awk '{ print $2 }'`
      echo $vol_id > /var/tmp/ebs_volume_id
    EOH
  end

  bash "attach ebs volume" do 
#    not_if "cat /proc/partitions | grep sdj"
    flags "-e"
    code <<-EOH
      #{setup_ec2_tools_env}
      set -x
      vol_id=`cat /var/tmp/ebs_volume_id`

  ## attach an EBS volume here
      /home/ec2/bin/ec2-attach-volume $vol_id \
        --private-key /tmp/AWS_X509_KEY.pem \
        --cert /tmp/AWS_X509_CERT.pem \
        --device /dev/sdj \
        --url #{node[:rightimage][:ec2_endpoint]} \
        --instance #{node[:ec2][:instance_id]} 

      sleep 20

  ## loop and wait for volume to become available, up to 20 minutes
      for i in `seq 1 60`; do
        vol_status=`/home/ec2/bin/ec2-describe-volumes $vol_id  --private-key /tmp/AWS_X509_KEY.pem --cert /tmp/AWS_X509_CERT.pem --url #{node[:rightimage][:ec2_endpoint]}`
        if `echo $vol_status | grep -q "attached"` ; then break; fi
        sleep 20
      done 

      sleep 10
    EOH
  end

  bash "create EBS snapshot" do 
#    not_if  { ::File.exists? "/var/tmp/ebs_snapshot_id" }
    flags "-e"
    code <<-EOH
      #{setup_ec2_tools_env}
      set -x
      vol_id=`cat /var/tmp/ebs_volume_id`
      ebs_mount="/mnt/ebs_mount"
      mkdir -p $ebs_mount
      image_mount=#{guest_root}

  ## format and mount volume
      mkfs.ext3 -F /dev/sdj
      root_label="#{node[:rightimage][:root_mount][:label_dev]}"
      tune2fs -L $root_label /dev/sdj
      mount /dev/sdj $ebs_mount

  ## mount EBS volume, rsync, and unmount ebs volume
      rsync -a $image_mount/ $ebs_mount/ --exclude '/proc'
  ## recreate the /proc mountpoint
      mkdir -p $ebs_mount/proc
  #    mount --bind /proc $ebs_mount/proc
      umount $ebs_mount

  ## snapshot the ebs volume and save the snapshot id
      snap_out=`/home/ec2/bin/ec2-create-snapshot $vol_id \
        --private-key /tmp/AWS_X509_KEY.pem \
        --cert /tmp/AWS_X509_CERT.pem \
        --url #{node[:rightimage][:ec2_endpoint]} \
        --description "This snapshot will be used to create #{image_name}"`
        
  # parse out snapshot id
      snap_id=`echo -n $snap_out | awk '{ print $2 }'`
      echo $snap_id > /var/tmp/ebs_snapshot_id
      sleep 60
    EOH
  end

  bash "register EBS snapshot" do 
#    not_if { ::File.exists? "/var/tmp/image_id_ebs" }
    flags "-e"
    code <<-EOH
      #{setup_ec2_tools_env}
      set -x
      snap_id=`cat /var/tmp/ebs_snapshot_id`
      vol_id=`cat /var/tmp/ebs_volume_id`
  ## loop and wait for snapshot to become available, up to 60 minutes
  # Upped the time between polls quite a bit, hopefully avoid ClientRequestLimitExceeded better
  # Turn off error checking temporarily, if we get Req. limit exceeded we don't want it to stop us
      for i in `seq 1 60`; do
        set +e
        snap_status=`/home/ec2/bin/ec2-describe-snapshots $snap_id --private-key /tmp/AWS_X509_KEY.pem --cert /tmp/AWS_X509_CERT.pem --url #{node[:rightimage][:ec2_endpoint]} `
        set -e
        if `echo $snap_status | grep -q "completed"` ; then break; fi
        sleep 60
      done 

  ## calculate options
      kernel_opt=""
      if [ -n "#{node[:rightimage][:aki_id]}" ]; then
        kernel_opt="--kernel #{node[:rightimage][:aki_id]}"
      fi 

      ramdisk_opt=""
      if [ -n "#{node[:rightimage][:ramdisk_id]}" ]; then
        ramdisk_opt="--ramdisk #{node[:rightimage][:ramdisk_id]}"
      fi

  ## calculate ec2 region
      region=#{node[:ec2][:placement][:availability_zone].chop}

      image_out_ebs=`/home/ec2/bin/ec2-register \
        --private-key /tmp/AWS_X509_KEY.pem \
        --cert /tmp/AWS_X509_CERT.pem \
        --region $region \
        --url #{node[:rightimage][:ec2_endpoint]}\
        --architecture #{new_resource.arch} \
        --block-device-mapping "/dev/sdb=ephemeral0" \
        --description "#{image_name}" \
        --name "#{image_name}" \
        --snapshot $snap_id \
        $kernel_opt \
        $ramdisk_opt \
        --root-device-name /dev/sda1 `

  ## parse out image id
      image_id_ebs=`echo -n $image_out_ebs | awk '{ print $2 }'`
      echo "$image_id_ebs" > /var/tmp/image_id_ebs

  ## detach volume
      /home/ec2/bin/ec2-detach-volume $vol_id \
        --private-key /tmp/AWS_X509_KEY.pem \
        --cert /tmp/AWS_X509_CERT.pem \
        --region $region \
        --url #{node[:rightimage][:ec2_endpoint]} \
        --force

      sleep 10

  ## delete volume
      /home/ec2/bin/ec2-delete-volume $vol_id \
        --private-key /tmp/AWS_X509_KEY.pem \
        --cert /tmp/AWS_X509_CERT.pem \
        --url #{node[:rightimage][:ec2_endpoint]} \
        --region $region 
    EOH
  end

  loopback_fs loopback_file(false) do
    mount_point guest_root
    action :unmount
  end

end


def upload_s3()
  # bundle and upload
  bash "bundle_upload_s3_image" do 
    flags "-e"
    code <<-EOH
      #{setup_ec2_tools_env}
      set -x
      
      kernel_opt=""
      if [ -n "#{node[:rightimage][:aki_id]}" ]; then
        kernel_opt="--kernel #{node[:rightimage][:aki_id]}"
      fi 

      ramdisk_opt=""
      if [ -n "#{node[:rightimage][:ramdisk_id]}" ]; then
        ramdisk_opt="--ramdisk #{node[:rightimage][:ramdisk_id]}"
      fi

      echo "Doing S3 bundle"
    
      rm -rf "#{temp_root}/bundled"
      mkdir -p "#{temp_root}/bundled"

      echo "Bundling..."
      /home/ec2/bin/ec2-bundle-image --privatekey /tmp/AWS_X509_KEY.pem --cert /tmp/AWS_X509_CERT.pem --user #{node[:rightimage][:aws_account_number]} --image #{loopback_file(partitioned?)} --prefix #{image_name} --destination "#{temp_root}/bundled" --arch #{new_resource.arch} $kernel_opt $ramdisk_opt -B "ami=sda1,root=/dev/sda1,ephemeral0=sdb,swap=sda3"
     
      echo "Uploading..." 
      echo y | /home/ec2/bin/ec2-upload-bundle -b #{node[:rightimage][:image_upload_bucket]} -m "#{temp_root}/bundled/#{image_name}.manifest.xml" -a #{node[:rightimage][:aws_access_key_id]} -s #{node[:rightimage][:aws_secret_access_key]} --retry --batch
      
      echo registering... 
      image_out_s3=`/home/ec2/bin/ec2-register #{node[:rightimage][:image_upload_bucket]}/#{image_name}.manifest.xml -K  /tmp/AWS_X509_KEY.pem -C  /tmp/AWS_X509_CERT.pem -n "#{image_name}" --url #{node[:rightimage][:ec2_endpoint]} `

      ## parse out image id
      image_id_s3=`echo -n $image_out_s3 | awk '{ print $2 }'`
      echo "$image_id_s3" > /var/tmp/image_id_s3
      EOH
  end 
end
