# bootstrap_ubuntu.rb
# 
# Use vmbuilder to generate a base virtual image.  We will use the image generated here for other recipes to add
# Cloud and Hypervisor specific details.
#
# When this is finished running, you should have a basic image ready in /mnt
#
class Erubis::Context
  include RightScale::RightImage::Helper
end
class Chef::Resource
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end

require 'chef/log'
require 'chef/mixin/shell_out'
class Chef::Provider
  include Chef::Mixin::ShellOut
end


# Ubuntu packages may call triggers which autostart services after install.  
# These services will open log files preventing the loopback filesystem from 
# unmounting.  Do the same thing debootstrap does and stub out initctl and
# such with dummy scripts temporarily
def loopback_package_install(packages = nil)
  init_scripts = ['/sbin/start-stop-daemon', '/sbin/initctl']
  begin
    init_scripts.each do |script|
      shell_out!("chroot #{guest_root} dpkg-divert --add --rename --local #{script}")
      ::File.open("#{guest_root}/#{script}","w") do |f|
        f.puts('#!/bin/sh')
        f.puts('echo')
        f.puts("echo 'Warning: Fake #{script} called, doing nothing'")
      end
      shell_out!("chmod 755 #{guest_root}/#{script}")
    end
    if packages
      package_list = Array(packages).join(" ")
      Chef::Log.info("Installing #{package_list} into #{guest_root}")
      shell_out!("chroot #{guest_root} apt-get install -y #{package_list}")
    end
    yield if block_given?
  ensure
    init_scripts.each do |script|
      shell_out!("rm #{guest_root}/#{script}")
      shell_out!("chroot #{guest_root} dpkg-divert --remove --rename #{script}")
    end
  end
end

action :install do
  mirror_date = "#{mirror_freeze_date[0..3]}/#{mirror_freeze_date[4..5]}/#{mirror_freeze_date[6..7]}"
  mirror_url = "http://#{node[:rightimage][:mirror]}/ubuntu_daily/#{mirror_date}"
  platform_codename = platform_codename(new_resource.platform_version)

  # Needed if constituent packages updated since image creation
  execute 'apt-get update -y > /dev/null'

  package "python-boto"
  package "python-vm-builder"

  # Overwrite the provided sources.list template or the kernel will be
  # installed from the upstream Ubuntu mirror. (w-6136)
  directory "/root/.vmbuilder/ubuntu" do
    owner "root"
    group "root"
    mode "0700"
    recursive true
    action :create
  end

  template "/root/.vmbuilder/ubuntu/sources.list.tmpl" do
    source "sources.list.erb"
    variables(
      :mirror_url => node[:rightimage][:mirror],
      :use_staging_mirror => node[:rightimage][:rightscale_staging_mirror],
      :mirror_date => mirror_date,
      :bootstrap => true,
      :platform_codename => platform_codename
    )
    backup false
  end

  bash "cleanup" do
    flags "-ex"
    code <<-EOH
      umount -lf /dev/loop1 || true
      losetup -d /dev/loop1 || true
    EOH
  end

  #create bootstrap command
  bootstrap_cmd = "/usr/bin/vmbuilder xen ubuntu -o \
      --suite=#{platform_codename} \
      -d #{node[:rightimage][:build_dir]} \
      --rootsize=2048 \
      --install-mirror=#{mirror_url} \
      --install-security-mirror=#{mirror_url} \
      --components=main,restricted,universe,multiverse \
      --lang=#{node[:rightimage][:lang]} --verbose "
  if node[:rightimage][:arch] == "i386"
    bootstrap_cmd << " --arch i386"
    bootstrap_cmd << " --addpkg libc6-xen"
  else
    bootstrap_cmd << " --arch amd64"
  end

  Chef::Log.info "vmbuilder bootstrap command is: " + bootstrap_cmd

  log "Configuring Image..."

  # vmbuilder is defaulting to ext4 and I couldn't find any options to force the filesystem type so I just hacked this.
  # we restore it back to normal later.  
  bash "Comment out ext4 in /etc/mke2fs.conf" do
    flags "-ex"
    code <<-EOH
      sed -i '/ext4/,/}/ s/^/#/' /etc/mke2fs.conf 
    EOH
  end

  # TODO: Split this step up.
  bash "configure_image"  do
    user "root"
    cwd "/tmp"
    flags "-ex"
    code <<-EOH
      image_name=#{image_name}
    
      modprobe dm-mod

      if [ "#{platform_codename}" == "hardy" ]; then
        locale-gen en_US.UTF-8
        export LANG=en_US.UTF-8
        export LC_ALL=en_US.UTF-8
      else
        source /etc/default/locale
        export LANG
      fi

      cat <<-EOS > /tmp/configure_script
#!/bin/bash -x

set -e 
set -x

chroot \\$1 localedef -i en_US -c -f UTF-8 en_US.UTF-8
chroot \\$1 ln -sf /usr/share/zoneinfo/UTC /etc/localtime
chroot \\$1 userdel -r ubuntu
chroot \\$1 rm -rf /home/ubuntu
chroot \\$1 rm -f /etc/hostname
chroot \\$1 touch /fastboot
chroot \\$1 apt-get purge -y apparmor apparmor-utils 
chroot \\$1 shadowconfig on
chroot \\$1  sed -i s/root::/root:*:/ /etc/shadow
chroot \\$1 ln -s /usr/bin/env /bin/env
chroot \\$1 rm -f /etc/rc?.d/*hwclock*
chroot \\$1 rm -f /etc/event.d/tty[2-6]
if [ -e \\$1/usr/bin/ruby1.9.1 ] && [ ! -e \\$1/usr/bin/ruby ]; then 
  chroot \\$1 ln -s /usr/bin/ruby1.9.1 /usr/bin/ruby
fi
if [ -e \\$1/usr/bin/ruby1.8 ] && [ ! -e \\$1/usr/bin/ruby ]; then 
  chroot \\$1 ln -s /usr/bin/ruby1.8 /usr/bin/ruby
fi
EOS
      chmod +x /tmp/configure_script
      #{bootstrap_cmd} --exec=/tmp/configure_script


      if [ "#{platform_codename}" == "hardy" ] ; then
        image_temp=$image_name
      else
        image_temp=`cat /mnt/vmbuilder/xen.conf  | grep xvda1 | grep -v root  | cut -c 25- | cut -c -9`
      fi


      loop_dev="/dev/loop1"

      base_raw_path="/mnt/vmbuilder/root.img"

      sync
      umount -lf $loop_dev || true
      # Cleanup loopback stuff
      set +e
      losetup -a | grep $loop_dev
      [ "$?" == "0" ] && losetup -d $loop_dev
      set -e

      qemu-img convert -O raw /mnt/vmbuilder/$image_temp $base_raw_path



      losetup $loop_dev $base_raw_path

      guest_root=#{guest_root}

      random_dir=/tmp/rightimage-$RANDOM
      mkdir $random_dir
      mount -o loop $loop_dev  $random_dir
      rsync -a --delete $random_dir/ $guest_root/ --exclude '/proc' --exclude '/dev' --exclude '/sys'
      umount $random_dir
      sync
      losetup -d $loop_dev
      rm -rf $random_dir

      mkdir -p $guest_root/var/man
      chroot $guest_root chown -R man:root /var/man


  EOH
  end


  # disable loading pata_acpi module - currently breaks acpid from discovering volumes attached to CDC KVM hypervisor, from bootstrap_centos, should be applicable to ubuntu though
  bash "blacklist pata_acpi" do
    code <<-EOF
      echo "blacklist pata_acpi"          > #{guest_root}/etc/modprobe.d/disable-pata_acpi.conf
      echo "install pata_acpi /bin/true" >> #{guest_root}/etc/modprobe.d/disable-pata_acpi.conf
    EOF
  end


  cookbook_file "#{guest_root}/tmp/GPG-KEY-RightScale" do
    source "GPG-KEY-RightScale"
    backup false
  end

  log "Adding rightscale gpg key to keyring"
  bash "install rightscale gpg key" do
    flags "-ex"
    code "chroot #{guest_root} apt-key add /tmp/GPG-KEY-RightScale"
  end

  #  - configure mirrors
  rightimage_os new_resource.platform do
    action :repo_unfreeze
  end


  bash "Restore original ext4 in /etc/mke2fs.conf" do
    flags "-ex"
    code <<-EOH
      sed -i '/ext4/,/}/ s/^#//' /etc/mke2fs.conf 
    EOH
  end

  
  # Set DHCP timeout
  bash "dhcp timeout" do
    flags "-ex"
    code <<-EOH
      if [ "#{new_resource.platform_version.to_f < 12.04}" == "true" ]; then
        dhcp_ver="3"
      else
        dhcp_ver=""
      fi
      sed -i "s/#timeout.*/timeout 300;/" #{guest_root}/etc/dhcp$dhcp_ver/dhclient.conf
      rm -f #{guest_root}/var/lib/dhcp$dhcp_ver/*
    EOH
  end

  # dhclient on precise by default doesn't set the hostname on boot
  # while dhcpd on ubuntu 10.04 does. Ubuntu 13.04 has a script in contrib
  # called sethostname.sh that does the same thing that you can place your enter
  # hooks.  You may have to manually install it though, so revisit the issue at 
  # that point (w-5618)
  if new_resource.platform_version.to_f.between?(12.04,12.10); then
    cookbook_file "#{guest_root}/etc/dhcp/dhclient-enter-hooks.d/hostname" do
      source "dhclient-hostname.sh"
      backup false
      mode "0644"
    end
  end

  # Don't let SysV init start until more than lo0 is ready
  bash "sysv upstart fix" do
    only_if { new_resource.platform_version.to_f == 10.04 }
    flags "-ex"
    code <<-EOH
      sed -i "s/IFACE=/IFACE\!=/" #{guest_root}/etc/init/rc-sysinit.conf
    EOH
  end

  log "Setting APT::Install-Recommends to false"
  bash "apt config" do
    flags "-ex"
    code <<-EOH
      echo "APT::Install-Recommends \"0\";" > #{guest_root}/etc/apt/apt.conf
    EOH
  end

  log "Disable HTTP pipeline on APT"
  bash "apt config pipeline" do
    flags "-ex"
    code <<-EOH
      echo "Acquire::http::Pipeline-Depth \"0\";" > #{guest_root}/etc/apt/apt.conf.d/99-no-pipelining
    EOH
  end


  # w-5970 - liblockfile has a bug resulting in ntp restart to fail on instances
  # where the hostname is too long (>36 chars) which might occur somewhat commonly
  # on openstack and rackspace instances. This is a patch from their staging repos
  # TBD can be removed when patched version merged to master
  # https://bugs.launchpad.net/ubuntu/+source/liblockfile/+bug/941968/comments/30
  directory "#{guest_root}/tmp/packages"
  bash "custom liblockfile" do
    cwd "#{guest_root}/tmp/packages"
    flags "-ex"
    only_if { new_resource.platform_version.to_f == 12.04 && node[:rightimage][:arch] == "x86_64" }
    packages = %w(
      liblockfile-bin_1.09-3ubuntu0.1_amd64.deb
      liblockfile-dev_1.09-3ubuntu0.1_amd64.deb
      liblockfile1_1.09-3ubuntu0.1_amd64.deb
      ).join(" ")
    code <<-EOF
      baseurl=http://rightscale-rightimage.s3.amazonaws.com/patches/ubuntu/12.04/w-5970/
      for p in #{packages}
      do
        curl -s -S -f -L --retry 7 -O $baseurl$p
      done
      echo 'cd /tmp/packages && dpkg -i #{packages}' | chroot /mnt/image
    EOF
  end

  # - add in custom built libc packages, fixes "illegal instruction" core dump (w-12310)
  bash "install custom libc" do 
    only_if { new_resource.platform_version.to_f == 10.04 && node[:rightimage][:arch] == "x86_64" }
    packages = %w(
      libc-bin_2.11.1-0ubuntu7.11_amd64.deb
      libc-dev-bin_2.11.1-0ubuntu7.11_amd64.deb
      libc6-dbg_2.11.1-0ubuntu7.11_amd64.deb
      libc6-dev-i386_2.11.1-0ubuntu7.11_amd64.deb
      libc6-dev_2.11.1-0ubuntu7.11_amd64.deb
      libc6-i386_2.11.1-0ubuntu7.11_amd64.deb
      libc6_2.11.1-0ubuntu7.11_amd64.deb
      nscd_2.11.1-0ubuntu7.11_amd64.deb
    ).join(" ")
    cwd "#{guest_root}/tmp/packages"
    flags "-ex"
    code <<-EOH
      mount -t proc none #{guest_root}/proc
      mount --bind /dev #{guest_root}/dev
      mount --bind /sys #{guest_root}/sys
      base_url=http://rightscale-rightimage-misc.s3.amazonaws.com/ubuntu/10.04/
      for p in #{packages}
      do
        curl -s -S -f -L --retry 7 -O $base_url$p 
      done

      cat <<EOF>#{guest_root}/tmp/packages/install_debs.sh
#!/bin/bash -ex
cd /tmp/packages
dpkg -i #{packages}
EOF
      chmod a+x #{guest_root}/tmp/packages/install_debs.sh
      chroot #{guest_root} /tmp/packages/install_debs.sh
      # nscd deb starts up second version, will prevent loopback fs from dismounting
      killall nscd
      umount -lf #{guest_root}/dev || true
      umount -lf #{guest_root}/proc || true
      umount -lf #{guest_root}/sys || true
      service nscd start
    EOH
  end


  ruby_block "install guest packages" do 
    block do
      loopback_package_install node[:rightimage][:guest_packages]
    end
  end

  install_grub_package
  install_grub_config { cloud "none" }
  install_bootloader { cloud "none" }

  # TODO: Add cleanup
  bash "cleanup" do
    flags "-ex"
    code <<-EOH
      guest_root=#{guest_root}

      # Remove resolv.conf leftovers (w-5554)
      rm -rf $guest_root/etc/resolvconf/resolv.conf.d/original $guest_root/etc/resolvconf/resolv.conf.d/tail
      touch $guest_root/etc/resolvconf/resolv.conf.d/tail

      chroot #{guest_root} rm -rf /etc/init/plymouth*
      chroot #{guest_root} apt-get update > /dev/null
      chroot #{guest_root} apt-get clean
    EOH
  end
end

action :repo_freeze do
  mirror_date = "#{mirror_freeze_date[0..3]}/#{mirror_freeze_date[4..5]}/#{mirror_freeze_date[6..7]}"

  template "#{guest_root}/etc/apt/sources.list" do
    source "sources.list.erb"
    variables(
      :mirror_url => node[:rightimage][:mirror],
      :use_staging_mirror => node[:rightimage][:rightscale_staging_mirror],
      :mirror_date => mirror_date,
      :bootstrap => true,
      :platform_codename => platform_codename
    )
    backup false
  end

  # Need to apt-get update whenever the repo file is changed.
  execute "chroot #{guest_root} apt-get -y update > /dev/null"
end

action :repo_unfreeze do
  mirror_date = "latest"

  template "#{guest_root}/etc/apt/sources.list" do
    source "sources.list.erb"
    variables(
      :mirror_url => node[:rightimage][:mirror],
      :use_staging_mirror => node[:rightimage][:rightscale_staging_mirror],
      :mirror_date => mirror_date,
      :bootstrap => false,
      :platform_codename => platform_codename
    )
    backup false
  end

  # Need to apt-get update whenever the repo file is changed.
  execute "chroot #{guest_root} apt-get -y update > /dev/null"
end
