class Chef::Resource
  include RightScale::RightImage::Helper
end


action :configure do  
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
        chroot #{guest_root} apt-get -y install linux-headers-virtual
        ;;
      "centos"|"rhel")
        chroot #{guest_root} yum -y install iscsi-initiator-utils kernel-devel
        ;;
      esac
    EOH
  end
  
  # ensure there is a hostname file
  execute "chroot #{guest_root} touch /etc/hostname"
  
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
    platform new_resource.platform
    platform_version new_resource.platform_version
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

