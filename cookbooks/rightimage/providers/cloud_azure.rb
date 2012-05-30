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
      chroot #{guest_root} apt-get -y install grub iscsi-initiator-utils"
      ;;
    "centos"|"rhel")
      chroot #{guest_root} yum -y install grub iscsi-initiator-utils"
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
    not_if { new_resource.hypervisor == "xen" }
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

end

action :package do
  rightimage_image node[:rightimage][:image_type] do
    action :package
  end
end

action :upload do
  
  raise "Upload not supported -- please implement me!!"

  ruby_block "store id" do
    # add to global id store for use by other recipes
    id_list = RightImage::IdList.new(Chef::Log)
    id_list.add(image_id)
  end
end

