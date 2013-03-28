class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

action :install_kernel do
  # To work on the Azure platform, you need this package from at least 12/22/2012 (w-5336)
  execute "chroot #{guest_root} apt-get -y install linux-backports-modules-hv-precise-virtual" do
    only_if { node[:rightimage][:platform] == "ubuntu" }
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
        chroot $guest_root apt-get -y install linux-tools hv-kvp-daemon-init

        # Tell package manager to use the old config file.
        chroot $guest_root apt-get -y -o Dpkg::Options::="--force-confold" install walinuxagent
        ;;
      "centos"|"rhel")
        chroot $guest_root yum -y install https://devs-us-west.s3.amazonaws.com/caryp/azure/WALinuxAgent-1.3.2-1.noarch.rpm
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
