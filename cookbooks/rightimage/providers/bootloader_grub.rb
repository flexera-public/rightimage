def grub_kernel_options(cloud)
  options_line = "consoleblank=0"
  if new_resource.hypervisor.to_s == "xen"
    options_line << " console=hvc0"

    # Start device naming from xvda instead of xvde (w-4893)
    # https://bugzilla.redhat.com/show_bug.cgi?id=729586
    if new_resource.platform == "centos" && new_resource.platform_version.to_f >= 6.3
      options_line << " xen_blkfront.sda_is_xvda=1"
    end
  end

  if cloud.to_s == "azure"
    # Ensure that all SCSI devices mounted in your kernel include an I/O timeout of 300 seconds or more. (w-5331)
    options_line << " rootdelay=300 console=ttyS0"

    if new_resource.platform == "centos"
      options_line <<  " numa=off"
    end
  end
  options_line
end

def grub_package
  if new_resource.platform == "ubuntu"
    "grub2"
  else
    "grub"
  end
end

def grub_initrd
  ::File.basename(Dir.glob("#{guest_root}/boot/initr*").sort_by { |f| ::File.mtime(f) }.last)
end

def grub_kernel
  ::File.basename(Dir.glob("#{guest_root}/boot/vmlinuz*").sort_by { |f| ::File.mtime(f) }.last)
end

def grub_root
  "(hd0,0)"
end


def install_grub_package
  if node[:rightimage][:platform] == "ubuntu"
    # Avoid grub install from asking questions. This is needed for grub -> grub2
    # update on host.
    grub_install = "cat << ! | debconf-set-selections -v
grub2   grub2/linux_cmdline                select   
grub2   grub2/linux_cmdline_default        select   
grub-pc grub-pc/install_devices_empty      select yes
grub-pc grub-pc/install_devices            select   
! && DEBIAN_FRONTEND=noninteractive apt-get -y install "
  else
    grub_install = "yum -y install "
  end
  execute "#{grub_install} #{grub_package}"
  execute "#{chroot_install} #{grub_package}"
end

def install_grub_config
  cloud = new_resource.cloud

  timeout = 5
  timeout = 0 if ["ec2","eucalyptus","azure"].include?(cloud.to_s)
  # Specify if running in Xen domU or have grub detect automatically
  indomu = (new_resource.hypervisor.to_s == "xen") ? "true" : "detect"
  if grub_package == "grub"
    grub_conf = "/boot/grub/menu.lst"
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
      :grub_root => grub_root,
      :grub_initrd => grub_initrd,
      :grub_kernel =>  grub_kernel,
      :grub_kernel_options => grub_kernel_options(cloud),
      :platform => new_resource.platform,
      :platform_version => new_resource.platform_version
      )
  end

  # EC2 is a special case.  PV-GRUB is not a true chainloader in that in passes
  # control to whatever is on disk.  It actually reads and mounts the disk itself
  # then manually reads the menu.lst and uses its contents, so if have grub2 installed 
  # it sort of gets bypassed by pv-grub.  grub-legacy-ec2 is a shim that maintains 
  # the menu.lst in parallel - technically ec2 doesn't even need a bootloader installed
  if cloud == "ec2" && grub_package == "grub2"
    Chef::Log::info("Installing legacy grub config to /boot/grub/menu.lst for ec2 cloud, kernel options: #{grub_kernel_options(cloud)}")

    execute "#{chroot_install} grub-legacy-ec2"
    template "#{guest_root}/boot/grub/menu.lst" do
      source "menu.lst.erb"
      backup false
      variables(
        :indomu => indomu,
        :timeout => timeout,
        :grub_root => grub_root,
        :grub_initrd => grub_initrd,
        :grub_kernel =>  grub_kernel,
        :grub_kernel_options => grub_kernel_options(cloud),
        :platform => new_resource.platform,
        :platform_version => new_resource.platform_version
        )
    end
    # 'ucf' manages the configuration files on upgrade, merging your local changes
    # with changes created by the package manager.  It keeps track of the config file
    # checksums and won't change the file if its been modified, so delete menu.lst
    # entry from the ucf registry to put it back under automatic control
    execute "sed -i '/menu.lst/d' #{guest_root}/var/lib/ucf/registry"
  end

  if grub_package == "grub"
    # Grubby requires a symlink to /etc/grub.conf.
    execute "grub symlink" do
      command "chroot #{guest_root} ln -s /boot/grub/menu.lst /etc/grub.conf"
      creates "#{guest_root}/etc/grub.conf"
    end

    execute "grub symlink2" do
      command "chroot #{guest_root} ln -s /boot/grub/menu.lst /boot/grub/grub.conf"
      creates "#{guest_root}/boot/grub/grub.conf"
    end

    # Setup /etc/sysconfig/kernel to allow grub to auto-update grub.conf when updating kernel.
    if new_resource.platform =~ /centos|rhel|redhat/
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

    # This value is set to /dev/mapper/sdaX when run from the loopback, manually fix up
    execute "sed -i 's/set root=.*/set root=(hd0,msdos1)/g' #{guest_root}/boot/grub/grub.cfg"
  end
end

action :install do

  cloud = new_resource.cloud

  install_grub_package
  install_grub_config


  root_device = 
    case new_resource.hypervisor
    when "xen" then "/dev/xvda"
    when "kvm" then  "/dev/vda"
    when "esxi", "hyperv" then "/dev/sda"
    else raise "Unknown hypervisor, can't install bootloader"
    end

  Chef::Log::info("Installing #{grub_package} bootloader to loopback file, with root dev #{root_device}")


  if grub_package == "grub"
    bash "setup grub" do
      not_if { new_resource.hypervisor == "xen" }
      flags "-ex"
      code <<-EOH
        guest_root="#{guest_root}"
        
        case "#{new_resource.platform}" in
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
        grub-install --boot-directory=#{guest_root}/boot/ --modules="ext2 part_msdos" #{loopback_device}0
      EOH
    end
  end
end





