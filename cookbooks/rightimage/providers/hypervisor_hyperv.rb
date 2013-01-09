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
 
end

action :install_tools do
  package_name =
    case node[:rightimage][:platform]
    when "centos", "rhel" then "WALinuxAgent-1.0-1.noarch.rpm"
    when "ubuntu" then "WALinuxAgent-1.0-1_all.deb"
    end

  remote_file "#{LIS_DIR_HOST}/#{package_name}" do
    source "http://devs-us-west.s3.amazonaws.com/caryp/azure/#{package_name}"
  end
  
  bash "install WAZ agent" do
    not_if_check = case node[:rightimage][:platform]
                   when "centos", "rhel" then "rpm --root #{guest_root} -qa WALinuxAgent|grep WA"
                   when "ubuntu" then "dpkg --root #{guest_root} --get-selections walinuxagent|grep install"
                   end

    flags "-ex"
    cwd LIS_DIR_HOST
    not_if not_if_check
    code <<-EOH
      guest_root=#{guest_root}

      case "#{new_resource.platform}" in
      "ubuntu")
        dpkg --root $guest_root --install #{LIS_DIR_HOST}/#{package_name}
        ;;
      "centos"|"rhel")
        yum -c /tmp/yum.conf --installroot=$guest_root -y install #{LIS_DIR_HOST}/#{package_name}
        ;;
      esac
    EOH
  end
end
