class Chef::Resource
  include RightScale::RightImage::Helper
end


action :configure do
  package "grub"
  
  ruby_block "check hypervisor" do
    block do
      raise "ERROR: you must set your hypervisor to VirtualBox!" unless new_resource.hypervisor == "virtualbox"
    end
  end
  
  bash "install guest packages" do 
    flags '-ex'
    code <<-EOH
      case "#{new_resource.platform}" in
      "ubuntu")
        chroot #{guest_root} apt-get -y purge grub-pc
        chroot #{guest_root} apt-get -y install grub linux-headers-virtual
        ;;
      "centos"|"rhel")
        chroot #{guest_root} yum -y install grub iscsi-initiator-utils kernel-devel
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
  
  # ensure there is a hostname file
  execute "chroot #{guest_root} touch /etc/hostname"
  
  # force cloud name to none
  execute "echo -n none > #{guest_root}/etc/rightscale.d/cloud" 


  bash "save system uname" do
    not_if "test -f #{guest_root}/bin/realuname"
    code "cp #{guest_root}/bin/uname #{guest_root}/bin/realuname"
  end

  cookbook_file "#{guest_root}/bin/fakeuname" do
    cookbook "rightimage_cloud_vagrant"
    source "uname"
    mode "0755"
    backup false
    action :create
  end

  %w(base chef puppet vagrant virtualbox cleanup).each do |script|
    s = "#{script}.sh"
    template "#{guest_root}/tmp/#{s}" do
      source s
      mode "0770"
      cookbook "rightimage_cloud_vagrant"
    end
  
    bash "run script #{script}" do
      code <<-EOH
        chroot #{guest_root} bash -ex /tmp/#{s}
      EOH
    end
  end
end

action :package do
  rightimage_image "virtualbox" do
    action :package
  end
end

action :upload do

  raise "Upload not yet implemented."

  # Needed for do_create_mci, the primary key is the image_name
  ruby_block "store id" do
    block do
      id_list = RightImage::IdList.new(Chef::Log)
      id_list.add(image_name)
    end
  end
end

