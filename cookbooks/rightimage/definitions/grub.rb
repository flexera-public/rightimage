
define :install_bootloader, :cloud => :default do

  cloud = (params[:cloud] == :default) ? node[:rightimage][:cloud] : params[:cloud]

  root_device = 
    case node[:rightimage][:hypervisor]
    when "xen" then "/dev/xvda"
    when "kvm" then  "/dev/vda"
    when "esxi", "hyperv" then "/dev/sda"
    else raise "Unknown hypervisor, can't install bootloader"
    end

  Chef::Log::info("Installing #{grub_package} bootloader to loopback file, with root dev #{root_device}")


  if grub_package == "grub"
    bash "setup grub" do
      not_if { node[:rightimage][:hypervisor] == "xen" }
      flags "-ex"
      code <<-EOH
        guest_root="#{guest_root}"
        
        case "#{node[:rightimage][:platform]}" in
          "ubuntu")
            chroot $guest_root cp -p /usr/lib/grub/x86_64-pc/* /boot/grub
            grub_command="/usr/sbin/grub"
            ;;
          "centos"|"rhel")
            chroot $guest_root cp -p /usr/share/grub/x86_64-redhat/* /boot/grub
            grub_command="/sbin/grub"
            ;;
        esac

        echo "(hd0) #{root_device}" > $guest_root/boot/grub/device.map
        echo "" >> $guest_root/boot/grub/device.map

        echo "(hd0) #{loopback_file}" > device.map 

        echo "root #{grub_root}" > /tmp/grubsetup
        echo "setup (hd0)" >> /tmp/grubsetup
        echo "quit" >> /tmp/grubsetup
        cat /tmp/grubsetup | ${grub_command} --batch --device-map=device.map
      EOH
    end
  else
    bash "setup grub2" do
      flags "-ex"
      code <<-EOH
        mkdir -p /mnt/out/boot/grub
        loop_device=`losetup -j #{loopback_file} | cut -d: -f1`
        grub-install --boot-directory=#{guest_root}/boot/ --modules="ext2 part_msdos" $loop_device
      EOH
    end
  end
end

define :install_grub_package do
  package grub_package
  execute "#{chroot_install} #{grub_package}"
end
  

define :install_grub_config, :cloud => :default do
  cloud = (params[:cloud] == :default) ? node[:rightimage][:cloud] : params[:cloud]

  timeout = 5
  timeout = 0 if ["ec2","eucalyptus","azure"].include?(cloud.to_s)
  # Specify if running in Xen domU or have grub detect automatically
  indomu = (node[:rightimage][:hypervisor].to_s == "xen") ? "true" : "detect"
  if grub_package == "grub"
    grub_conf = "/boot/menu.lst"
  else
    grub_conf = "/etc/default/grub"
  end

  Chef::Log::info("Installing grub config to #{grub_conf} with cloud #{cloud}, kernel options: #{grub_kernel_options(cloud)}")

  # insert grub conf, and link menu.lst to grub_conf
  directory "#{guest_root}/boot/grub" do
    owner "root"
    group "root"
    mode "0750"
    action :create
    recursive true
  end 

  template "#{guest_root}#{grub_conf}" do
    source ::File::basename(grub_conf)+".erb"
    backup false
    variables(
      :indomu => indomu,
      :timeout => timeout,
      :kernel_options => grub_kernel_options(cloud),
      :platform => node[:rightimage][:platform],
      :platform_version => node[:rightimage][:platform_version]
      )
  end

  # EC2 is a special case.  PV-GRUB is not a true chainloader in that in passes
  # control to whatever is on disk.  It actually reads and mounts the disk itself
  # then manually reads the menu.lst and uses its contents, so if have grub2 installed 
  # it sort of gets bypassed by pv-grub.  grub-legacy-ec2 is a shim that maintains 
  # the menu.lst in parallel - technically ec2 doesn't even need a bootloader installed
  if cloud == "ec2" && grub_package == "grub2"
    execute "#{chroot_install} grub-legacy-ec2"
    template "/boot/grub/menu.lst" do
      source "menu.lst.erb"
      backup false
      variables(
        :indomu => indomu,
        :timeout => timeout,
        :grub_kernel_options => grub_kernel_options(cloud),
        :platform => node[:rightimage][:platform],
        :platform_version => node[:rightimage][:platform_version]
        )
    end
    # 'ucf' manages the configuration files on upgrade, merging your local changes
    # with changes created by the package manager.  It keeps track of the config file
    # checksums and won't change the file if its been modified, so delete menu.lst
    # entry from the ucf registry to put it back under automatic control
    execute "sed -i '/menu.lst/d' /var/lib/ucf/registry"
  end

  if grub_package == "grub"
    # Grubby requires a symlink to /etc/grub.conf.
    execute "grub symlink" do
      command "chroot #{guest_root} ln -s /boot/grub/menu.lst /etc/grub.conf"
      creates "#{guest_root}/etc/grub.conf"
    end

    # Setup /etc/sysconfig/kernel to allow grub to auto-update grub.conf when updating kernel.
    if node[:rightimage][:platform] =~ /centos|rhel|redhat/
      template "#{guest_root}/etc/sysconfig/kernel" do
        source "sysconfig-kernel.erb"
        backup false
        variables({
          :kernel => (el6?) ? "kernel" : "kernel-xen"
        })
      end
    end
  else
    execute "chroot #{guest_root} /usr/sbin/update-grub"
    execute "sed -i 's/set root=.*/set root=(hd0,msdos1)/g' #{guest_root}/boot/grub/grub.cfg"
  end
end




