
action :install do 
  rightimage_os new_resource.platform do
    action :repo_freeze
  end

  # This allows builds for CentOS on Fedora and other Redhat Enterprise Linux clones.
  cookbook_file "/etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-#{node[:rightimage][:platform_version].to_i}" do
    source "RPM-GPG-KEY-CentOS-#{node[:rightimage][:platform_version].to_i}"
    action :create_if_missing
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


  # Collectd 5 is not currently supported by the RightScale monitoring servers
  # Pin to previous version from "precise" to avoid issues. These packages are
  # available from http://mirror.rightscale.com/rightscale_software_ubuntu (w-6281)
  if el7?
    package "yum-plugin-versionlock"
    cookbook_file "/etc/yum/pluginconf.d/versionlock.list" do
      source "pin_collectd"
      backup false
    end
  end

  bash "bootstrap_centos" do 
    flags "-ex"
    code <<-EOF
  ## Some yum prereqs
  mkdir -p #{guest_root}/etc
  touch #{guest_root}/etc/fstab
  mkdir -p #{guest_root}/var/log
  touch #{guest_root}/var/log/yum.log


  ## bootstrap base OS.  
  # We have to disable the rightscale-epel in the base install due to a subtle bug with
  # ius packages being in the rightscale-epel mirror.  Base wants libopenssl.so which
  # is gets supplied by the openssl10-libs package in ius, rather than the base openssl package.
  # This causes a dependency conflict at a later point
  yum -c /tmp/yum.conf  --installroot=#{guest_root} --disablerepo=rightscale-epel -y groupinstall Base 

  # Shadow file needs to be setup prior install additional packages
  if [ "#{el7?}" != "true" ]; then
    # Not working EL7 - TBD figure out why or if we need this still
    chroot #{guest_root} authconfig --enableshadow --useshadow --enablemd5 --updateall
  fi
  yum -c /tmp/yum.conf -y clean all
  yum -c /tmp/yum.conf -y makecache

  if [ "#{el7?}" = "true" ]; then
    yum -c /tmp/yum.conf --installroot=#{guest_root} -y install yum-plugin-versionlock
    cp /etc/yum/pluginconf.d/versionlock.list #{guest_root}/etc/yum/pluginconf.d/versionlock.list
  fi
  # Install these one by one... yum install doesn't fail unless every package
  # fails, so grouping them on one lines hides errors
  for p in #{node[:rightimage][:guest_packages].join(" ")}; do
    yum -c /tmp/yum.conf --installroot=#{guest_root} --exclude gcc-java -y install $p
  done
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
    sed -i "s/enabled=1/enabled=0/" #{guest_root}/etc/yum/pluginconf.d/fastestmirror.conf

    # Disable ttys
    sed -i "s/ACTIVE_CONSOLES=.*/ACTIVE_CONSOLES=/" #{guest_root}/etc/sysconfig/init
  fi

  mkdir -p #{guest_root}/etc/ssh

  mv #{guest_root}/lib/tls #{guest_root}/lib/tls.disabled || true

  ## fix logrotate
  touch #{guest_root}/var/log/boot.log

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

  #Disable FSCK on the image
  touch #{guest_root}/fastboot

  # Set timezone to UTC by default
  chroot #{guest_root} ln -sf /usr/share/zoneinfo/UTC /etc/localtime

  # disable loading pata_acpi module - currently breaks acpid from discovering volumes attached to CDC KVM hypervisor
  echo "blacklist pata_acpi"          > #{guest_root}/etc/modprobe.d/disable-pata_acpi.conf
  echo "install pata_acpi /bin/true" >> #{guest_root}/etc/modprobe.d/disable-pata_acpi.conf
    
  # disable IPV6
  if [ #{node[:rightimage][:platform_version].to_i} -lt 7 ]; then
    chroot #{guest_root} /sbin/chkconfig ip6tables off
  fi

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
 
end


action :repo_freeze do
  repo_dir = "#{guest_root}/etc/yum.repos.d"

  directory repo_dir do
    recursive true
    action :create
  end

  mirror_date = mirror_freeze_date[0..7] 

  ["/tmp/yum.conf", "#{repo_dir}/#{el_repo_file}"].each do |location|
    template location do
      source "yum.conf.erb"
      backup false
      variables({
        :bootstrap => true,
        :mirror => node[:rightimage][:mirror],
        :use_staging_mirror => node[:rightimage][:rightscale_staging_mirror],
        :mirror_date => mirror_date
      })
    end
  end
end

action :repo_unfreeze do
  template "#{guest_root}/etc/yum.repos.d/#{el_repo_file}" do
    source "yum.conf.erb"
    backup false
    variables({
      :bootstrap => false,
      :mirror => node[:rightimage][:mirror],
      :use_staging_mirror => node[:rightimage][:rightscale_staging_mirror],
      :mirror_date => "latest"
    })
  end
end
