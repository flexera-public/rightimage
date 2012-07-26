class Chef::Resource
  include RightScale::RightImage::Helper
end


action :configure do
  package "grub"
  
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
(hd0) #{loopback_file(partitioned?)}
EOF

    ${grub_command} --batch --device-map=device.map <<EOF
root (hd0,0)
setup (hd0)
quit
EOF
EOH
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
        chroot $guest_root add-apt-repository -y ppa:chris-lea/node.js
        chroot $guest_root apt-get update
        chroot $guest_root apt-get -y install nodejs npm
        ;;
      "centos"|"rhel")
        yum --installroot $guest_root -y --nogpgcheck install http://nodejs.tchol.org/repocfg/el/nodejs-stable-release.noarch.rpm
        chroot $guest_root yum -y install nodejs-compat-symlinks npm
        ;;
      esac
      set -e
      chroot $guest_root npm install azure -g
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
      # Ignore errors during install, for re-runability.  If you're missing something, it will fail anyway during npm install.
      case "#{new_resource.platform}" in
      "ubuntu")
        apt-get -y install python-software-properties
        add-apt-repository -y ppa:chris-lea/node.js
        apt-get update
        apt-get -y install nodejs npm
        ;;
      "centos"|"rhel")
        yum -y --nogpgcheck install http://nodejs.tchol.org/repocfg/el/nodejs-stable-release.noarch.rpm
        yum -y install nodejs-compat-symlinks npm
        ;;
      esac
      npm -g ls | grep azure
      if [ "$?" == "1" ]; then
        set -e
        npm install azure -g
      fi
    EOH
  end

  template "/root/azure.publishsettings" do
    source "azure.publishsettings.erb"
    backup false
  end

  bash "upload image" do
    flags "-ex"
    cwd target_raw_root
    code <<-EOH
      settings=/root/azure.publishsettings
      azure account import $settings
      rm -f $settings
      azure vm image create #{image_name} #{image_name}.vhd --os Linux --location "West US"
      # Delete publishsettings
      azure account clear
    EOH
  end
end

