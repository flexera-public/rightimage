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
  template "/tmp/yum.conf" do 
    source "yum.conf.erb"
    backup false
    variables ({
      :bootstrap => true
    })
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

  #install syslog-ng
  chroot #{guest_root} rpm -e rsyslog --nodeps || true #remove rsyslog if it exists 
  if [ "#{node[:rightimage][:arch]}" == i386 ] ; then 
    rpm --force --root #{guest_root} -Uvh http://s3.amazonaws.com/rightscale_scripts/syslog-ng-1.6.12-1.el5.centos.i386.rpm
  else 
    rpm --force --root #{guest_root} -Uvh http://s3.amazonaws.com/rightscale_scripts/syslog-ng-1.6.12-1.x86_64.rpm
  fi
  chroot #{guest_root} chkconfig --level 234 syslog-ng on

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

  # disable loading pata_acpi module - currently breaks acpid from discovering volumes attached to CDC KVM hypervisor
  echo "blacklist pata_acpi"          > #{guest_root}/etc/modprobe.d/disable-pata_acpi.conf
  echo "install pata_acpi /bin/true" >> #{guest_root}/etc/modprobe.d/disable-pata_acpi.conf
    
  # disable IPV6
  echo "NETWORKING_IPV6=no" >> #{guest_root}/etc/sysconfig/network
  echo "install ipv6 /bin/true" > #{guest_root}/etc/modprobe.d/disable-ipv6.conf
  echo "options ipv6 disable=1" >> #{guest_root}/etc/modprobe.d/disable-ipv6.conf
  chroot #{guest_root} /sbin/chkconfig ip6tables off

  # Depricated CentOS 5.3 and older uses this to disable ipv6
  #echo "alias ipv6 off" >> #{guest_root}/etc/modprobe.conf 
  #echo "alias net-pf-10 off" >> #{guest_root}/etc/modprobe.conf 
  EOF
  end

  cookbook_file "#{guest_root}/etc/pki/rpm-gpg/RPM-GPG-KEY-RightScale" do
    source "GPG-KEY-RightScale"
    backup false
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

  repo_file = case node[:rightimage][:platform]
              when "centos" then "CentOS-Base"
              when "rhel" then "Epel"
              end

  template "#{guest_root}/etc/yum.repos.d/#{repo_file}.repo" do
    source "yum.conf.erb"
    backup false
  end

  template "#{guest_root}/root/.gemrc" do 
    source "gemrc.erb"
    backup false
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
