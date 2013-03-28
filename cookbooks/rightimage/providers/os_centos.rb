class Chef::Resource
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end
class Erubis::Context
  include RightScale::RightImage::Helper
end


action :install do 
  rightimage_os new_resource.platform do
    action :repo_freeze
  end

  cookbook_file "/etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL#{epel_key_name}" do
     source "RPM-GPG-KEY-EPEL#{epel_key_name}"
     backup false
  end

  directory "#{guest_root}/etc/pki/rpm-gpg" do
    recursive true
  end

  cookbook_file "#{guest_root}/etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL#{epel_key_name}" do
     source "RPM-GPG-KEY-EPEL#{epel_key_name}"
     backup false
  end

  directory "#{guest_root}/tmp" do 
    recursive true
  end

  cookbook_file "#{guest_root}/tmp/chkconfig" do 
     source "chkconfig"  
     backup false
  end

  directory "#{guest_root}/etc/sysconfig" do 
    recursive true
  end

  directory "#{guest_root}/etc/sysconfig/network-scripts" do 
    recursive true
  end

  cookbook_file "#{guest_root}/etc/sysconfig/network" do 
    source "network" 
    backup false
  end

  cookbook_file "#{guest_root}/etc/sysconfig/network-scripts/ifcfg-eth0" do 
    source "ifcfg-eth0" 
    backup false
  end

  bash "bootstrap_centos" do 
    flags "-ex"
    code <<-EOF
  ## yum is getting mad that /etc/fstab does not exist and that /proc is not mounted
  mkdir -p #{guest_root}/etc
  touch #{guest_root}/etc/fstab

  mkdir -p #{guest_root}/proc
  umount #{guest_root}/proc || true
  mount --bind /proc #{guest_root}/proc

  mkdir -p #{guest_root}/sys
  umount #{guest_root}/sys || true
  mount --bind /sys #{guest_root}/sys

  umount #{guest_root}/dev/pts || true

  ## bootstrap base OS
  yum -c /tmp/yum.conf --installroot=#{guest_root} -y groupinstall Base 

  /sbin/MAKEDEV -d #{guest_root}/dev -x console
  /sbin/MAKEDEV -d #{guest_root}/dev -x null
  /sbin/MAKEDEV -d #{guest_root}/dev -x zero
  /sbin/MAKEDEV -d #{guest_root}/dev ptmx
  /sbin/MAKEDEV -d #{guest_root}/dev urandom

  mkdir -p #{guest_root}/dev/pts
  mkdir -p #{guest_root}/sys/block
  mkdir -p #{guest_root}/var/log
  touch #{guest_root}/var/log/yum.log

  mkdir -p #{guest_root}/proc
  chroot #{guest_root} mount -t devpts none /dev/pts || true
  test -e /dev/ptmx #|| chroot $imagedir mknod --mode 666 /dev/ptmx c 5 2
                
  # Shadow file needs to be setup prior install additional packages
  chroot #{guest_root} authconfig --enableshadow --useshadow --enablemd5 --updateall
  yum -c /tmp/yum.conf -y clean all
  yum -c /tmp/yum.conf -y makecache
  # used to install a full set of packages on local os, it screws up if you want to use a freezedate
  # that's older than the host os.  its probably not even necessary anymore, so comment out for now - PS
  #  old comment re this was: "install guest packages on CentOS 5.2 i386 host to work around yum problem"
  # yum -c /tmp/yum.conf -y install #{node[:rightimage][:guest_packages]} --exclude gcc-java
  # Install postfix separately, don't want to use centosplus version which bundles mysql
  yum -c /tmp/yum.conf --installroot=#{guest_root} -y install postfix --disablerepo=centosplus
  yum -c /tmp/yum.conf --installroot=#{guest_root} -y remove sendmail

  # install the guest packages in the chroot
  if [ "5" == "#{node[:rightimage][:platform_version].to_i}" ]; then
    yum -c /tmp/yum.conf --installroot=#{guest_root} --exclude='*.i386' -y install --enablerepo=ruby_custom #{node[:rightimage][:ruby_packages]}
  fi

  yum -c /tmp/yum.conf --installroot=#{guest_root} -y install #{node[:rightimage][:guest_packages]} --exclude gcc-java

  yum -c /tmp/yum.conf --installroot=#{guest_root} -y remove bluez* gnome-bluetooth*
  yum -c /tmp/yum.conf --installroot=#{guest_root} -y clean all

  ## stop crap from going in the logs...    
  rm -f #{guest_root}/var/lib/rpm/__*
  chroot #{guest_root} rpm --rebuilddb

  if [ #{node[:rightimage][:platform_version].to_i} -lt 6 ]; then
    ## Remove yum-fastestmirror plugin
    set +e
    chroot #{guest_root} rpm -e --nodeps yum-fastestmirror
    set -e

    echo 'hwcap 0 nosegneg' > #{guest_root}/etc/ld.so.conf.d/libc6-xen.conf
    chroot #{guest_root} /sbin/ldconfig -v

  else
    set +e
    chroot #{guest_root} rpm -e --nodeps yum-plugin-fastestmirror
    set -e

    # Disable ttys
    sed -i "s/ACTIVE_CONSOLES=.*/ACTIVE_CONSOLES=/" #{guest_root}/etc/sysconfig/init
  fi

  mkdir -p #{guest_root}/etc/ssh

  mv #{guest_root}/lib/tls #{guest_root}/lib/tls.disabled || true

  ## fix logrotate
  touch #{guest_root}/var/log/boot.log

  ## enable name server caching daemon on boot
  chroot #{guest_root} chkconfig --level 2345 nscd on

  echo "Disabling TTYs"
  perl -p -i -e 's/(.*tty2)/#\1/' #{guest_root}/etc/inittab
  perl -p -i -e 's/(.*tty3)/#\1/' #{guest_root}/etc/inittab
  perl -p -i -e 's/(.*tty4)/#\1/' #{guest_root}/etc/inittab
  perl -p -i -e 's/(.*tty5)/#\1/' #{guest_root}/etc/inittab
  perl -p -i -e 's/(.*tty6)/#\1/' #{guest_root}/etc/inittab

  rm -f #{guest_root}/etc/yum.repos.d/CentOS-Media.repo

  echo "PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/local/lib/pkgconfig" > #{guest_root}/etc/profile.d/pkgconfig.sh

  chmod +x #{guest_root}/tmp/chkconfig 
  chroot #{guest_root} /tmp/chkconfig
  rm -f #{guest_root}/tmp/chkconfig

  sed -i s/root::/root:*:/ #{guest_root}/etc/shadow

  echo "127.0.0.1   localhost   localhost.localdomain" > #{guest_root}/etc/hosts
  echo "NOZEROCONF=true" >> #{guest_root}/etc/sysconfig/network

  # Start rsyslog on startup
  chroot #{guest_root} chkconfig --level 234 rsyslog on

  #Install the JDK from S3.
  if [ "#{node[:rightimage][:arch]}" == x86_64 ] ; then 
    java_arch="amd64"
  else 
    java_arch="i586"
  fi

  java_ver="6u31"
  javadb_ver="10.6.2-1.1"

  array=( jdk-$java_ver-linux-$java_arch.rpm sun-javadb-common-$javadb_ver.i386.rpm sun-javadb-client-$javadb_ver.i386.rpm sun-javadb-core-$javadb_ver.i386.rpm sun-javadb-demo-$javadb_ver.i386.rpm )
  set +e
  for i in "${array[@]}"; do
    ret=$(rpm --root #{guest_root} -Uvh http://s3.amazonaws.com/rightscale_software/java/$i 2>&1)
    [ "$?" == "0" ] && continue
    echo "$ret" | grep "already installed"
    [ "$?" != "0" ] && exit 1
  done
  set -e

  #Add JAVA_HOME to the system profile
  echo "Configuring Java Home" 
  echo "export JAVA_HOME=/usr/java/default" >> #{guest_root}/etc/profile.d/java.sh
  chmod +x #{guest_root}/etc/profile.d/java.sh

  # Remove system java
  yum -y --installroot=#{guest_root} remove java

  #Disable FSCK on the image
  touch #{guest_root}/fastboot

  # Set timezone to UTC by default
  chroot #{guest_root} ln -sf /usr/share/zoneinfo/UTC /etc/localtime

  # disable loading pata_acpi module - currently breaks acpid from discovering volumes attached to CDC KVM hypervisor
  echo "blacklist pata_acpi"          > #{guest_root}/etc/modprobe.d/disable-pata_acpi.conf
  echo "install pata_acpi /bin/true" >> #{guest_root}/etc/modprobe.d/disable-pata_acpi.conf
    
  # disable IPV6
  chroot #{guest_root} /sbin/chkconfig ip6tables off

  # Configure NTP - RightLink requires local time to be accurate (w-5025)
  # Enable ntpd on startup
  chroot #{guest_root} chkconfig ntpd on

  # Add -g option to ntpd to allow offset to exceed default panic threshold.
  # This shouldn't actually be necessary due to the "tinker panic" option, but doesn't hurt.
  ntp_sys="#{guest_root}/etc/sysconfig/ntpd"
  set +e
  grep " -g" $ntp_sys
  [ "$?" == "1" ] && echo "OPTIONS=\"\$OPTIONS -g\"" >> $ntp_sys
  set -e
  EOF
  end

  # Fix for illegal instruction error caused by AVX extension (w-4923)
  # See https://bugzilla.redhat.com/show_bug.cgi?id=752122, patch backported
  if node[:rightimage][:platform_version].to_s == "6.2"
    directory "/tmp/packages"
    bash "install custom libc" do
      packages = %w(
        nscd-2.12-1.47.el6.x86_64.rpm
        glibc-utils-2.12-1.47.el6.x86_64.rpm
        glibc-static-2.12-1.47.el6.x86_64.rpm
        glibc-headers-2.12-1.47.el6.x86_64.rpm
        glibc-devel-2.12-1.47.el6.x86_64.rpm
        glibc-debuginfo-common-2.12-1.47.el6.x86_64.rpm
        glibc-debuginfo-2.12-1.47.el6.x86_64.rpm
        glibc-common-2.12-1.47.el6.x86_64.rpm
        glibc-2.12-1.47.el6.x86_64.rpm
      ).join(" ")
      cwd "/tmp/packages"
      flags "-ex"
      code <<-EOH
      base_url=http://rightscale-rightimage.s3.amazonaws.com/patches/centos/6.2/w-4923/RPMS/x86_64/
      for p in #{packages}
      do
        curl -s -S -f -L --retry 7 -O $base_url$p 
      done

      rpm --force --nodeps --root #{guest_root} --upgrade #{packages}
      EOH
    end
  end

  cookbook_file "#{guest_root}/etc/pki/rpm-gpg/RPM-GPG-KEY-RightScale" do
    source "GPG-KEY-RightScale"
    backup false
  end

  # Grubby requires a symlink to /etc/grub.conf.
  execute "grub symlink" do
    command "chroot #{guest_root} ln -s /boot/grub/menu.lst /etc/grub.conf"
    creates "#{guest_root}/etc/grub.conf"
  end

  # Setup /etc/sysconfig/kernel to allow grub to auto-update grub.conf when updating kernel.
  template "#{guest_root}/etc/sysconfig/kernel" do
    source "sysconfig-kernel.erb"
    backup false
    variables({
      :kernel => (el6?)?"kernel" : "kernel-xen"
    })
  end

  cookbook_file "#{guest_root}/root/.bash_profile" do 
    source "bash_profile" 
    backup false
  end

  cookbook_file "#{guest_root}/root/.bash_logout" do 
    source "bash_logout" 
    backup false
  end

  cookbook_file "#{guest_root}/etc/motd" do 
    source "motd" 
    backup false
  end

  cookbook_file "#{guest_root}/etc/profile.d/pkgconfig.sh" do 
    source "pkgconfig.sh" 
    mode "0755"
    backup false
  end

  rightimage_os new_resource.platform do
    action :repo_unfreeze
  end

  bash "clean_db" do 
    code <<-EOH
      #have to do this to fix a yummy bug
      rm -f #{guest_root}/var/lib/rpm/__*
      chroot #{guest_root} rpm --rebuilddb
    EOH
  end

  bash "cleanup" do
    code <<-EOH
      umount -lf #{guest_root}/proc || true
      umount -lf #{guest_root}/sys || true
      umount -lf #{guest_root}/dev/pts || true
    EOH
  end    
end

action :repo_freeze do
  repo_dir = "#{guest_root}/etc/yum.repos.d"

  directory repo_dir do
    recursive true
    action :create
  end

  ["/tmp/yum.conf", "#{repo_dir}/#{el_repo_file}"].each do |location|
    template location do
      source "yum.conf.erb"
      backup false
      variables ({
        :bootstrap => true,
        :mirror_date => mirror_freeze_date
      })
    end
  end
end

action :repo_unfreeze do
  template "#{guest_root}/etc/yum.repos.d/#{el_repo_file}" do
    source "yum.conf.erb"
    backup false
    variables ({
      :bootstrap => false,
      :mirror_date => "latest"
    })
  end
end
