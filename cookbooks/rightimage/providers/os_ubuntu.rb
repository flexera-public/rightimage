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

action :install do
  #create bootstrap command
  if node[:lsb][:codename] == "maverick" || node[:lsb][:codename] == "lucid"
    # install vmbuilder from deb files
    remote_file "/tmp/python-vm-builder.deb" do
      source "python-vm-builder.deb"
    end
    if node[:rightimage][:hypervisor] == "ec2" 
      remote_file "/tmp/python-vm-builder-ec2.deb" do
        source "python-vm-builder-ec2.deb"
      end 
    end
    ruby_block "install python-vm-builder debs with dependencies" do
      block do
        Chef::Log.info(`dpkg -i /tmp/python-vm-builder.deb`)
        Chef::Log.info(`dpkg -i /tmp/python-vm-builder-ec2.deb`) if node[:rightimage][:hypervisor] == 'ec2'
        Chef::Log.info(`apt-get -fy install`)
      end
    end
  end

  # TODO: Need this to be hypervisor unspecific.  debootstrap?
  bootstrap_cmd = "/usr/bin/vmbuilder xen ubuntu -o \
      --suite=#{node[:rightimage][:release]} \
      -d #{node[:rightimage][:build_dir]} \
      --rootsize=2048 \
      --install-mirror=#{node[:rightimage][:mirror_url]} \
      --install-security-mirror=#{node[:rightimage][:mirror_url]} \
      --components=main,restricted,universe,multiverse \
      --lang=#{node[:rightimage][:lang]} --verbose "
  if node[:rightimage][:arch] == "i386"
    bootstrap_cmd << " --arch i386"
    bootstrap_cmd << " --addpkg libc6-xen"
  else
    bootstrap_cmd << " --arch amd64"
  end
  node[:rightimage][:guest_packages].split.each { |p| bootstrap_cmd << " --addpkg " + p} 

  Chef::Log.info "vmbuilder bootstrap command is: " + bootstrap_cmd

  log "Configuring Image..."

  # vmbuilder is defaulting to ext4 and I couldn't find any options to force the filesystem type so I just hacked this.
  # we restore it back to normal later.  
  bash "Comment out ext4 in /etc/mke2fs.conf" do
    code <<-EOH
      set -e
      set -x
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

      if [ "#{node[:rightimage][:release]}" == "hardy" ]; then
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
  chroot \\$1 cp /usr/share/zoneinfo/UTC /etc/timezone
  chroot \\$1 userdel -r ubuntu
  chroot \\$1 rm -rf /home/ubuntu
  chroot \\$1 rm -f /etc/hostname
  chroot \\$1 touch /fastboot
  chroot \\$1 apt-get remove -y apparmor apparmor-utils 
  chroot \\$1 shadowconfig on
  chroot \\$1  sed -i s/root::/root:*:/ /etc/shadow
  chroot \\$1 ln -s /usr/bin/env /bin/env
  chroot \\$1 rm -f /etc/rc?.d/*hwclock*
  chroot \\$1 rm -f /etc/event.d/tty[2-6]
  if [ ! -e \\$1/usr/bin/ruby ]; then 
    chroot \\$1 ln -s /usr/bin/ruby1.8 /usr/bin/ruby
  fi

  EOS
      chmod +x /tmp/configure_script
      #{bootstrap_cmd} --exec=/tmp/configure_script


      if ( [ "#{node[:rightimage][:release]}" == "lucid" ] || [ "#{node[:rightimage][:release]}" == "maverick" ] ) ; then
       kvm_image=`cat /mnt/vmbuilder/xen.conf  | grep xvda1 | grep -v root  | cut -c 25- | cut -c -9`
      else
       kvm_image=$image_name
      fi

      loop_name="loop1"
      loop_dev="/dev/$loop_name"

      base_raw_path="/mnt/vmbuilder/root.img"

      sync
      # Cleanup loopback stuff
      set +e
      losetup -a | grep $loop_name
      [ "$?" == "0" ] && losetup -d $loop_dev
      set -e

      qemu-img convert -O raw /mnt/vmbuilder/$kvm_image $base_raw_path
      losetup $loop_dev $base_raw_path

      guest_root=#{source_image}

      random_dir=/tmp/rightimage-$RANDOM
      mkdir $random_dir
      mount -o loop $loop_dev  $random_dir
      umount $guest_root/proc || true
      rm -rf $guest_root/*
      rsync -a $random_dir/ $guest_root/
      umount $random_dir
      sync
      losetup -d $loop_dev
      rm -rf $random_dir
      mkdir -p $guest_root/var/man
      chroot $guest_root chown -R man:root /var/man
  EOH
  end

  #  - configure mirrors
  template "#{guest_root}/#{node[:rightimage][:mirror_file_path]}" do 
    source node[:rightimage][:mirror_file] 
    backup false
  end 

  bash "Restore original ext4 in /etc/mke2fs.conf" do
    code <<-EOH
      set -e
      set -x
      sed -i '/ext4/,/}/ s/^#//' /etc/mke2fs.conf 
    EOH
  end

  java_temp = "/tmp/java"

  directory java_temp do
    action :delete
    recursive true
  end

  directory java_temp do
    action :create
  end

  bash "install sun java" do
    cwd java_temp
    flags "-ex"
    code <<-EOH
      guest_root=#{guest_root}
      java_home="/usr/lib/jvm/java-6-sun"
      java_ver="31"

      if [ "#{node[:rightimage][:arch]}" == x86_64 ] ; then
        java_arch="x64"
      else
        java_arch="i586"
      fi

      java_file=jdk-6u$java_ver-linux-$java_arch.bin

      wget http://s3.amazonaws.com/rightscale_software/java/$java_file
      chmod +x /tmp/java/$java_file
      echo "\\n" | /tmp/java/$java_file
      rm -rf $guest_root${java_home}
      mkdir -p $guest_root${java_home}
      mv /tmp/java/jdk1.6.0_$java_ver/* $guest_root${java_home}

      cat >$guest_root/etc/profile.d/java.sh <<EOF
  JAVA_HOME=$java_home
  export JAVA_HOME
  EOF

      chmod 775 $guest_root/etc/profile.d/java.sh
    EOH
  end

  # Modified version of syslog-ng.conf that will properly route recipe output to /var/log/messages
  remote_file "#{source_image}/etc/syslog-ng/syslog-ng.conf" do
    source "syslog-ng.conf"
  end

  # Set DHCP timeout
  bash "dhcp timeout" do
    flags "-ex"
    code <<-EOH
      sed -i "s/#timeout.*/timeout 300;/" #{source_image}/etc/dhcp3/dhclient.conf
      rm -f #{source_image}/var/lib/dhcp3/*
    EOH
  end

  # Don't let SysV init start until more than lo0 is ready
  bash "sysv upstart fix" do
    flags "-ex"
    code <<-EOH
      sed -i "s/IFACE=/IFACE\!=/" #{source_image}/etc/init/rc-sysinit.conf
    EOH
  end

  log "Setting APT::Install-Recommends to false"
  bash "apt config" do
    flags "-ex"
    code <<-EOH
      echo "APT::Install-Recommends \"0\";" > #{source_image}/etc/apt/apt.conf
    EOH
  end

  log "Disable HTTP pipeline on APT"
  bash "apt config pipeline" do
    flags "-ex"
    code <<-EOH
      echo "Acquire::http::Pipeline-Depth \"0\";" > #{source_image}/etc/apt/apt.conf.d/99-no-pipelining
    EOH
  end

  # TODO: Add cleanup
  bash "cleanup" do
    flags "-ex"
    code <<-EOH

      chroot #{source_image} rm -rf /etc/init/plymouth* /etc/init/rsyslog.conf
      chroot #{source_image} apt-get update
      chroot #{source_image} apt-get clean
    EOH
  end
end
