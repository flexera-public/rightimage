action :configure do

  ruby_block "check hypervisor" do
    block do
      raise "ERROR: you must set your hypervisor to xen!" unless new_resource.hypervisor == "xen"
    end
  end


  #  - add get_ssh_key script
  template "#{guest_root}/etc/init.d/getsshkey" do 
    source "getsshkey.erb" 
    mode "0544"
    backup false
  end

  execute "link_getsshkey" do 
    command  node[:rightimage][:getsshkey_cmd]
    environment({'GUEST_ROOT' => guest_root }) 
  end

  #  Add cloud tools to host
  cookbook_file "#{guest_root}/tmp/install_ec2_tools.sh" do
    source "install_ec2_tools.sh"
    mode "0755"
    backup false
  end
  execute "#{guest_root}/tmp/install_ec2_tools.sh" do
    environment(node[:rightimage][:script_env])
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

  loopback_fs loopback_file do
    mount_point guest_root
    bind_devices false
    action :mount
  end

  if is_ebs
    upload_ebs()
  else
    upload_s3()
  end

  loopback_fs loopback_file do
    mount_point guest_root
    action :unmount
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
  bash "create ebs volume" do 
    flags "-e"
    creates "/var/tmp/ebs_volume_id"
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

  # So in newer versions of software, devices are named xvdX, but amazon still 
  # expects the api calls for the devices to be named sdX, which the OS then 
  # remaps to xvdx.  In CentOS/RHEL case, remapping bumps up letter by 4. See 
  # https://bugzilla.redhat.com/show_bug.cgi?id=729586 for explanation - PS
  local_device = "/dev/sdj"
  case node[:platform]
  when "centos", "redhat"
    if node[:platform_version].to_f.between?(6.1, 6.2)
      local_device = "/dev/xvdn"
    elsif node[:platform_version].to_f >= 6.3
      local_device = "/dev/xvdj"
    end
  when "ubuntu"
    local_device = "/dev/xvdj" if node[:platform_version].to_f >= 10.10
  end

  bash "attach ebs volume" do 
    not_if "cat /proc/partitions | grep #{local_device.split("/dev/")[1]}"
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
      local_device=#{local_device}

  ## format and mount volume
      mkfs.ext3 -F ${local_device}
      root_label="#{node[:rightimage][:root_mount][:label_dev]}"
      tune2fs -L $root_label ${local_device}
      mount ${local_device} $ebs_mount

  ## mount EBS volume, rsync, and unmount ebs volume
      rsync -a $image_mount/ $ebs_mount/ --exclude '/proc'
  ## recreate the /proc mountpoint
      mkdir -p $ebs_mount/proc
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

  ## register image
      # EBS images don't support the maximum number of ephemeral devices
      # provided by the instance type unless you register them on the image or
      # when running the instance. (w-5974)
      set +x
      block_device_mapping="";
      i=0;

      # Register /dev/sdb -> ephemeral0 .. /dev/sdy -> ephemeral23 to support 24 ephemeral drives total.
      for letter in {b..y}; do
        block_device_mapping="$block_device_mapping --block-device-mapping \\"/dev/sd${letter}=ephemeral${i}\\" ";
        ((i = i + 1))
      done
      set -x

      image_out_ebs=`/home/ec2/bin/ec2-register \
        --private-key /tmp/AWS_X509_KEY.pem \
        --cert /tmp/AWS_X509_CERT.pem \
        --region $region \
        --url #{node[:rightimage][:ec2_endpoint]}\
        --architecture #{new_resource.arch} \
        $block_device_mapping \
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
end


def upload_s3()
  guest_root_nonpart=guest_root+"2"
  loopback_nonpart="#{temp_root}/#{ri_lineage}_hd0.raw"

  loopback_fs loopback_nonpart do
    device_number 1
    mount_point guest_root_nonpart
    partitioned false
    size_gb node[:rightimage][:root_size_gb].to_i
    action :create
  end

  bash "copy loopback fs" do
    flags "-e"
    code "rsync -a #{guest_root}/ #{guest_root_nonpart}/"
  end

  loopback_fs loopback_nonpart do
    device_number 1
    action :unmount
  end

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
      /home/ec2/bin/ec2-bundle-image --privatekey /tmp/AWS_X509_KEY.pem --cert /tmp/AWS_X509_CERT.pem --user #{node[:rightimage][:aws_account_number]} --image #{loopback_nonpart} --prefix #{image_name} --destination "#{temp_root}/bundled" --arch #{new_resource.arch} $kernel_opt $ramdisk_opt -B "ami=sda,root=/dev/sda1,ephemeral0=sdb,swap=sda3"

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
