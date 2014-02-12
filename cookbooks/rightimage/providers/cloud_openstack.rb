action :configure do 
  execute "install iscsi tools" do 
    only_if { node[:rightimage][:platform] =~ /redhat|rhel|centos/ }
    command "chroot #{guest_root} yum -y install iscsi-initiator-utils"
  end

  Chef::Log::info "Add DHCP symlink for RightLink"
  execute "chroot #{guest_root} ln -s /var/lib/dhcp /var/lib/dhcp3" do
    only_if { ::File.exists?"#{guest_root}/var/lib/dhcp" }
    creates "#{guest_root}/var/lib/dhcp3"
  end

  
  bash "configure for openstack" do
    flags "-ex"
    code <<-EOH
      guest_root=#{guest_root}

      case "#{node[:rightimage][:platform]}" in
      "centos"|"rhel")
        # clean out packages
        chroot $guest_root yum -y clean all

        # clean centos RPM data
        rm ${guest_root}/var/lib/rpm/__*
        chroot $guest_root rpm --rebuilddb

        # enable console access
        if [ -f $guest_root/etc/sysconfig/init ]; then
          sed -i "s/ACTIVE_CONSOLES=.*/ACTIVE_CONSOLES=\\/dev\\/tty1/" $guest_root/etc/sysconfig/init
        else
          echo "2:2345:respawn:/sbin/mingetty tty2" >> $guest_root/etc/inittab
          echo "tty2" >> $guest_root/etc/securetty
        fi

        # configure dhcp timeout
        echo 'timeout 300;' > $guest_root/etc/dhclient.conf

        [ -f $guest_root/var/lib/rpm/__* ] && rm ${guest_root}/var/lib/rpm/__*
        chroot $guest_root rpm --rebuilddb
        ;;
      "ubuntu")
        # Disable all ttys except for tty1 (console)
        for i in `ls $guest_root/etc/init/tty[2-9].conf`; do
          mv $i $i.disabled;
        done
        ;;
      esac

      # set hwclock to UTC
      echo "UTC" >> $guest_root/etc/adjtime
    EOH
  end
end

action :package do
  rightimage_image node[:rightimage][:image_type] do
    action :package
  end
end

action :upload do
  # TODO: Probably need to add a dependency for gcc
  packages = case node[:platform]
             when "centos", "redhat" then
               %w(python-devel python-libs openssl-devel python-pip)
             when "ubuntu" then
               %w(python-dev libssl-dev python-pip)
             end

  packages.each { |p| package p }

  # Create bundle using pip bundle command on instance
  remote_file "/tmp/glance.pybundle" do
    source "#{node[:rightimage][:s3_base_url]}/files/glance-0.12.0.pybundle"
    action :create_if_missing
  end

  bash "install python modules" do
    flags "-ex"
    environment(node[:rightimage][:script_env])
    code "pip install /tmp/glance.pybundle"
  end

  ruby_block "upload to cloud" do
    block do
      require 'json'

      # Fetches a glance property from the command output
      def get_property(output, property_name)
        Array(output.scan(/#{property_name}\s*[:|]\s+([^ |]+)/i)).flatten.first
      end

      filename = "#{image_name}.qcow2"

      aws_url  = "rightscale-openstack-dev.s3.amazonaws.com"
      aws_path = node[:rightimage][:hypervisor]+"/"+node[:rightimage][:platform]+"/"+node[:rightimage][:platform_version].to_s
      image_url = "http://#{aws_url}/#{aws_path}/#{filename}"

      openstack_user = node[:rightimage][:openstack][:user]
      openstack_password = node[:rightimage][:openstack][:password]
      openstack_tenant = node[:rightimage][:openstack][:tenant]
      openstack_host = node[:rightimage][:openstack][:hostname].split(":")[0].sub(/http(s)?:\/\//,"")
      openstack_api_port = node[:rightimage][:openstack][:hostname].split(":")[1] || "5000"

      # Don't use location=file://path/to/file like you might think, thats the name of the location to store the file on the server that hosts the images, not this machine
      auth_property = "--os-username '#{openstack_user}' --os-password '#{openstack_password}' --os-auth-url http://#{openstack_host}:#{openstack_api_port}/v2.0 --os-tenant-name #{openstack_tenant}"
      cmd = %Q(env PATH=$PATH:/usr/local/bin glance #{auth_property} image-create --name #{image_name} --is-public True --disk-format qcow2 --container-format bare --copy-from #{image_url})
      Chef::Log.info "Executing command: "
      Chef::Log.info cmd
      upload_resp = `#{cmd}`
      Chef::Log.info("got response for upload req: #{upload_resp} to cloud.")

      image_id = get_property(upload_resp, "id")

      if image_id
        Chef::Log.info "Uploaded image with id #{image_id}"
      else
        raise "ERROR! Could not parse image_id from glance response"
      end


      require 'timeout'
      wait_timer = 3600
      Chef::Log.info "Waiting up to #{wait_timer} seconds for image to become active"
      Timeout::timeout(wait_timer) do 
        while true
          cmd = "env PATH=$PATH:/usr/local/bin glance #{auth_property} image-show #{image_id}"
          output = `#{cmd}`
          status = get_property(output, "status")
          img_checksum = get_property(output, "checksum")
          Chef::Log.info "Waiting for image to be active, current status: #{status}"

          if status =~ /active/i
            Chef::Log.info "SUCCESS!, image successfully uploaded with checksum #{img_checksum}"
            break
          elsif status =~ /error|kill|fail/i
            Chef::Log.error "FAILURE!, uploaded image #{image_id} is in error state"
            Chef::Log.error "LAST OUTPUT:"
            raise output
          end
          sleep 30
        end

        # add to global id store for use by other recipes
        id_list = RightImage::IdList.new(Chef::Log)
        id_list.add(image_id)
      end
    end
  end
end
