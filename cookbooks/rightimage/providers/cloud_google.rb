class Chef::Resource
  include RightScale::RightImage::Helper
end


action :configure do

  # Add google init script for ubuntu
  if new_resource.platform == "ubuntu"
    cookbook_file "#{guest_root}/etc/init.d/google" do
      source "google_initscript.sh"
      owner "root"
      group "root"
      mode "0755"
      action :create
      backup false
    end
  elsif new_resource.platform =~ /centos|rhel/ && new_resource.platform_version.to_f >= 6 }
    # Add google init script for centos (6+ only)
    cookbook_file "#{guest_root}/etc/init/google.conf" do
      source "google.conf"
      owner "root"
      group "root"
      mode "0755"
      action :create
      backup false
    end
    cookbook_file "#{guest_root}/etc/init/google_run_startup_scripts.conf" do
      source "google_run_startup_scripts.conf"
      owner "root"
      group "root"
      mode "0755"
      action :create
      backup false
    end
    cookbook_file "#{temp_root}/google_centos.tgz" do
      source "google_centos.tgz"
      action :create
      backup false
    end
#    directory "#{guest_root}/usr/share" { recursive true }
    bash "untar google startup scripts" do
      code "tar zxvf #{temp_root}/google_centos.tgz -C /usr/share"
    end
  else
    raise "Unsupported platform/version combination #{new_resource.platform} #{new_resource.platform_version}"
  end

  
  
  # HACK: our ubuntu base images currently do not have a motd -- adding it here
  cookbook_file "#{guest_root}/etc/motd.tail" do 
    source "motd"
    backup false
  end

  if new_resource.platform == "ubuntu"
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
  else
    # Not necessary for upstart
  end

  bash "configure for google compute" do
    flags "-ex" 
    code <<-EOH
      guest_root=#{guest_root}

      wget http://commondatastorage.googleapis.com/pub/gsutil.tar.gz
      tar zxvf gsutil.tar.gz -C #{guest_root}/usr/local
      chroot $guest_root easy_install pip
      chroot $guest_root pip install https://dl.google.com/dl/compute/gcompute.tar.gz

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
  bash "zipping raw file" do 
    code "gzip -c #{loopback_file(true)} > #{loopback_file(true)}.gz"
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

