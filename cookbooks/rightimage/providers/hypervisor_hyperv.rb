class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

action :install_kernel do
  LIS_DIR_GUEST = "/tmp/lis_install"
  LIS_DIR_HOST = "#{guest_root}#{LIS_DIR_GUEST}"
  LIS_KMOD = "kmod-microsoft-hyper-v-rhel63.3.4-1.20120727.x86_64.rpm"
  LIS_PKG = "microsoft-hyper-v-rhel63.3.4-1.20120727.x86_64.rpm"

  directory LIS_DIR_HOST do
    recursive true
  end

  remote_file "#{LIS_DIR_HOST}/#{LIS_KMOD}" do
    only_if { node[:rightimage][:platform] == "centos" }
    source "http://devs-us-west.s3.amazonaws.com/caryp/azure/#{LIS_KMOD}"
  end

  remote_file "#{LIS_DIR_HOST}/#{LIS_PKG}" do
    only_if { node[:rightimage][:platform] == "centos" }
    source "http://devs-us-west.s3.amazonaws.com/caryp/azure/#{LIS_PKG}"
  end
 
  bash "install Linux Integration Services package" do
    only_if { node[:rightimage][:platform] == "centos" }
    flags "-ex"
    cwd LIS_DIR_HOST
    code <<-EOH
      guest_root=#{guest_root}
      lis_dir_host=#{LIS_DIR_HOST}
      lis_dir_guest=#{LIS_DIR_GUEST}

      # Uninstall all kernels.  Need Openlogic supplied kernel to work (w-5335)
      for pkg in `rpm -qa --root $guest_root kernel*`; do
        rpm --root $guest_root --erase --nodeps $pkg
      done

      # Install Openlogic supplied kernel to support Azure (w-5335)
      kernel="2.6.32-279.14.1.el6.openlogic.x86_64"
      url="http://devs-us-west.s3.amazonaws.com/caryp/azure"
      rpm --root $guest_root -Uvh ${url}/kernel-${kernel}.rpm ${url}/kernel-firmware-${kernel}.rpm ${url}/kernel-headers-${kernel}.rpm

      # Install kernel module
      rpm --root $guest_root --force --nodeps -ivh $guest_root/tmp/lis_install/kmod*.rpm
      rpm --root $guest_root --force --nodeps -ivh $guest_root/tmp/lis_install/microsoft-hyper-v-rhel*.rpm


      # Agent install attempts to use kernel on host instead of the guest
      rm -f $guest_root/initr* $guest_root/boot/initr*$(uname -r)*

      # Kill services started automatically during package installs
      set +e
      killall hv_kvp_daemon
      set -e
    EOH
  end

  # To work on the Azure platform, you need packages from at least 12/22/2012 (w-5336)
  # NOTE: ONLY NEEDED FOR v13.2.1
  template "#{guest_root}/etc/apt/sources.list.d/rightscale-azure.sources.list" do
    only_if { node[:rightimage][:platform] == "ubuntu" }
    source "sources-azure.list.erb"
    backup false
  end

  template "#{guest_root}/etc/apt/preferences.d/azure" do
    only_if { node[:rightimage][:platform] == "ubuntu" }
    source "apt-pref-azure.erb"
    backup false
  end

  execute "chroot #{guest_root} apt-get update" do
    only_if { node[:rightimage][:platform] == "ubuntu" }
  end

  execute "chroot #{guest_root} apt-get -y install linux-backports-modules-hv-precise-virtual" do
    only_if { node[:rightimage][:platform] == "ubuntu" }
  end

end

action :install_tools do
  # Disable agent for now since in a chroot.  Installation fails if it is left enabled.
  template "#{guest_root}/etc/default/walinuxagent" do
    only_if { node[:rightimage][:platform] == "ubuntu" }
    source "walinuxagent.erb"
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
        chroot $guest_root yum -y install https://devs-us-west.s3.amazonaws.com/caryp/azure/WALinuxAgent-1.2-1.noarch.rpm
        ;;
      esac
    EOH
  end

  # Re-enable agent.
  template "#{guest_root}/etc/default/walinuxagent" do
    only_if { node[:rightimage][:platform] == "ubuntu" }
    source "walinuxagent.erb"
    variables({
      :enabled => "1"
    })
  end
end
