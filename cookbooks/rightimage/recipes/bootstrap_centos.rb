rs_utils_marker :begin
class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end
class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

template "/tmp/yum.conf" do 
  source "yum.conf.erb"
  backup false
  variables ({
    :bootstrap => true
  })
end

directory "#{node[:rightimage][:mount_dir]}/tmp" do 
  recursive true
end

remote_file "#{node[:rightimage][:mount_dir]}/tmp/chkconfig" do 
   source "chkconfig"  
   backup false
end

directory "#{node[:rightimage][:mount_dir]}/etc/sysconfig" do 
  recursive true
end

directory "#{node[:rightimage][:mount_dir]}/etc/sysconfig/network-scripts" do 
  recursive true
end

remote_file "#{node[:rightimage][:mount_dir]}/etc/sysconfig/network" do 
  source "network" 
  backup false
end

remote_file "#{node[:rightimage][:mount_dir]}/etc/sysconfig/network-scripts/ifcfg-eth0" do 
  source "ifcfg-eth0" 
  backup false
end

bash "bootstrap_centos" do 
  flags "-ex"
  code <<-EOF
## yum is getting mad that /etc/fstab does not exist and that /proc is not mounted
mkdir -p #{node[:rightimage][:mount_dir]}/etc
touch #{node[:rightimage][:mount_dir]}/etc/fstab

mkdir -p #{node[:rightimage][:mount_dir]}/proc
umount #{node[:rightimage][:mount_dir]}/proc || true
mount --bind /proc #{node[:rightimage][:mount_dir]}/proc

mkdir -p #{node[:rightimage][:mount_dir]}/sys
umount #{node[:rightimage][:mount_dir]}/sys || true
mount --bind /sys #{node[:rightimage][:mount_dir]}/sys

umount #{node[:rightimage][:mount_dir]}/dev/pts || true

## bootstrap base OS
yum -c /tmp/yum.conf --installroot=#{node[:rightimage][:mount_dir]} -y groupinstall Base 

/sbin/MAKEDEV -d #{node[:rightimage][:mount_dir]}/dev -x console
/sbin/MAKEDEV -d #{node[:rightimage][:mount_dir]}/dev -x null
/sbin/MAKEDEV -d #{node[:rightimage][:mount_dir]}/dev -x zero
/sbin/MAKEDEV -d #{node[:rightimage][:mount_dir]}/dev ptmx

mkdir -p #{node[:rightimage][:mount_dir]}/dev/pts
mkdir -p #{node[:rightimage][:mount_dir]}/sys/block
mkdir -p #{node[:rightimage][:mount_dir]}/var/log
touch #{node[:rightimage][:mount_dir]}/var/log/yum.log

mkdir -p #{node[:rightimage][:mount_dir]}/proc
chroot #{node[:rightimage][:mount_dir]} mount -t devpts none /dev/pts || true
test -e /dev/ptmx #|| chroot $imagedir mknod --mode 666 /dev/ptmx c 5 2
              
# Shadow file needs to be setup prior install additional packages
chroot #{node[:rightimage][:mount_dir]} authconfig --enableshadow --useshadow --enablemd5 --updateall
# install guest packages on CentOS 5.2 i386 host to work around yum problem
yum -c /tmp/yum.conf -y clean all
yum -c /tmp/yum.conf -y makecache
yum -c /tmp/yum.conf -y install #{node[:rightimage][:guest_packages]}
# Install postfix separately, don't want to use centosplus version which bundles mysql
yum -c /tmp/yum.conf --installroot=#{node[:rightimage][:mount_dir]} -y install postfix --disablerepo=centosplus
# install the guest packages in the chroot
yum -c /tmp/yum.conf --installroot=#{node[:rightimage][:mount_dir]} -y install  #{node[:rightimage][:guest_packages]}
yum -c /tmp/yum.conf --installroot=#{node[:rightimage][:mount_dir]} -y remove bluez* gnome-bluetooth*
yum -c /tmp/yum.conf --installroot=#{node[:rightimage][:mount_dir]} -y clean all

## stop crap from going in the logs...    
rm -f #{node[:rightimage][:mount_dir]}/var/lib/rpm/__*
chroot #{node[:rightimage][:mount_dir]} rpm --rebuilddb

if [ #{node[:rightimage][:release].to_i} -lt 6 ]; then
  ## Remove yum-fastestmirror plugin
  set +e
  chroot #{node[:rightimage][:mount_dir]} rpm -e --nodeps yum-fastestmirror
  set -e

  echo 'hwcap 0 nosegneg' > #{node[:rightimage][:mount_dir]}/etc/ld.so.conf.d/libc6-xen.conf
  chroot #{node[:rightimage][:mount_dir]} /sbin/ldconfig -v

  curl -o #{node[:rightimage][:mount_dir]}/etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL https://fedoraproject.org/static/217521F6.txt
else
  curl -o #{node[:rightimage][:mount_dir]}/etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6 https://fedoraproject.org/static/0608B895.txt

  # Disable ttys
  sed -i "s/ACTIVE_CONSOLES=.*/ACTIVE_CONSOLES=/" #{node[:rightimage][:mount_dir]}/etc/sysconfig/init
fi

mkdir -p #{node[:rightimage][:mount_dir]}/etc/ssh

mv #{node[:rightimage][:mount_dir]}/lib/tls #{node[:rightimage][:mount_dir]}/lib/tls.disabled || true

## fix logrotate
touch #{node[:rightimage][:mount_dir]}/var/log/boot.log

## enable name server caching daemon on boot
chroot #{node[:rightimage][:mount_dir]} chkconfig --level 2345 nscd on

echo "Disabling TTYs"
perl -p -i -e 's/(.*tty2)/#\1/' #{node[:rightimage][:mount_dir]}/etc/inittab
perl -p -i -e 's/(.*tty3)/#\1/' #{node[:rightimage][:mount_dir]}/etc/inittab
perl -p -i -e 's/(.*tty4)/#\1/' #{node[:rightimage][:mount_dir]}/etc/inittab
perl -p -i -e 's/(.*tty5)/#\1/' #{node[:rightimage][:mount_dir]}/etc/inittab
perl -p -i -e 's/(.*tty6)/#\1/' #{node[:rightimage][:mount_dir]}/etc/inittab

rm -f #{node[:rightimage][:mount_dir]}/etc/yum.repos.d/CentOS-Media.repo

echo "PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/local/lib/pkgconfig" > #{node[:rightimage][:mount_dir]}/etc/profile.d/pkgconfig.sh

chmod +x #{node[:rightimage][:mount_dir]}/tmp/chkconfig 
chroot #{node[:rightimage][:mount_dir]} /tmp/chkconfig
rm -f #{node[:rightimage][:mount_dir]}/tmp/chkconfig

sed -i s/root::/root:*:/ #{node[:rightimage][:mount_dir]}/etc/shadow

echo "127.0.0.1   localhost   localhost.localdomain" > #{node[:rightimage][:mount_dir]}/etc/hosts
echo "NOZEROCONF=true" >> #{node[:rightimage][:mount_dir]}/etc/sysconfig/network

#install syslog-ng
chroot #{node[:rightimage][:mount_dir]} rpm -e rsyslog --nodeps || true #remove rsyslog if it exists 
if [ "#{node[:rightimage][:arch]}" == i386 ] ; then 
  rpm --force --root #{node[:rightimage][:mount_dir]} -Uvh http://s3.amazonaws.com/rightscale_scripts/syslog-ng-1.6.12-1.el5.centos.i386.rpm
else 
  rpm --force --root #{node[:rightimage][:mount_dir]} -Uvh http://s3.amazonaws.com/rightscale_scripts/syslog-ng-1.6.12-1.x86_64.rpm
fi
chroot #{node[:rightimage][:mount_dir]} chkconfig --level 234 syslog-ng on

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
  ret=$(rpm --root #{node[:rightimage][:mount_dir]} -Uvh http://s3.amazonaws.com/rightscale_software/java/$i 2>&1)
  [ "$?" == "0" ] && continue
  echo "$ret" | grep "already installed"
  [ "$?" != "0" ] && exit 1
done
set -e

#Add JAVA_HOME to the system profile
echo "Configuring Java Home" 
echo "export JAVA_HOME=/usr/java/default" >> #{node[:rightimage][:mount_dir]}/etc/profile.d/java.sh
chmod +x #{node[:rightimage][:mount_dir]}/etc/profile.d/java.sh

#Disable FSCK on the image
touch #{node[:rightimage][:mount_dir]}/fastboot

# disable loading pata_acpi module - currently breaks acpid from discovering volumes attached to CDC KVM hypervisor
echo "blacklist pata_acpi"          > #{node[:rightimage][:mount_dir]}/etc/modprobe.d/disable-pata_acpi.conf
echo "install pata_acpi /bin/true" >> #{node[:rightimage][:mount_dir]}/etc/modprobe.d/disable-pata_acpi.conf
  
# disable IPV6
echo "NETWORKING_IPV6=no" >> #{node[:rightimage][:mount_dir]}/etc/sysconfig/network
echo "install ipv6 /bin/true" > #{node[:rightimage][:mount_dir]}/etc/modprobe.d/disable-ipv6.conf
echo "options ipv6 disable=1" >> #{node[:rightimage][:mount_dir]}/etc/modprobe.d/disable-ipv6.conf
chroot #{node[:rightimage][:mount_dir]} /sbin/chkconfig ip6tables off

# Depricated CentOS 5.3 and older uses this to disable ipv6
#echo "alias ipv6 off" >> #{node[:rightimage][:mount_dir]}/etc/modprobe.conf 
#echo "alias net-pf-10 off" >> #{node[:rightimage][:mount_dir]}/etc/modprobe.conf 
EOF
end

remote_file "#{node[:rightimage][:mount_dir]}/root/.bash_profile" do 
  source "bash_profile" 
  backup false
end

remote_file "#{node[:rightimage][:mount_dir]}/root/.bash_logout" do 
  source "bash_logout" 
  backup false
end

remote_file "#{node[:rightimage][:mount_dir]}/etc/motd" do 
  source "motd" 
  backup false
end


remote_file "#{node[:rightimage][:mount_dir]}/etc/profile.d/pkgconfig.sh" do 
  source "pkgconfig.sh" 
  mode "0755"
  backup false
end

template "#{node[:rightimage][:mount_dir]}/etc/yum.repos.d/CentOS-Base.repo" do 
  source "yum.conf.erb"
  backup false
end

template "#{node[:rightimage][:mount_dir]}/root/.gemrc" do 
  # Issue: gem install segfaults with a buffer overflow error in the syck (yaml parsing)
  # code (compiled into ruby) for ruby 1.8.5 with mirror beyond this date.  one of rubygems
  # yaml files probably changed format slightly in incompatable way
  freeze_date = timestamp[0..7]
  if freeze_date > "20120514"
    freeze_date = "20120514"
  end
  variables(
    :mirror_base_url => node[:rightimage][:mirror],
    :mirror_freeze_date => freeze_date
  )
  source "gemrc.erb"
  backup false
end

bash "clean_db" do 
  code <<-EOH
    #have to do this to fix a yummy bug
    rm -f #{node[:rightimage][:mount_dir]}/var/lib/rpm/__*
    chroot #{node[:rightimage][:mount_dir]} rpm --rebuilddb
  EOH
end

bash "cleanup" do
  code <<-EOH
    umount -lf #{node[:rightimage][:mount_dir]}/proc || true
    umount -lf #{node[:rightimage][:mount_dir]}/sys || true
    umount -lf #{node[:rightimage][:mount_dir]}/dev/pts || true
  EOH
end    
rs_utils_marker :end
