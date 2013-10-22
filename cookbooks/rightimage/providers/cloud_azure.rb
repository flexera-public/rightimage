class Chef::Resource
  include RightScale::RightImage::Helper
end


action :configure do
  package "grub"
  
  ruby_block "check hypervisor" do
    block do
      raise "ERROR: you must set your hypervisor to hyperv!" unless new_resource.hypervisor == "hyperv"
    end
  end
  
  bash "install guest packages" do 
    flags '-ex'
    code <<-EOH
      case "#{new_resource.platform}" in
      "ubuntu")
        chroot #{guest_root} apt-get -y purge grub-pc
        chroot #{guest_root} apt-get -y install grub
        ;;
      "centos"|"rhel")
        chroot #{guest_root} yum -y install grub iscsi-initiator-utils
        ;;
      esac
    EOH
  end

  # insert grub conf, and link menu.lst to grub.conf
  directory "#{guest_root}/boot/grub" do
    owner "root"
    group "root"
    mode "0750"
    action :create
    recursive true
  end 

  # insert grub conf, and symlink
  template "#{guest_root}/boot/grub/menu.lst" do
    source "menu.lst.erb"
    backup false 
  end

  bash "setup grub" do
    flags "-ex"
    code <<-EOH
      guest_root="#{guest_root}"
      
      case "#{new_resource.platform}" in
        "ubuntu")
          chroot $guest_root cp -p /usr/lib/grub/x86_64-pc/* /boot/grub
          grub_command="/usr/sbin/grub"
          ;;
        "centos"|"rhel")
          chroot $guest_root cp -p /usr/share/grub/x86_64-redhat/* /boot/grub
          grub_command="/sbin/grub"
          ;;
      esac

      echo "(hd0) #{node[:rightimage][:grub][:root_device]}" > $guest_root/boot/grub/device.map
      echo "" >> $guest_root/boot/grub/device.map

      cat > device.map <<EOF
(hd0) #{loopback_file}
EOF

    ${grub_command} --batch --device-map=device.map <<EOF
root (hd0,0)
setup (hd0)
quit
EOF
EOH
  end

  # Install Openlogic supplied kernel to support Azure (w-5335)
  template "#{guest_root}/etc/yum.repos.d/Openlogic.repo" do
     only_if { node[:rightimage][:platform] == "centos" }
    source "openlogic.repo.erb"
    backup false
  end

  bash "configure for azure" do
    flags "-ex"
    code <<-EOH
      guest_root=#{guest_root}

      # Disable all ttys except for tty1 (console)
      case "#{new_resource.platform}" in
      "ubuntu")
        for i in `ls $guest_root/etc/init/tty[2-9].conf`; do
          mv $i $i.disabled;
        done
        ;;
      "centos"|"rhel")
        sed -i "s/ACTIVE_CONSOLES=.*/ACTIVE_CONSOLES=\\/dev\\/tty1/" $guest_root/etc/sysconfig/init

        # Install Openlogic supplied kernel to support Azure (w-5335)
        # Need to be able to give Openlogic repo priority over base kernels.
        chroot $guest_root yum -y install yum-plugin-priorities
        ;;
      esac
    EOH
  end

  bash "install tools" do
    flags "-x"
    code <<-EOH
      guest_root=#{guest_root}

      # Ignore errors during install, for re-runability.  If you're missing something, it will fail anyway during npm install.
      case "#{new_resource.platform}" in
      "ubuntu")
        chroot $guest_root apt-get -y install python-software-properties
        chroot $guest_root add-apt-repository -y ppa:chris-lea/node.js-legacy
        chroot $guest_root apt-get update
        chroot $guest_root apt-get -y install nodejs npm
        ;;
      "centos"|"rhel")
        chroot $guest_root rpm -Uvh http://rightscale-rightimage.s3-website-us-east-1.amazonaws.com/packages/el6/nodejs-0.8.16-1.x86_64.rpm
        ;;
      esac
      set -e
      chroot $guest_root npm install azure-cli@0.6.8 -g

      # Remove .swp files
      find $guest_root/root/.npm $guest_root/usr/lib/node* $guest_root/usr/lib/node_modules -name *.swp -exec rm -rf {} \\;
    EOH
  end
end

action :package do
  rightimage_image node[:rightimage][:image_type] do
    action :package
  end
end

action :upload do
  bash "install tools on host" do
    flags "-x"
    code <<-EOH
      azure_ver="0.7.3"

      # Ignore errors during install, for re-runability.  If you're missing something, it will fail anyway during npm install.
      case "#{new_resource.platform}" in
      "ubuntu")
        apt-get -y install python-software-properties
        add-apt-repository -y ppa:chris-lea/node.js
        apt-get update
        # nodejs package includes nodejs-dev and npm
        apt-get -y install nodejs
        ;;
      "centos"|"rhel")
        rpm -Uvh http://rightscale-rightimage.s3-website-us-east-1.amazonaws.com/packages/el6/nodejs-0.8.16-1.x86_64.rpm
        ;;
      esac
      npm -g ls | grep azure
      if [ "$?" == "1" ]; then
        set -e
        npm install azure-cli@$azure_ver -g
      fi
    EOH
  end

  template "/root/azure.publishsettings" do
    source "azure.publishsettings.erb"
    backup false
  end

  bash "import settings" do
    flags "-e"
    code <<-EOH
      settings=/root/azure.publishsettings
      azure account import $settings
      rm -f $settings
    EOH
  end
  if node[:rightimage][:azure][:shared_key].to_s.empty?
    bash "upload and register image" do
      flags "-ex"
      cwd target_raw_root
      code <<-EOH
        azure vm image create #{image_name} #{image_name}.vhd \
          --os Linux \
          --location "#{node[:rightimage][:azure][:region]}"
      EOH
    end
  else
    account = node[:rightimage][:azure][:storage_account]
    container = node[:rightimage][:image_upload_bucket]
    bash "upload image" do
      flags "-e"
      cwd target_raw_root
      code <<-EOH
        azure vm disk upload #{image_name}.vhd \
          http://#{account}.blob.core.windows.net/#{container}/#{image_name}.vhd \
          #{node[:rightimage][:azure][:shared_key]}
      EOH
    end
    bash "register image" do
      flags "-ex"
      cwd target_raw_root
      code <<-EOH
        azure vm image create #{image_name} \
          --os Linux \
          --location "#{node[:rightimage][:azure][:region]}" \
          --blob-url https://#{account}.blob.core.windows.net/#{container}/#{image_name}.vhd
      EOH
    end
  end

  # Delete publishsettings
  execute "azure account clear"

  # Needed to create the mci, pulled by right_image_builder
  ruby_block "store id" do
    block do
      id_list = RightImage::IdList.new(Chef::Log)
      id_list.add(image_name)
    end
  end
end

