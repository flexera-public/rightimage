mount_dir = node[:rightimage][:mount_dir]

#install prereq packages
node[:rightimage][:host_packages].split.each { |p| package p} 

#create bootstrap command
case node[:rightimage][:platform]
  when "ubuntu"
    # install specialty kernel for testing
    
    if node[:lsb][:codename] == "maverick" || node[:lsb][:codename] == "lucid"
      # install vmbuilder from deb files
      remote_file "/tmp/python-vm-builder.deb" do
        source "python-vm-builder.deb"
      end
      remote_file "/tmp/python-vm-builder-ec2.deb" do
        source "python-vm-builder-ec2.deb"
      end 
      ruby_block "install python-vm-builder debs with dependencies" do
        block do
          Chef::Log.info(`dpkg -i /tmp/python-vm-builder.deb`)
          Chef::Log.info(`dpkg -i /tmp/python-vm-builder-ec2.deb`)
          Chef::Log.info(`apt-get -fy install`)
        end
      end
    end

    bootstrap_cmd = "/usr/bin/vmbuilder  #{node[:rightimage][:virtual_environment]} ubuntu -o \
        --suite=#{node[:rightimage][:release]} \
        -d #{node[:rightimage][:build_dir]} \
        --rootsize=#{node[:rightimage][:root_size]} \
        --install-mirror=http://mirror.rightscale.com/ubuntu \
        --install-security-mirror=http://mirror.rightscale.com/ubuntu \
        --components=main,restricted,universe,multiverse \
        --lang=#{node[:rightimage][:lang]} "
    if node[:rightimage][:arch] == "i386"
      bootstrap_cmd << " --arch i386"
      bootstrap_cmd << " --addpkg libc6-xen"
    else
      bootstrap_cmd << " --arch amd64"
    end
    node[:rightimage][:guest_packages].split.each { |p| bootstrap_cmd << " --addpkg " + p} 

    Chef::Log.info "vmbuilder bootstrap command is: " + bootstrap_cmd
  else 

    template "/tmp/yum.conf" do
      source "yum.conf.erb"
      backup false
    end
end

log "Configuring Image..."

bash "configure_image"  do
  user "root"
  cwd "/tmp"
  code <<-EOH
    set -e
    set -x

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

    if [ "#{node[:rightimage][:release]}" == "lucid" ] || [ "#{node[:rightimage][:release]}" == "maverick" ] ;then
      image_name=`cat /mnt/vmbuilder/xen.conf  | grep xvda1 | grep -v root  | cut -c 25- | cut -c -9`
    else
      image_name="root.img"
    fi
    random_dir=/tmp/rightimage-$RANDOM
    mkdir $random_dir
    mount -o loop /mnt/vmbuilder/$image_name  $random_dir
    umount #{node[:rightimage][:mount_dir]}/proc || true
    rm -rf #{node[:rightimage][:mount_dir]}
    mkdir -p #{node[:rightimage][:mount_dir]}
    rsync -a $random_dir/ #{node[:rightimage][:mount_dir]}/
    umount $random_dir
    rm -rf  $random_dir
    mkdir -p #{node[:rightimage][:mount_dir]}/var/man
    chroot #{node[:rightimage][:mount_dir]}  chown -R man:root /var/man


EOH
  not_if "test -e /mnt/vmbuilder/root.img"
end


if node[:rightimage][:release] == "maverick"
  template "/mnt/image/boot/grub/menu.lst" do
    source "menu.lst.erb"
  end
end

if node[:rightimage][:release] == "lucid"
  remote_file "/mnt/image/tmp/linux-headers-2.6.32-313_2.6.32-313.25_all.deb" do
    source "linux-headers-2.6.32-313_2.6.32-313.25_all.deb"
  end
  if node[:rightimage][:arch] == "i386"
    remote_file "/mnt/image/tmp/linux-headers-2.6.32-313-ec2_2.6.32-313.25_i386.deb" do
      source "linux-headers-2.6.32-313-ec2_2.6.32-313.25_i386.deb"
    end
    remote_file "/mnt/image/tmp/linux-image-2.6.32-313-ec2_2.6.32-313.25_i386.deb" do
      source "linux-image-2.6.32-313-ec2_2.6.32-313.25_i386.deb"
    end
  else
    remote_file "/mnt/image/tmp/linux-headers-2.6.32-313-ec2_2.6.32-313.25_amd64.deb" do
      source "linux-headers-2.6.32-313-ec2_2.6.32-313.25_amd64.deb"
    end
    remote_file "/mnt/image/tmp/linux-image-2.6.32-313-ec2_2.6.32-313.25_amd64.deb" do
      source "linux-image-2.6.32-313-ec2_2.6.32-313.25_amd64.deb"
    end
  end
  bash "install custom lucid kernel" do
    code <<-EOH
    chroot #{node[:rightimage][:mount_dir]} dpkg -i /tmp/linux-headers*.deb  
    chroot #{node[:rightimage][:mount_dir]} dpkg -i /tmp/linux-image*.deb  
EOH
  end
end

if node[:rightimage][:release] == "lucid" || node[:rightimage][:release] == "maverick"

  # Fix apt config so it does not install all recommended packages
  log "Fixing apt.conf APT::Install-Recommends setting prior to installing Java"
   
  log "Installing Sun Java for Lucid..."

  guest_java_install = "/tmp/java_install"
  host_java_install = "#{mount_dir}#{guest_java_install}"
  
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
    chroot #{mount_dir} #{guest_java_install}    
    rm -f #{host_java_install}

    EOH
  end
end

include_recipe "rightimage::bootstrap_common"

