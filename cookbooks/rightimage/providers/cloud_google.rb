class Chef::Resource
  include RightScale::RightImage::Helper
end


action :configure do

  # Add google init script
  cookbook_file "#{guest_root}/etc/init.d/google" do
    source "google_initscript.sh"
    cookbook "google"
    owner "root"
    group "root"
    mode "0755"
    action :create
  end
  
  # HACK: our ubuntu base images currently do not have a motd -- adding it here
  remote_file "#{node[:rightimage][:mount_dir]}/etc/motd.tail" do 
    source "motd" 
    cookbook "rightimage"
    backup false
  end

  bash "Link init script to runlevels" do
    flags "-ex" 
    code <<-EOH
      guest_root=#{guest_root}
    
      # Link init script to runlevels
      chroot $guest_root ln -sf ../init.d/google /etc/rc0.d/K01google
      chroot $guest_root ln -sf ../init.d/google /etc/rc1.d/K01google
      chroot $guest_root ln -sf ../init.d/google /etc/rc6.d/K01google
      chroot $guest_root ln -sf ../init.d/google /etc/rc2.d/s99google
      chroot $guest_root ln -sf ../init.d/google /etc/rc3.d/s99google
      chroot $guest_root ln -sf ../init.d/google /etc/rc4.d/s99google
      chroot $guest_root ln -sf ../init.d/google /etc/rc5.d/s99google
    EOH
  end

  bash "configure for google compute" do
    flags "-ex" 
    code <<-EOH
      guest_root=#{guest_root}

      case "#{node[:rightimage][:platform]}" in
      "centos")
        # TODO
        ;;

      "ubuntu")
        # TOOO
        chroot $guest_root apt-get -y install acpi dhcp3-client 
        ;;
      esac

      mkdir -p $guest_root/etc/rightscale.d
      echo "gc" > $guest_root/etc/rightscale.d/cloud

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

