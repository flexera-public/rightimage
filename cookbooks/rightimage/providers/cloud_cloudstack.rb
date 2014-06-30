class Chef::Resource
  include RightScale::RightImage::Helper
end



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


  bash "configure for cloudstack" do
    flags "-ex" 
    code <<-EOH
      guest_root=#{guest_root}

      case "#{new_resource.hypervisor}" in
      "kvm")
        # following found on functioning CDC test image Centos 64bit using KVM hypervisor
        echo "alias scsi_hostadapter ata_piix"     > $guest_root/etc/modprobe.conf
        echo "alias scsi_hostadapter1 virtio_blk" >> $guest_root/etc/modprobe.conf
        echo "alias eth0 virtio_net"              >> $guest_root/etc/modprobe.conf
        ;;
      esac

      case "#{new_resource.platform}" in
      "ubuntu")
        case "#{new_resource.hypervisor}" in
        "xen")
          # enable console access
          cp $guest_root/etc/init/tty1.conf* $guest_root/etc/init/hvc0.conf
          sed -i "s/tty1/hvc0/g" $guest_root/etc/init/hvc0.conf
          echo "hvc0" >> $guest_root/etc/securetty

          for i in $guest_root/etc/init/tty*; do
            mv $i $i.disabled;
          done
          ;;
        "kvm"|"esxi")
          # Disable all ttys except for tty1 (console)
          for i in `ls $guest_root/etc/init/tty[2-9].conf`; do
            mv $i $i.disabled;
          done
          ;;
        esac
        ;;
      "centos"|"rhel")
        # clean out packages
        chroot $guest_root yum -y clean all

        # clean centos RPM data
        rm -rf ${guest_root}/var/lib/rpm/__*
        chroot $guest_root rpm --rebuilddb

        # configure dhcp timeout
        echo 'timeout 300;' > $guest_root/etc/dhclient.conf

        case "#{new_resource.hypervisor}" in
        "xen")
          if [ ! -f $guest_root/etc/sysconfig/init ]; then
            echo "2:2345:respawn:/sbin/mingetty xvc0" >> $guest_root/etc/inittab
            echo "xvc0" >> $guest_root/etc/securetty
          fi
          ;;
        "esxi")
          # Setup console
          [ -f $guest_root/etc/sysconfig/init ] && sed -i "s/ACTIVE_CONSOLES=.*/ACTIVE_CONSOLES=\\/dev\\/tty1/" $guest_root/etc/sysconfig/init
          ;;
        "kvm")

          # enable console access
          if [ -f $guest_root/etc/sysconfig/init ]; then
            sed -i "s/ACTIVE_CONSOLES=.*/ACTIVE_CONSOLES=\\/dev\\/tty1/" $guest_root/etc/sysconfig/init
          else
            echo "2:2345:respawn:/sbin/mingetty tty2" >> $guest_root/etc/inittab
            echo "tty2" >> $guest_root/etc/securetty
          fi
          ;;
        esac
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
  CDC_GEM_VER = "0.0.0"
  CDC_GEM = ::File.join(::File.dirname(__FILE__), "..", "files", "default", "right_cloud_api-#{CDC_GEM_VER}.gem")
  
  chef_gem CDC_GEM do
    version CDC_GEM_VER
    action :install
  end

  tools_temp = "/tmp/rightimage_tools"
  directory tools_temp

  remote_file "#{tools_temp}/rightimage_tools.tgz" do
    source "#{node[:rightimage][:s3_base_url]}/files/rightimage_tools_0.7.5.tar.gz"
    action :create_if_missing
  end

  execute "tar zxf #{tools_temp}/rightimage_tools.tgz -C #{tools_temp}" do
    creates "#{tools_temp}/bin"
  end

  ruby_block "trigger download to test cloud" do
    block do
      require "#{tools_temp}/lib/cloudstack_uploader"

      aws_url  = "rightscale-cloudstack-dev.s3.amazonaws.com"
      aws_path = new_resource.hypervisor+"/"+new_resource.platform+"/"+new_resource.platform_version.to_s
      filename = "#{new_resource.image_name}.#{image_file_ext}"
      image_url = "http://#{aws_url}/#{aws_path}/#{filename}"

      options = {}
      options[:endpoint] = node[:rightimage][:cloudstack][:cdc_url]
      options[:name]     = "#{new_resource.image_name}_#{new_resource.hypervisor.upcase}"
      options[:source]   = image_url
      options[:zone_id]  = node[:rightimage][:datacenter]

      ENV['CLOUDSTACK_API_KEY'] = node[:rightimage][:cloudstack][:cdc_api_key]
      ENV['CLOUDSTACK_SECRET_KEY'] = node[:rightimage][:cloudstack][:cdc_secret_key]

      uploader = RightImageTools::CloudstackUploader.new(options, Chef::Log)
      uploader.register()
    end
  end
end

