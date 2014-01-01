require 'json'
require 'chef/log'

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

  # generate command to install getsshkey init script 
  case node[:rightimage][:platform]
    when "ubuntu" 
      getsshkey_cmd = "chroot $GUEST_ROOT update-rc.d getsshkey start 20 2 3 4 5 . stop 1 0 1 6 ."
    when "centos", "rhel"
      getsshkey_cmd = "chroot $GUEST_ROOT chkconfig --add getsshkey && \
                 chroot $GUEST_ROOT chkconfig --level 4 getsshkey on"
  end


  execute "link_getsshkey" do 
    command getsshkey_cmd
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
  execute "chroot #{guest_root} /tmp/install_ec2_tools.sh" do
    environment({'PLATFORM' => node[:rightimage][:platform]})
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
  is_ebs = new_resource.image_type =~ /ebs/i or new_resource.image_name =~ /_EBS/ or hvm?

  res = ec2_api_command("describe-images", {
    "owner" => "self",
    "filter" => "Name=name,Values=#{image_name}"
  })
  if res["Images"].length > 0
    raise("Found existing image, aborting: #{res.inspect}")
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

  ruby_block "Write out ami-id" do 
    block do 
      if is_ebs
        image_id = ::File.read("/var/tmp/image_id_ebs")
        image_type = "EBS"
      else
        image_id = ::File.read("/var/tmp/image_id_s3")
        image_type = nil
      end
      id_list = RightImage::IdList.new(Chef::Log)
      id_list.add(image_id, image_type)
    end
  end
end

def upload_ebs

  this_region = node[:ec2][:placement][:availability_zone].chop
  instance_id = node[:ec2][:instance_id]

  unless this_region == node[:rightimage][:region]
    raise ArgumentError, "attribute rightimage/region must be set to the region we're in (#{this_region}) for EBS image creation."
  end


## TBD THINK ABOUT VOLID IDEMPOTENCY
  if ::File.exists?("/var/tmp/ebs_volume_id")
    vol_id = ::File.read("/var/tmp/ebs_volume_id")
    Chef::Log.info("Using existing volume with id #{vol_id}")
    node["rightimage"]["ebs_volume_id"] = vol_id
  else
    ruby_block "Creating EBS volume" do
      block do 
        res = ec2_api_command("create-volume", {
          "size" => node[:rightimage][:root_size_gb],
          "availability-zone" => node[:ec2][:placement][:availability_zone]
          })
        vol_id = res["VolumeId"]
        Chef::Log.info("Created volume with id #{vol_id}")
        ::File.open("/var/tmp/ebs_volume_id","w") { |f| f.write(vol_id) }
        node["rightimage"]["ebs_volume_id"] = vol_id
      end
    end
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
  local_device_name = local_device.sub("/dev/","")


  ruby_block "Attach EBS volume" do
    block do 
      vol_attached = ::File.read("/proc/partitions").each_line.any? do |l| 
        l.include?(local_device_name)
      end

      unless vol_attached
        ec2_api_command("attach-volume", {
          "device" => local_device,
          "volume-id" => node["rightimage"]["ebs_volume_id"],
          "instance-id" => instance_id
          })
          sleep 20
      end
    end
  end

  ruby_block "Wait for volume to attach" do 
    block do 
      Timeout::timeout(60*20) do 
        while true
          status = ec2_api_command("describe-volumes", {"volume-ids" => node["rightimage"]["ebs_volume_id"]})
          attachments = status["Volumes"][0]["Attachments"]
          break if attachments.any? { |a| a["InstanceId"] == instance_id && a["State"] == "attached" }
          sleep 20
        end
      end
    end
  end
  

  ebs_mount = "/mnt/ebs_mount"

  bash "Format EBS volume" do 
    flags "-ex"
    code <<-EOH
      hvm=#{hvm?}

      ## partition volume (HVM only)
      if [ "$hvm" == "true" ]; then
        if [ ! -e #{local_device}1 ]; then
          parted -s #{local_device} mklabel msdos
          parted -s #{local_device} mkpart primary ext2 1024k 100% -a minimal
          parted -s #{local_device} set 1 boot on
        fi
        device="#{local_device}1"
      else
        device="#{local_device}"
      fi

      mkfs.ext3 -F $device > /dev/null
      root_label="#{node[:rightimage][:root_mount][:label_dev]}"
      tune2fs -L $root_label $device
      mkdir -p #{ebs_mount}
      mount $device #{ebs_mount}

      ## mount EBS volume, rsync, and unmount ebs volume
      rsync -a #{guest_root}/ #{ebs_mount}/ --exclude '/proc' --exclude '/sys' --exclude '/dev/'
      ## recreate the /proc mountpoint
      mkdir -p #{ebs_mount}/proc
      mkdir -p #{ebs_mount}/dev
    EOH
  end

  if hvm? 
    # TBD figure out to share code for tihs part
    # Bind devices
    bash "bind devices" do
      flags "-ex"
      code <<-EOF
        umount #{ebs_mount}/proc || true
        mkdir -p #{ebs_mount}/proc
        mount --bind /proc #{ebs_mount}/proc

        umount #{ebs_mount}/sys || true
        mkdir -p #{ebs_mount}/sys
        mount --bind /sys #{ebs_mount}/sys

        umount #{ebs_mount}/dev || true
        mkdir -p #{ebs_mount}/dev
        mount -t devtmpfs none #{ebs_mount}/dev
      EOF
    end

    # HVM doesn't use pvgrub, thus we need to re-set this up correctly
    rightimage_bootloader "grub" do
      root ebs_mount
      device local_device
      hypervisor node[:rightimage][:hypervisor]
      platform node[:rightimage][:platform]
      platform_version node[:rightimage][:platform_version].to_f
      cloud "ec2"
      action :install_bootloader
    end

    # Unbind devices
    bash "unbind devices" do 
      flags "-ex"
      code <<-EOF
        umount -lf #{ebs_mount}/dev/pts || true
        umount -lf #{ebs_mount}/dev || true
        umount -lf #{ebs_mount}/proc || true
        umount -lf #{ebs_mount}/sys || true
      EOF
    end
  end


  execute "umount #{ebs_mount}"

  ruby_block "Creating EBS snapshot" do
    block do 
      res = ec2_api_command("create-snapshot", {
        "volume-id" => node["rightimage"]["ebs_volume_id"],
        "description" => "This snapshot will be used to create #{image_name}"
        })

      snap_id = res["SnapshotId"]
      ::File.open("/var/tmp/ebs_snapshot_id","w") { |f| f.write(snap_id) }
      node["rightimage"]["ebs_snapshot_id"] = snap_id
      sleep 60 # Snapshot will take at least this long
    end
  end



  ## loop and wait for snapshot to become available, up to 60 minutes
  # Upped the time between polls quite a bit, hopefully avoid ClientRequestLimitExceeded better
  ruby_block "Wait for snapshot completion" do
    block do 
      Timeout::timeout(60*45) do 
        while true
          status = ec2_api_command("describe-snapshots", {"snapshot-id" => node["rightimage"]["ebs_snapshot_id"]})
          break if status["Snapshots"][0]["State"] == "completed"
          sleep 60
        end
      end
    end
  end

  ruby_block "Detach volume" do
    block do 
      ec2_api_command("detach-volume", { "volume-id" => node["rightimage"]["ebs_volume_id"], "instance-id" => instance_id, "force" => true })
      # TBD: Should get rid of the force parameter and wait for detachment here. 
      sleep 20
    end
  end

  ruby_block "Delete volume" do
    block do 
      ec2_api_command("delete-volume", { "volume-id" =>  vol_id })
    end
  end

  file "/var/tmp/ebs_volume_id" do 
    backup false
    action :delete
  end

  ruby_block "Register image" do 
    block do
      register_options = {
        "name" => image_name,
        "description" => image_name,
        "root-device-name" => "/dev/sda1",
        "architecture" => new_resource.arch
      }



      if hvm?
        # HVM doesn't use pvgrub, so don't pass in the kernel options
        register_options["virtualization-type"] = "hvm"
      else
        register_options["kernel"] = node[:rightimage][:aki_id] if node[:rightimage][:aki_id]
        register_options["ramdisk"] = node[:rightimage][:ramdisk_id] if node[:rightimage][:ramdisk_id]        
      end

      # EBS images don't support the maximum number of ephemeral devices
      # provided by the instance type unless you register them on the image or
      # when running the instance. (w-5974)
      mappings = [{ "DeviceName" => register_options["root-device-name"], "Ebs" => { "SnapshotId" => node["rightimage"]["ebs_snapshot_id"] } }.to_json]
      ("b".."y").each_with_index do |letter, i| 
        mappings << { "DeviceName" => "/dev/sd#{letter}", "VirtualName" => "ephemeral#{i}" }.to_json
      end
      register_options["block-device-mappings"] = mappings

      result = ec2_api_command("register-image", register_options)
      image_id = result["ImageId"]

      ::File.open("/var/tmp/image_id_ebs","w") do |f|
        f.write(image_id)
      end
    end
  end


  file "/var/tmp/ebs_snapshot_id" do 
    backup false
    action :delete
  end

end


def upload_s3()
  if hvm? 
    raise "HVM not supported for instance store"
  end

  # We rsync to a non-partitioned filesystem since ec2-ami-tools don't support bundling of 
  # of images that are partitioned -- the tools don't recreate the grub config faithfully
  # and always assume we're using the non-partioned pvgrub
  guest_root_nonpart=guest_root+"2"
  loopback_nonpart="#{target_raw_root}/#{ri_lineage}_hd0.qcow2"
  raw_image="#{target_raw_root}/#{loopback_rootname}.raw"
  keyfile = "/tmp/AWS_X509_KEY.pem"
  certfile = "/tmp/AWS_X509_CERT.pem"

  file keyfile do
    mode "0400"
    backup false
    content node[:rightimage][:aws_509_key]
    action :create
  end

  file certfile do
    mode "0400"
    backup false
    content node[:rightimage][:aws_509_cert]
    action :create
  end

  loopback_fs loopback_nonpart do
    device_number 1
    mount_point guest_root_nonpart
    partitioned false
    size_gb node[:rightimage][:root_size_gb].to_i
    action :create
  end

  bash "copy loopback fs" do
    not_if { ::File.exists? raw_image }
    flags "-e"
    code "rsync -a #{guest_root}/ #{guest_root_nonpart}/"
  end

  loopback_fs loopback_nonpart do
    not_if { ::File.exists? raw_image }
    device_number 1
    action :unmount
  end

  bundle_image_options = {
    "privatekey" => keyfile,
    "cert" => certfile,
    "user" => node[:rightimage][:aws_account_number],
    "image" => loopback_nonpart,
    "prefix" => image_name,
    "destination" => "#{temp_root}/bundled",
    "arch" => new_resource.arch,
    "block-device-mapping" => "ami=sda,root=/dev/sda1,ephemeral0=sdb,swap=sda3"
  }

  execute "rm -rf '#{temp_root}/bundled'"
  execute "mkdir -p '#{temp_root}/bundled'"

  execute "qemu-img convert -f qcow2 -O raw #{loopback_nonpart} #{raw_image}" do
    creates raw_image
  end

  ruby_block "Create and upload InstanceStore image bundle" do
    block do
      ec2_ami_command("bundle-image", bundle_image_options)
      ec2_ami_command("upload-bundle", {
        "bucket" => node[:rightimage][:image_upload_bucket], 
        "manifest" => "#{temp_root}/bundled/#{image_name}.manifest.xml",
        "access-key" => node[:rightimage][:aws_access_key_id],
        "secret-key" => node[:rightimage][:aws_secret_access_key],
        "retry" => true,
        "batch" => true
        })
    end
  end


  register_options = {
    "image-location" => "#{node[:rightimage][:image_upload_bucket]}/#{image_name}.manifest.xml",
    "description" => image_name,
    "name" => image_name
  }


  register_options["kernel"] = node[:rightimage][:aki_id] if node[:rightimage][:aki_id]
  register_options["ramdisk"] = node[:rightimage][:ramdisk_id] if node[:rightimage][:ramdisk_id]

  ruby_block "Register InstanceStore image" do 
    block do 
      result = ec2_api_command("register-image", register_options)
      image_id = result["ImageId"]
      ::File.open("/var/tmp/image_id_s3","w") do |f|
        f.write(image_id)
      end
    end
  end

  file raw_image do 
    action :delete
    backup false
  end

  file certfile do 
    action :delete
    backup false
  end

  file keyfile do 
    action :delete
    backup false
  end
end
