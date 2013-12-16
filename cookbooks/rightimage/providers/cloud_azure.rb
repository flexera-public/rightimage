class Chef::Resource
  include RightScale::RightImage::Helper
end


action :configure do
  ruby_block "check hypervisor" do
    block do
      raise "ERROR: you must set your hypervisor to hyperv!" unless new_resource.hypervisor == "hyperv"
    end
  end
  
  execute "install iscsi tools" do 
    only_if { node[:rightimage][:platform] =~ /redhat|rhel|centos/ }
    command "chroot #{guest_root} yum -y install iscsi-initiator-utils"
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

  cookbook_file "#{guest_root}/tmp/install_azure_tools.sh" do
    source "install_azure_tools.sh"
    mode "0755"
    action :create
    backup false
  end

  execute "chroot #{guest_root} /tmp/install_azure_tools.sh" do
    environment(node[:rightimage][:script_env])
  end

end

action :package do
  rightimage_image node[:rightimage][:image_type] do
    action :package
  end
end

action :upload do
  cookbook_file "/tmp/install_azure_tools.sh" do
    source "install_azure_tools.sh"
    mode "0755"
    action :create
    backup false
  end


  execute "/tmp/install_azure_tools.sh" do
    environment(node[:rightimage][:script_env])
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

