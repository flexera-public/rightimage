# bootstrap_ubuntu.rb
# 
# Use vmbuilder to generate a base virtual image.  We will use the image generated here for other recipes to add
# Cloud and Hypervisor specific details.
#
# When this is finished running, you should have a basic image ready in /mnt
#
class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end
class Erubis::Context
  include RightScale::RightImage::Helper
end
class Chef::Resource::Execute
  include RightScale::RightImage::Helper
end
class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end

mount_dir = node[:rightimage][:mount_dir]

#install prereq packages
node[:rightimage][:host_packages].split.each { |p| package p} 

#create bootstrap command
if node[:lsb][:codename] == "maverick" || node[:lsb][:codename] == "lucid"
  # install vmbuilder from deb files
  remote_file "/tmp/python-vm-builder.deb" do
    source "python-vm-builder.deb"
  end
  if node[:rightimage][:virtual_environment] == "ec2" 
    remote_file "/tmp/python-vm-builder-ec2.deb" do
      source "python-vm-builder-ec2.deb"
    end 
  end
  ruby_block "install python-vm-builder debs with dependencies" do
    block do
      Chef::Log.info(`dpkg -i /tmp/python-vm-builder.deb`)
      Chef::Log.info(`dpkg -i /tmp/python-vm-builder-ec2.deb`) if node[:rightimage][:virtual_environment] == 'ec2'
      Chef::Log.info(`apt-get -fy install`)
    end
  end
end

# TODO: Need this to be hypervisor unspecific.  debootstrap?
bootstrap_cmd = "/usr/bin/vmbuilder  #{node[:rightimage][:virtual_environment]} ubuntu -o \
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
  code <<-EOH
    set -e
    set -x

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


case "#{node.rightimage.virtual_environment}" in

  "kvm" )
      kvm_image=`basename $(ls -1 /mnt/vmbuilder/tmp*.qcow2)`
      ;;

  "esxi" )
      kvm_image=`basename $(ls -1 /mnt/vmbuilder/tmp*-flat.vmdk)`
      ;;

  "ec2"|* )
      if ( [ "#{node[:rightimage][:release]}" == "lucid" ] || [ "#{node[:rightimage][:release]}" == "maverick" ] ) ; then
        kvm_image=`cat /mnt/vmbuilder/xen.conf  | grep xvda1 | grep -v root  | cut -c 25- | cut -c -9`
      else 
        kvm_image=$image_name
      fi
      ;;
esac


loop_name="loop1"
loop_dev="/dev/$loop_name"
loop_map="/dev/mapper/${loop_name}p1"

base_raw_path="/mnt/vmbuilder/root.img"

# Cleanup loopback stuff
set +e
[ -e $loop_map ] && kpartx -d $loop_dev
losetup -a | grep $loop_name
[ "$?" == "0" ] && losetup -d $loop_dev
set -e

qemu-img convert -O raw /mnt/vmbuilder/$kvm_image $base_raw_path
losetup $loop_dev $base_raw_path

# Setup loopback device
case "#{node.rightimage.virtual_environment}" in 
  "kvm"|"esxi" )
    kpartx -a $loop_dev
    loopback_device=$loop_map
   ;;
  "ec2"|*)
    loopback_device=$loop_dev
   ;;
esac

    guest_root=#{source_image}

    random_dir=/tmp/rightimage-$RANDOM
    mkdir $random_dir
    mount -o loop $loopback_device  $random_dir
    umount $guest_root/proc || true
    rm -rf $guest_root/*
    rsync -a $random_dir/ $guest_root/
    umount $random_dir
    losetup -d $loopback_device
    rm -rf $random_dir
    mkdir -p $guest_root/var/man
    chroot $guest_root chown -R man:root /var/man
EOH
  # TODO: Fix this
  not_if "test -e /mnt/vmbuilder/root.img"
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


if node[:rightimage][:release] == "maverick" || node[:rightimage][:release] == "lucid"
  # Fix apt config so it does not install all recommended packages
  log "Fixing apt.conf APT::Install-Recommends setting prior to installing Java"
  log "Installing Sun Java for Lucid..."

  guest_java_install = "/tmp/java_install"
  host_java_install = "#{source_image}#{guest_java_install}"
  
  bash "install sun java" do
    user "root"
    cwd "/tmp"
    code <<-EOH
    
    cat <<-EOS > #{host_java_install}
#!/bin/bash
set -e
set -x

echo "Setting APT::Install-Recommends to false"
echo "APT::Install-Recommends \"0\";" > /etc/apt/apt.conf

cp /etc/apt/sources.list /etc/apt/sources.java.sav
echo "deb http://archive.canonical.com/ #{node[:rightimage][:release]} partner" >> /etc/apt/sources.list
apt-get update

apt-get -y install debconf-utils
echo 'sun-java6-bin   shared/accepted-sun-dlj-v1-1    boolean true
sun-java6-jdk   shared/accepted-sun-dlj-v1-1    boolean true
sun-java6-jre   shared/accepted-sun-dlj-v1-1    boolean true
sun-java6-jre   sun-java6-jre/stopthread        boolean true
sun-java6-jre   sun-java6-jre/jcepolicy note
sun-java6-bin   shared/present-sun-dlj-v1-1     note
sun-java6-jdk   shared/present-sun-dlj-v1-1     note
sun-java6-jre   shared/present-sun-dlj-v1-1     note
'|debconf-set-selections
apt-get -y install sun-java6-jdk

cat >/etc/profile.d/java.sh <<EOF

JAVA_HOME=/usr/lib/jvm/java-6-sun
export JAVA_HOME

EOF

chmod 775 /etc/profile.d/java.sh

echo "Restore origional repo list"
cp /etc/apt/sources.java.sav /etc/apt/sources.list
apt-get update

EOS

    chmod +x #{host_java_install}
    chroot #{source_image} #{guest_java_install}    
    rm -f #{host_java_install}

    EOH
  end
end

# Modified version of syslog-ng.conf that will properly route recipe output to /var/log/messages
remote_file "#{source_image}/etc/syslog-ng/syslog-ng.conf" do
  source "syslog-ng.conf"
end

# TODO: Add cleanup
bash "cleanup" do
  code <<-EOH
    set -ex
    chroot #{source_image} apt-get update
    chroot #{source_image} apt-get clean
  EOH
end
