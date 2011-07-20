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

  code <<-EOF
set -x
set -e

## yum is getting mad that /etc/fstab does not exist and that /proc is not mounted
mkdir -p #{node[:rightimage][:mount_dir]}/etc
touch #{node[:rightimage][:mount_dir]}/etc/fstab

mkdir -p #{node[:rightimage][:mount_dir]}/proc
umount #{node[:rightimage][:mount_dir]}/proc || true
mount --bind /proc #{node[:rightimage][:mount_dir]}/proc

mkdir -p #{node[:rightimage][:mount_dir]}/sys
umount #{node[:rightimage][:mount_dir]}/sys || true
mount --bind /sys #{node[:rightimage][:mount_dir]}/sys

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
# install the guest packages in the chroot
yum -c /tmp/yum.conf --installroot=#{node[:rightimage][:mount_dir]} -y install  #{node[:rightimage][:guest_packages]}
yum -c /tmp/yum.conf --installroot=#{node[:rightimage][:mount_dir]} -y remove bluez* gnome-bluetooth*
yum -c /tmp/yum.conf --installroot=#{node[:rightimage][:mount_dir]} -y clean all


## stop crap from going in the logs...    
rm #{node[:rightimage][:mount_dir]}/var/lib/rpm/__*
chroot #{node[:rightimage][:mount_dir]} rpm --rebuilddb

## Remove yum-fastestmirror plugin
chroot #{node[:rightimage][:mount_dir]} rpm -e --nodeps yum-fastestmirror

mkdir -p #{node[:rightimage][:mount_dir]}/etc/ssh

echo 'hwcap 0 nosegneg' > #{node[:rightimage][:mount_dir]}/etc/ld.so.conf.d/libc6-xen.conf
chroot #{node[:rightimage][:mount_dir]} /sbin/ldconfig -v
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
chroot #{node[:rightimage][:mount_dir]} service network start

rm #{node[:rightimage][:mount_dir]}/etc/yum.repos.d/CentOS-Media.repo
curl -o #{node[:rightimage][:mount_dir]}/etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL http://download.fedora.redhat.com/pub/epel/RPM-GPG-KEY-EPEL

echo "PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/local/lib/pkgconfig" > #{node[:rightimage][:mount_dir]}/etc/profile.d/pkgconfig.sh

chmod +x #{node[:rightimage][:mount_dir]}/tmp/chkconfig 
chroot #{node[:rightimage][:mount_dir]} /tmp/chkconfig
rm -f #{node[:rightimage][:mount_dir]}/tmp/chkconfig


sed -i s/root::/root:*:/ #{node[:rightimage][:mount_dir]}/etc/shadow



echo "127.0.0.1   localhost   localhost.localdomain" > #{node[:rightimage][:mount_dir]}/etc/hosts
echo "NOZEROCONF=true" >> #{node[:rightimage][:mount_dir]}/etc/sysconfig/network

chroot #{node[:rightimage][:mount_dir]} service network restart


#install syslog-ng
chroot #{node[:rightimage][:mount_dir]} rpm -e rsyslog --nodeps || true #remove rsyslog if it exists 
if [ "#{node[:rightimage][:arch]}" == i386 ] ; then 
  chroot #{node[:rightimage][:mount_dir]} rpm -Uvh http://s3.amazonaws.com/rightscale_scripts/syslog-ng-1.6.12-1.el5.centos.i386.rpm
else 
  chroot #{node[:rightimage][:mount_dir]} rpm -Uvh http://s3.amazonaws.com/rightscale_scripts/syslog-ng-1.6.12-1.x86_64.rpm
fi
chroot #{node[:rightimage][:mount_dir]} chkconfig --level 234 syslog-ng on


#Install the JDK from S3.
if [ "#{node[:rightimage][:arch]}" == x86_64 ] ; then 
  java_arch="amd64"
else 
  java_arch="i586"
fi

chroot #{node[:rightimage][:mount_dir]} mkdir -p /tmp/updates

#get java RPM
chroot #{node[:rightimage][:mount_dir]} curl -o /tmp/updates/jdk-6u14-linux-$java_arch.rpm https://s3.amazonaws.com/rightscale_software/java/jdk-6u14-linux-$java_arch.rpm

#get JavaDB (always use i386 RPM's, even for 64 bit)
chroot #{node[:rightimage][:mount_dir]} curl -o /tmp/updates/sun-javadb-common-10.4.2-1.1.i386.rpm https://s3.amazonaws.com/rightscale_software/java/sun-javadb-common-10.4.2-1.1.i386.rpm
chroot #{node[:rightimage][:mount_dir]} curl -o /tmp/updates/sun-javadb-client-10.4.2-1.1.i386.rpm https://s3.amazonaws.com/rightscale_software/java/sun-javadb-client-10.4.2-1.1.i386.rpm
chroot #{node[:rightimage][:mount_dir]} curl -o /tmp/updates/sun-javadb-core-10.4.2-1.1.i386.rpm https://s3.amazonaws.com/rightscale_software/java/sun-javadb-core-10.4.2-1.1.i386.rpm
chroot #{node[:rightimage][:mount_dir]} curl -o /tmp/updates/sun-javadb-demo-10.4.2-1.1.i386.rpm https://s3.amazonaws.com/rightscale_software/java/sun-javadb-demo-10.4.2-1.1.i386.rpm
chroot #{node[:rightimage][:mount_dir]} curl -o /tmp/updates/sun-javadb-docs-10.4.2-1.1.i386.rpm https://s3.amazonaws.com/rightscale_software/java/sun-javadb-docs-10.4.2-1.1.i386.rpm
chroot #{node[:rightimage][:mount_dir]} curl -o /tmp/updates/sun-javadb-javadoc-10.4.2-1.1.i386.rpm https://s3.amazonaws.com/rightscale_software/java/sun-javadb-javadoc-10.4.2-1.1.i386.rpm

#Install RPM's
chroot #{node[:rightimage][:mount_dir]} rpm -Uvh /tmp/updates/jdk-6u14-linux-$java_arch.rpm

chroot #{node[:rightimage][:mount_dir]} rpm -Uvh /tmp/updates/sun-javadb-common-10.4.2-1.1.i386.rpm
chroot #{node[:rightimage][:mount_dir]} rpm -Uvh /tmp/updates/sun-javadb-client-10.4.2-1.1.i386.rpm
chroot #{node[:rightimage][:mount_dir]} rpm -Uvh /tmp/updates/sun-javadb-core-10.4.2-1.1.i386.rpm
chroot #{node[:rightimage][:mount_dir]} rpm -Uvh /tmp/updates/sun-javadb-demo-10.4.2-1.1.i386.rpm
chroot #{node[:rightimage][:mount_dir]} rpm -Uvh /tmp/updates/sun-javadb-docs-10.4.2-1.1.i386.rpm
chroot #{node[:rightimage][:mount_dir]} rpm -Uvh /tmp/updates/sun-javadb-javadoc-10.4.2-1.1.i386.rpm


#Add JAVA_HOME to the system profile
echo "Configuring Java Home" 
echo "export JAVA_HOME=/usr/java/default" >> #{node[:rightimage][:mount_dir]}/etc/profile.d/java.sh
chmod +x #{node[:rightimage][:mount_dir]}/etc/profile.d/java.sh

#Disable FSCK on the image
touch #{node[:rightimage][:mount_dir]}/fastboot

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

include_recipe "rightimage::bootstrap_common"

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
  source "gemrc.erb"
  backup false
end

bash "clean_db" do 
  code <<-EOH
    #have to do this to fix a yummy bug
    rm #{node[:rightimage][:mount_dir]}/var/lib/rpm/__*
    chroot #{node[:rightimage][:mount_dir]} rpm --rebuilddb
  EOH
end

bash "cleanup" do
  code <<-EOH
    umount -lf #{node[:rightimage][:mount_dir]}/proc || true
    umount -lf #{node[:rightimage][:mount_dir]}/sys || true
  EOH
end    



