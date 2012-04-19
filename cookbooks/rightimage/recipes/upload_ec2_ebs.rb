rs_utils_marker :begin
class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end
class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end
class Chef::Resource::Execute
  include RightScale::RightImage::Helper
end

# Clean up guest image
rightimage guest_root do
  action :sanitize
end

execute "unset proc" do
  command "umount '#{guest_root}/proc' || true"
end

bash "setup keyfiles" do
  not_if { ::File.exists? "/tmp/AWS_X509_KEY.pem" }
  code <<-EOH
    echo "#{node[:rightimage][:aws_509_key]}" > /tmp/AWS_X509_KEY.pem
    echo "#{node[:rightimage][:aws_509_cert]}" > /tmp/AWS_X509_CERT.pem
  EOH
end

bash "check that image doesn't exist" do
  only_if { node[:rightimage][:cloud] == "ec2" }
  flags "-e"
  code <<-EOH
    #{setup_ec2_tools_env}
    set -x

    images=`/home/ec2/bin/ec2-describe-images --private-key /tmp/AWS_X509_KEY.pem --cert /tmp/AWS_X509_CERT.pem -o self --url #{node[:rightimage][:ec2_endpoint]} --filter name=#{image_name}_EBS`
    if [ -n "$images" ]; then
      echo "Found existing image, aborting:"
      echo $images
      exit 1
    fi 
  EOH
end

execute "mount loopback" do 
  not_if "mount | grep #{guest_root}"
  command "mount -o loop #{target_raw_path} #{guest_root}"
end


bash "create ebs volume" do 
  only_if { node[:rightimage][:cloud] == "ec2" }
  flags "-e"
  code <<-EOH
    #{setup_ec2_tools_env}
    set -x

## create EBS volume
    vol_out=`/home/ec2/bin/ec2-create-volume \
      --private-key /tmp/AWS_X509_KEY.pem \
      --cert /tmp/AWS_X509_CERT.pem \
      --size 8 \
      --url #{node[:rightimage][:ec2_endpoint]} \
      --availability-zone #{node[:ec2][:placement][:availability_zone]}`

# parse out volume id
    vol_id=`echo -n $vol_out | awk '{ print $2 }'`
    echo $vol_id > /var/tmp/ebs_volume_id
  EOH
end

bash "attach ebs volume" do 
  only_if { node[:rightimage][:cloud] == "ec2" }
  not_if "cat /proc/partitions | grep sdj"
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

    sleep 10

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
  only_if { node[:rightimage][:cloud] == "ec2" }
  not_if  { ::File.exists? "/var/tmp/ebs_snapshot_id" }
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
      --description "This snapshot will be used to create #{image_name}_EBS"`
      
# parse out snapshot id
    snap_id=`echo -n $snap_out | awk '{ print $2 }'`
    echo $snap_id > /var/tmp/ebs_snapshot_id
    sleep 60
  EOH
end

bash "register EBS snapshot" do 
  only_if { node[:rightimage][:cloud] == "ec2" }
  not_if { ::File.exists? "/var/tmp/image_id_ebs" }
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
      --architecture #{node[:rightimage][:arch]} \
      --block-device-mapping "/dev/sdb=ephemeral0" \
      --description "#{image_name}_EBS" \
      --name "#{image_name}_EBS" \
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

## upped time, occassionally 10 seconds is not enough
    sleep 20

## delete volume
    /home/ec2/bin/ec2-delete-volume $vol_id \
      --private-key /tmp/AWS_X509_KEY.pem \
      --cert /tmp/AWS_X509_CERT.pem \
      --url #{node[:rightimage][:ec2_endpoint]} \
      --region $region 
  EOH
end


execute "unmount guest root" do
  only_if "mount | grep #{guest_root}"
  command "umount -lf #{guest_root}"
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
  block do
    image_id = nil
    
    # read id which was written in previous stanza
    ::File.open("/var/tmp/image_id_ebs", "r") { |f| image_id = f.read() }
    
    # add to global id store for use by other recipes
    id_list = RightImage::IdList.new(Chef::Log)
    id_list.add(image_id, "EBS")
  end
end
rs_utils_marker :end
