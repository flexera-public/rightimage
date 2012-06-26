class Chef::Resource
  include RightScale::RightImage::Helper
end


action :configure do
  ruby_block "check hypervisor" do
    block do
      raise "ERROR: you must set your hypervisor to kvm!" unless new_resource.hypervisor == "kvm"
    end
  end

  directory temp_root { recursive true }

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
  elsif new_resource.platform =~ /centos|rhel/ && new_resource.platform_version.to_f >= 6
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

      # Set HW clock to UTC
      echo "UTC" >> $guest_root/etc/adjtime

      case "#{new_resource.platform}" in
      "centos"|"rhel")
        chroot $guest_root yum -y install python-setuptools python-devel python-libs
        ;;
      "ubuntu")
        chroot $guest_root apt-get -y install python-dev python-setuptools
        chroot $guest_root apt-get -y install acpi dhcp3-client
        ;;
      esac
      
      #Install GCompute
      chroot $guest_root easy_install pip
      chroot $guest_root pip install boto
      chroot $guest_root pip install https://dl.google.com/dl/compute/gcompute.tar.gz

      # Install GSUtil
      wget http://commondatastorage.googleapis.com/pub/gsutil.tar.gz
      tar zxvf gsutil.tar.gz -C $guest_root/usr/local
      echo 'export PATH=$PATH:/usr/local/gsutil' > $guest_root/etc/profile.d/gsutil.sh

      mkdir -p $guest_root/etc/rightscale.d
      echo "gc" > $guest_root/etc/rightscale.d/cloud
    EOH
  end

end

action :package do
  file "#{target_raw_root}/disk.raw" do
    action :delete
    backup false
  end
  # Chef file resource doesn't do this correctly for some reason
  bash "hard link to disk.raw" do
    cwd target_raw_root
    code "ln #{loopback_file(true)} disk.raw"
  end
  bash "zipping raw file" do
    cwd target_raw_root
    code "tar zcvf #{new_resource.image_name}.tar.gz disk.raw"
  end
end

action :upload do
  packages =
    case node[:platform]
    when "centos", "redhat" then
      %w(python-setuptools python-devel python-libs)
    when "ubuntu" then
      %w(python-dev python-setuptools)
    end

  packages.each { package p }

  execute "easy_install"
  execute "easy_install pip"
  execute "pip install boto"
  execute "pip install https://dl.google.com/dl/compute/gcompute.tar.gz"

  bash "install gsutil" do
    creates "/usr/local/gsutil/gsutil"
    code <<-EOF
  wget http://commondatastorage.googleapis.com/pub/gsutil.tar.gz
  tar zxvf gsutil.tar.gz -C /usr/local
  echo 'export PATH=$PATH:/usr/local/gsutil' > /etc/profile.d/gsutil.sh
  source /etc/profile.d/gsutil.sh
EOF
  end
 
  # TBD, replace this block. We use the gsutil/gcompute tools to do this, but we 
  # need to generate the refresh_token on another computer (see rightimage_tools/google_token)
  # We can skip this and use the api directly with the "service accounts" oauth method
  # but these tools don't support that control flow and need to look into doing
  # it with google-api-python or google-api-ruby separately. don't think those tools
  # work yet either, revisit later 
  template "/root/.gcompute_auth" do
    source "gcompute_auth"
    variables(
      :client_id => node[:rightimage][:google][:client_id],
      :client_secret  => node[:rightimage][:google][:client_secret],
      :refresh_token => node[:rightimage][:google][:refresh_token]
    )
    backup false
  end
  
  template "/root/.boto" do 
    source "google_boto"
    variables(
      :refresh_token => node[:rightimage][:google][:refresh_token],
      :project_id => node[:rightimage][:google][:gs_x_project_id]
    )
    backup false
  end

  bash "upload image" do
    image = "#{target_raw_root}/#{new_resource.image_name}.tar.gz"
    code <<-EOF
      if [ ! -e  #{image} ]; then
        echo "ERROR: file #{image} does not exist, aborting upload!"
        exit 1
      fi
      gsutil cp #{image} gs://rightimage-dev"
    EOF
  end

  bash "register image" do
    code <<-EOF
      gcompute addimage #{new_resource.image_name} \
      "http://commondatastorage.googleapis.com/#{node[:rightimage][:upload_bucket]}/#{new_resource.image_name}.tar.gz \
      --project_id=#{node[:rightimage][:google][:project_id]}
    EOF
  end

#  ruby_block "store id" do
    # add to global id store for use by other recipes
#    id_list = RightImage::IdList.new(Chef::Log)
#    id_list.add(image_id)
#  end
end

