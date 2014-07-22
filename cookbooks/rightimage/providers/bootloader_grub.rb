def grub_kernel_options(cloud)
  options_line = "consoleblank=0"
  if hvm?
    options_line << " console=ttyS0"
  elsif new_resource.hypervisor.to_s == "xen"
    options_line << " console=hvc0"
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
  if new_resource.platform == "ubuntu" || 
    (new_resource.platform =~ /centos|rhel/ && new_resource.platform_version.to_i >= 7)
    "grub2"
  else
    "grub"
  end
end

def grub_root
  if partitioned?
    "(hd0,0)"
  else
    "(hd0)"
  end
end

def partitioned?
  # Base images have cloud == none, so should always be true
  if new_resource.cloud == "ec2" && !hvm?
    false
  else
    true
  end
end



def grub_initrd
  ::File.basename(Dir.glob("#{new_resource.root}/boot/initr*").sort_by { |f| ::File.mtime(f) }.last)
end

def grub_kernel
  ::File.basename(Dir.glob("#{new_resource.root}/boot/vmlinuz*").sort_by { |f| ::File.mtime(f) }.last)
end

def install_grub_package
  if node[:rightimage][:platform] == "ubuntu"
    # Work around issue with grub installed on host and grub2 on image.
    # grub-pc postinst resets grub-pc/mixed_legacy_and_grub2 and marks as
    # critical input even if you set it beforehand (w-6232)
    execute "touch /boot/grub/grub2-installed" do
      creates "/boot/grub/grub2-installed"
    end

    # Avoid grub install from asking questions. This is needed for grub -> grub2
    # update on host.
    cookbook_file "/tmp/debconf-grub.txt" do
      source "debconf-grub.txt"
      backup false
    end

    execute 'debconf-set-selections -v /tmp/debconf-grub.txt'

    execute("apt-get -y install #{grub_package}") do
      environment({"DEBIAN_FRONTEND"=>"noninteractive"})
    end
  else
    execute("yum -y install #{grub_package}")
  end
    
  execute "#{chroot_install} #{grub_package}"
end

def install_grub_config
  cloud = new_resource.cloud

  timeout = 5
  timeout = 0 if ["azure","ec2","eucalyptus","google"].include?(cloud.to_s)
  # Specify if running in Xen domU or have grub detect automatically
  indomu = (new_resource.hypervisor.to_s == "xen" && !hvm?) ? "true" : "detect"
  if grub_package == "grub"
    grub_conf = "/boot/grub/menu.lst"
  else
    grub_conf = "/etc/default/grub"
  end

  Chef::Log::info("Installing grub config to #{grub_conf} with cloud #{cloud}, kernel options: #{grub_kernel_options(cloud)}")

  # insert grub conf, and link menu.lst to grub_conf
  directory "#{new_resource.root}/boot/grub" do
    owner "root"
    group "root"
    mode "0750"
    action :create
    recursive true
  end 

  template "#{new_resource.root}#{grub_conf}" do
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
  # grub-legacy-ec2 is an ubuntu package -- no equivalent for centos 7 (grub2 only) existsq
  if cloud == "ec2" && grub_package == "grub2" && !hvm?
    Chef::Log::info("Installing legacy grub config to /boot/grub/menu.lst for ec2 cloud, kernel options: #{grub_kernel_options(cloud)}")

    execute "#{chroot_install(new_resource.root)} grub-legacy-ec2" if new_resource.platform == "ubuntu"
    template "#{new_resource.root}/boot/grub/menu.lst" do
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
    execute "sed -i '/menu.lst/d' #{new_resource.root}/var/lib/ucf/registry"
  end

  if grub_package == "grub"
    # Grubby requires a symlink to /etc/grub.conf.
    execute "grub symlink" do
      command "chroot #{new_resource.root} ln -s /boot/grub/menu.lst /etc/grub.conf"
      creates "#{new_resource.root}/etc/grub.conf"
    end

    execute "grub symlink2" do
      command "chroot #{new_resource.root} ln -s /boot/grub/menu.lst /boot/grub/grub.conf"
      creates "#{new_resource.root}/boot/grub/grub.conf"
    end

    # Setup /etc/sysconfig/kernel to allow grub to auto-update grub.conf when updating kernel.
    if new_resource.platform =~ /centos|rhel|redhat/
      template "#{new_resource.root}/etc/sysconfig/kernel" do
        source "sysconfig-kernel.erb"
        backup false
        variables({
          :kernel => (new_resource.platform_version.to_f >= 6.0) ? "kernel" : "kernel-xen"
        })
      end
    end
  else
    if new_resource.platform == "ubuntu"
      execute "chroot #{new_resource.root} /usr/sbin/update-grub"

      # This value is set to /dev/mapper/sdaX when run from the loopback, manually fix up
      execute "sed -i 's/set root=.*/set root=(hd0,msdos1)/g' #{new_resource.root}/boot/grub/grub.cfg"
    else
      execute "chroot #{new_resource.root} /usr/sbin/grub2-mkconfig -o /boot/grub2/grub.cfg"
    end
  end
end

def install_grub_bootloader
  instance_device = 
    case new_resource.hypervisor
    when "xen" then "/dev/xvda"
    when "kvm" then  "/dev/vda"
    when "esxi", "hyperv", "virtualbox" then "/dev/sda"
    else raise "Unknown hypervisor, can't install bootloader"
    end

  Chef::Log::info("Installing #{grub_package} bootloader to #{new_resource.device} mounted at #{new_resource.root} with root volume set to #{instance_device}")


  if grub_package == "grub"
    # So the device mapping stuff is slightly convoluted -- grub and grub2 expect
    # different things passed in as the device for the loopback filesystem (loop0 for grub2
    # mapped equiv at /dev/mapper/sda0 for grub) or they'll crap out with errors
    # about being unable to find the partition.  
    # For a real device (HVM case, mounted volume) it just works as expected 
    if new_resource.device.to_s.empty?
      local_device = "/dev/mapper/sda0"
    else
      local_device = new_resource.device
    end
    
    package "grub"

    bash "setup grub" do
      flags "-ex"
      code <<-EOH
        guest_root="#{new_resource.root}"
        
        case "#{new_resource.platform}" in
          "ubuntu")
            cp -p $guest_root/usr/lib/grub/x86_64-pc/* $guest_root/boot/grub
            grub_command="/usr/sbin/grub"
            ;;
          "centos"|"rhel")
            cp -p $guest_root/usr/share/grub/x86_64-redhat/* $guest_root/boot/grub
            grub_command="/sbin/grub"
            ;;
        esac

        echo "(hd0) #{instance_device}" > $guest_root/boot/grub/device.map
        echo "" >> $guest_root/boot/grub/device.map

        echo "(hd0) #{local_device}" > device.map 

        echo "root #{grub_root}" > /tmp/grubsetup
        echo "setup (hd0)" >> /tmp/grubsetup
        echo "quit" >> /tmp/grubsetup
        cat /tmp/grubsetup | ${grub_command} --batch --device-map=device.map
      EOH
    end
  else
    if new_resource.device.to_s.empty?
      local_device = "#{::LoopbackFs.loopback_device}0"
    else
      local_device = new_resource.device
    end
    grub_install = new_resource.platform == "ubuntu" ? "grub-install" : "grub2-install"
    execute "#{grub_install} --boot-directory='#{new_resource.root}/boot/' --modules='ext2 part_msdos' '#{local_device}'"
  end
end

action :install do
  install_grub_package
  install_grub_config
  install_grub_bootloader
end

action :install_bootloader  do
  install_grub_config
  install_grub_bootloader
end





