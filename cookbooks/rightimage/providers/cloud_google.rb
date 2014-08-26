class Chef::Resource
  include RightScale::RightImage::Helper
end

action :configure do

  ruby_block "check hypervisor" do
    block do
      raise "ERROR: you must set your hypervisor to kvm!" unless new_resource.hypervisor == "kvm"
    end
  end

  execute "install iscsi tools" do
    only_if { node[:rightimage][:platform] =~ /redhat|rhel|centos/ }
    command "chroot #{guest_root} yum -y install iscsi-initiator-utils"
  end

  # See https://github.com/GoogleCloudPlatform/compute-image-packages for google startup
  # scripts for all the various platforms. Prepared the tarball with:
  #   git clone https://github.com/GoogleCloudPlatform/compute-image-packages
  #   cd compute-image-packages/google-startup-scripts
  #   tar --exclude etc/rc.local -zcvf ../google-startup-scripts-master-20140718.tar.gz etc lib usr
  if (new_resource.platform =~ /centos|rhel/ && new_resource.platform_version.to_f >= 5) || new_resource.platform == "ubuntu"
    # Add google init scripts. All system startup types (upstart, systemd, sysvinit)
    # get extracted, though they will only be used as needed. We still need to 
    remote_file "/tmp/google-startup-scripts.tar.gz" do
      source "#{node[:rightimage][:s3_base_url]}/files/google-startup-scripts-v1.1.6.tar.gz"
      action :create_if_missing
      backup false
    end

    bash "extract google startup scripts" do
      flags "-ex"
      code <<-EOF
        if [ -x #{guest_root}/bin/systemctl ]; then
          echo "Installing systemd google startup scripts"
          exclusions="--exclude etc/init.d --exclude etc/init"
        elif [ -x #{guest_root}/sbin/initctl ]; then 
          echo "Installing upstart google startup scripts"
          exclusions="--exclude etc/init.d --exclude usr/lib/systemd"
        else
          echo "Installing sysvinit google startup scripts"
          exclusions="--exclude etc/init --exclude usr/lib/systemd"
        fi
        tar $exclusions -C #{guest_root}/ -zhxvf /tmp/google-startup-scripts.tar.gz
      EOF
    end

    # Add the needed upstart job emission to /etc/rc.local, conditional on upstart
    # being present, but only if it's not already in the file. stolen from the .rpm
    # postinstall scriptlet
    # Note that this comes after and appends the /etc/rc.local written in KVM provider
    bash "finish google startup scripts installation" do
      flags "-ex"
      code <<-EOF
        if [ -x #{guest_root}/bin/systemctl ]; then
          chroot #{guest_root} systemctl enable google-startup-scripts.service
          chroot #{guest_root} systemctl enable google.service
        elif [ -x #{guest_root}/sbin/initctl ]; then 
          grep -q 'google-rc-local-has-run' #{guest_root}/etc/rc.local && exit 0
          echo "initctl emit --no-wait google-rc-local-has-run" >> #{guest_root}/etc/rc.local
          chmod 755 #{guest_root}/etc/rc.local
        fi
      EOF
    end
  else
    raise "Unsupported platform/version combination #{new_resource.platform} #{new_resource.platform_version}"
  end


  bash "configure for google compute" do
    flags "-ex" 
    environment(node[:rightimage][:script_env])

    code <<-EOH
      guest_root=#{guest_root}

      # Set HW clock to UTC
      echo "UTC" >> $guest_root/etc/adjtime

      case "#{new_resource.platform}" in
      "centos"|"rhel")
        # enable console access
        sed -i "s/ACTIVE_CONSOLES=.*/ACTIVE_CONSOLES=\\/dev\\/tty1/" $guest_root/etc/sysconfig/init
        ;;
      "ubuntu")
        chroot $guest_root apt-get -y install acpid dhcp3-client

        # Need to install backported kernel from 13.04
        # NOTE: this image should not be used in production!!
        # Precise kernel doesn't support SCSI_VIRTIO driver.
        # Quantal kernel doesn't show attached volumes. (w-6223)
        if [ "#{node[:rightimage][:platform_version]}" == "12.04" ]; then
          chroot $guest_root apt-get -y install linux-generic-lts-raring
        fi

        # Disable all ttys except for tty1 (console)
        for i in `ls $guest_root/etc/init/tty[2-9].conf`; do
          mv $i $i.disabled;
        done
        ;;
      esac

      set +e
      # Add metadata alias
      grep -E 'metadata' $guest_root/etc/hosts &> /dev/null
      if [ "$?" != "0" ]; then
        echo '169.254.169.254 metadata.google.internal metadata' >> $guest_root/etc/hosts
      fi
      set -e
    EOH
  end
end

action :package do
  loopback_raw="#{loopback_rootname}.raw"
  execute "qemu-img convert -f qcow2 -O raw #{loopback_file} #{loopback_raw}" do
    cwd target_raw_root
  end

  file "#{target_raw_root}/disk.raw" do
    action :delete
    backup false
  end
  # Chef file resource doesn't do this correctly for some reason
  bash "hard link to disk.raw" do
    cwd target_raw_root
    code "ln #{loopback_raw} disk.raw"
  end
  bash "zipping raw file" do
    cwd target_raw_root
    code "tar zcvf #{new_resource.image_name}.tar.gz disk.raw"
  end
end

action :upload do
  cookbook_file "/tmp/install_google_tools.sh" do
    source "install_google_tools.sh"
    mode "0755"
    action :create
    backup false
  end

  execute "/tmp/install_google_tools.sh" do
    environment(node[:rightimage][:script_env])
  end

  # TBD, replace this block. We use the gsutil/gcutil tools to do this, but we
  # need to generate the refresh_token on another computer (see rightimage_tools/google_token)
  # We can skip this and use the api directly with the "service accounts" oauth method
  # but these tools don't support that control flow and need to look into doing
  # it with google-api-python or google-api-ruby separately. don't think those tools
  # work yet either, revisit later
  template "/root/.gcutil_auth" do
    source "gcutil_auth.erb"
    variables(
      :client_id => node[:rightimage][:google][:client_id],
      :client_secret => node[:rightimage][:google][:client_secret],
      :refresh_token => node[:rightimage][:google][:refresh_token]
    )
    backup false
  end

  template "/root/.boto" do
    source "google_boto.erb"
    variables(
      :gc_access_key_id     => node[:rightimage][:google][:gc_access_key_id],
      :gc_secret_access_key => node[:rightimage][:google][:gc_secret_access_key]
    )
    backup false
  end

  bash "upload image" do
    image = "#{target_raw_root}/#{new_resource.image_name}.tar.gz"
    code <<-EOF
      if [ ! -e #{image} ]; then
        echo "ERROR: file #{image} does not exist, aborting upload!"
        exit 1
      fi
      /usr/local/gsutil/gsutil cp #{image} gs://#{node[:rightimage][:image_upload_bucket]}/
    EOF
  end

  ruby_block "register image" do
    block do
      command = "/usr/local/gcutil/gcutil addimage \"#{new_resource.image_name}\" " +
        "\"http://commondatastorage.googleapis.com/#{node[:rightimage][:image_upload_bucket]}/#{new_resource.image_name}.tar.gz\" " +
        "--preferred_kernel='' " +
        "--project=#{node[:rightimage][:google][:project_id]}"
      Chef::Log.info("Running command: #{command}")
      `#{command}`
      raise "Registration failed" unless $?.success?
    end
  end

  # Needed to create the MCI, pulled by right_image_builder
  ruby_block "store id" do
    block do
      id_list = RightImage::IdList.new(Chef::Log)
      id_list.add("projects/#{node[:rightimage][:google][:project_id]}/images/"+new_resource.image_name)
    end
  end
end

