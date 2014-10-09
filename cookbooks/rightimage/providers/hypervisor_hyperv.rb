class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

action :install_kernel do
  if node[:rightimage][:platform_version].to_f < 6.4
    raise "Hyper-v support was added in CentOS 6.4, please use a more recent version"
  end

  # To work on the Azure platform, you need this package from at least 12/22/2012 (w-5336)
  execute "chroot #{guest_root} apt-get -y install linux-backports-modules-hv-precise-virtual" do
    only_if { node[:rightimage][:platform] == "ubuntu" &&  node[:rightimage][:platform_version] == "12.04" }
  end

  cookbook_file "#{guest_root}/etc/dracut.conf.d/azure.conf" do
    only_if { el7? }
    source "dracut-azure.conf"
    mode "0600"
    action :create
    backup false
  end

  bash "install hyperv ramdisk" do
    only_if { el7? }
    flags "-ex"
    code <<-EOH
      # Install to guest.
      guest_root=#{guest_root}

      kernel_version=$(ls -t $guest_root/lib/modules|awk '{ printf "%s ", $0 }'|cut -d ' ' -f1-1)

      # Now rebuild ramdisk with hyper-v drivers
      chroot $guest_root dracut --force --kver $kernel_version
    EOH
  end
end

action :install_tools do
  # Disable agent for now since in a chroot.  Installation fails if it is left enabled.
  template "#{guest_root}/etc/default/walinuxagent" do
    only_if { node[:rightimage][:platform] == "ubuntu" }
    source "walinuxagent.erb"
    backup false
    variables({
      :enabled => "0"
    })
  end

  bash "install WAZ agent" do
    not_if_check = case node[:rightimage][:platform]
                   when "centos", "rhel" then "rpm --root #{guest_root} -qa WALinuxAgent|grep WA"
                   when "ubuntu" then "dpkg --root #{guest_root} --get-selections walinuxagent|grep install"
                   end

    flags "-ex"
    not_if not_if_check
    code <<-EOH
      guest_root=#{guest_root}

      # Install agent version 1.2 to support platform changes. (w-5337)
      case "#{new_resource.platform}" in
      "ubuntu")
        # Install linux-tools and hv-kvp-daemon-init to support platform changes. (w-5338)
        chroot $guest_root apt-get -y install hv-kvp-daemon-init

        # Tell package manager to use the old config file.
        chroot $guest_root apt-get -y -o Dpkg::Options::="--force-confold" install walinuxagent
        ;;
      "centos"|"rhel")
        chroot $guest_root yum -y install #{node[:rightimage][:s3_base_url]}/files/WALinuxAgent-2.0.8-1.noarch.rpm
        ;;
      esac
    EOH
  end

  # Re-enable agent.
  template "#{guest_root}/etc/default/walinuxagent" do
    only_if { node[:rightimage][:platform] == "ubuntu" }
    backup false
    source "walinuxagent.erb"
    variables({
      :enabled => "1"
    })
  end
end
