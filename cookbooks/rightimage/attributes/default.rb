## when pasting a key into a json file, make sure to use the following command: 
## sed -e :a -e '$!N;s/\n/\\n/;ta' /path/to/key
## this seems not to work on os x

UNKNOWN = :unknown.to_s

set_unless[:rightimage][:debug] = false
set[:rightimage][:lang] = "en_US.UTF-8"
set_unless[:rightimage][:root_size_gb] = "10"
set[:rightimage][:build_dir] = "/mnt/vmbuilder"
set[:rightimage][:mount_dir] = "/mnt/image"
set_unless[:rightimage][:virtual_environment] = "xen"
set[:rightimage][:install_mirror] = "mirror.rightscale.com"
set_unless[:rightimage][:sandbox_repo_tag] = "rightlink_package_#{rightimage[:rightlink_version]}"

lineage_split = node[:block_device][:lineage].split("_")
set[:rightimage][:platform] = lineage_split[0]
set[:rightimage][:release] = lineage_split[1]

if lineage_split[2] == "x64"
  set[:rightimage][:arch] = "x86_64"
else
  set[:rightimage][:arch] = lineage_split[2]
end

set[:rightimage][:timestamp] = lineage_split[3]
set[:rightimage][:build] = lineage_split[4] if lineage_split[4]
set[:rightimage][:install_mirror_date] = node[:rightimage][:timestamp][0..7]

if rightimage[:platform] == "ubuntu"
# for using apt-proxy
  set[:rightimage][:install_mirror] = "localhost:9999"
end

# set base os packages
case rightimage[:platform]
when "ubuntu"   
  set[:rightimage][:guest_packages] = "ubuntu-standard binutils ruby1.8 curl unzip openssh-server ruby1.8-dev build-essential autoconf automake libtool logrotate rsync openssl openssh-server ca-certificates libopenssl-ruby1.8 subversion vim libreadline-ruby1.8 irb rdoc1.8 git-core liberror-perl libdigest-sha1-perl dmsetup emacs rake screen mailutils nscd bison ncurses-dev zlib1g-dev libreadline5-dev readline-common libxslt1-dev sqlite3 libxml2 flex libshadow-ruby1.8 postfix sysstat iptraf syslog-ng libarchive-dev"

  node[:rightimage][:guest_packages] << " cloud-init" if node[:rightimage][:virtual_environment] == "ec2"
  set[:rightimage][:host_packages] = "openjdk-6-jre openssl ca-certificates"

  case node[:lsb][:codename]
    when "maverick"
      rightimage[:host_packages] << " apt-cacher"
    else
      rightimage[:host_packages] << " apt-proxy"
  end

  set[:rightimage][:package_type] = "deb"
  rightimage[:guest_packages] << " euca2ools" if rightimage[:cloud] == "euca"

when "centos" 
  set[:rightimage][:guest_packages] = "wget mlocate nano logrotate ruby ruby-devel ruby-docs ruby-irb ruby-libs ruby-mode ruby-rdoc ruby-ri ruby-tcltk postfix openssl openssh openssh-askpass openssh-clients openssh-server curl gcc* zip unzip bison flex compat-libstdc++-296 cvs subversion autoconf automake libtool compat-gcc-34-g77 mutt sysstat rpm-build fping vim-common vim-enhanced rrdtool-1.2.27 rrdtool-devel-1.2.27 rrdtool-doc-1.2.27 rrdtool-perl-1.2.27 rrdtool-python-1.2.27 rrdtool-ruby-1.2.27 rrdtool-tcl-1.2.27 pkgconfig lynx screen yum-utils bwm-ng createrepo redhat-rpm-config redhat-lsb git nscd xfsprogs swig libarchive-devel"

  rightimage[:guest_packages] << " iscsi-initiator-utils" if rightimage[:cloud] == "vmops" 

  set[:rightimage][:host_packages] = "swig"
  set[:rightimage][:package_type] = "rpm"
when "suse"
  set[:rightimage][:guest_packages] = "gcc"

  set[:rightimage][:host_packages] = "kiwi"
end

# set addtional release specific packages
case rightimage[:release]
  when "hardy"
    set[:rightimage][:guest_packages] = rightimage[:guest_packages] + " sysv-rc-conf debian-helper-scripts"
    rightimage[:host_packages] << " ubuntu-vm-builder"
  when "karmic"
    rightimage[:guest_packages] << " linux-image-ec2"
    #set[:rightimage][:guest_packages] = rightimage[:guest_packages] + " linux-image-ec2"
    rightimage[:host_packages] << " python-vm-builder-ec2"
  when "lucid"
    if rightimage[:cloud] == "ec2"
      #set[:rightimage][:guest_packages] = rightimage[:guest_packages] + " linux-image-2.6.32-309-ec2 linux-image-2.6.32-308-ec2 linux-image-2.6.32-305-ec2" 
      rightimage[:host_packages] << " python-vm-builder-ec2 devscripts"
      #set[:rightimage][:guest_packages] = rightimage[:guest_packages] + " linux-image-virtual-lts-backport-maverick linux-headers-virtual-lts-backport-maverick grub-legacy-ec2" 
    else
      #set[:rightimage][:guest_packages] = rightimage[:guest_packages] + " linux-image-virtual-lts-backport-maverick linux-headers-virtual-lts-backport-maverick grub-legacy-ec2" 
      rightimage[:host_packages] << " devscripts"
    end
  when "maverick"
    rightimage[:host_packages] << " devscripts"
    set[:rightimage][:guest_packages] = rightimage[:guest_packages] + " linux-image-virtual grub-legacy-ec2"
end if rightimage[:platform] == "ubuntu" 

# set cloud stuff
case rightimage[:cloud]
  when "ec2", "euca" 
    set[:rightimage][:root_mount][:dev] = "/dev/sda1"
    set[:rightimage][:root_mount][:dump] = "0" 
    set[:rightimage][:root_mount][:fsck] = "0" 
    set[:rightimage][:fstab][:ephemeral] = true
    set[:rightimage][:ephemeral_mount] = "/dev/sdb" 
    set[:rightimage][:swap_mount] = "/dev/sda3"  unless rightimage[:arch]  == "x86_64"
    case rightimage[:platform]
      when "ubuntu" 
        set[:rightimage][:fstab][:ephemeral_mount_opts] = "defaults,nobootwait"
        set[:rightimage][:fstab][:swap] = "defaults,nobootwait"
      when "centos"
        set[:rightimage][:fstab][:ephemeral_mount_opts] = "defaults"
        set[:rightimage][:fstab][:swap] = "defaults"
    end
  when "vmops", "openstack"
    rightimage[:host_packages] << " python26-distribute python26-devel python26-libs" if rightimage[:cloud] == "openstack"

    case rightimage[:virtual_environment]
    when "xen"
      set[:rightimage][:fstab][:ephemeral_mount_opts] = "defaults"
      set[:rightimage][:fstab][:ephemeral] = false
      set[:rightimage][:root_mount][:dev] = "/dev/xvda"
      set[:rightimage][:root_mount][:dump] = "1" 
      set[:rightimage][:root_mount][:fsck] = "1" 
      set[:rightimage][:ephemeral_mount] = nil
      set[:rightimage][:fstab][:ephemeral_mount_opts] = nil
    when "kvm"
      rightimage[:host_packages] << " qemu grub"
      rightimage[:guest_packages] << " grub"
      set[:rightimage][:fstab][:ephemeral] = false
      set[:rightimage][:ephemeral_mount] = "/dev/vdb"
      set[:rightimage][:fstab][:ephemeral_mount_opts] = "defaults"
      set[:rightimage][:grub][:root_device] = "/dev/vda"
      set[:rightimage][:root_mount][:dev] = "/dev/vda1"
      set[:rightimage][:root_mount][:dump] = "1" 
      set[:rightimage][:root_mount][:fsck] = "1" 
    when "esxi"
      rightimage[:host_packages] << " qemu grub"
      rightimage[:guest_packages] << " grub"
      set[:rightimage][:ephemeral_mount] = nil
      set[:rightimage][:fstab][:ephemeral_mount_opts] = nil
      set[:rightimage][:fstab][:ephemeral] = false
      set[:rightimage][:grub][:root_device] = "/dev/sda"
      set[:rightimage][:root_mount][:uuid] = `uuidgen`.strip
      set[:rightimage][:root_mount][:dev] = "UUID=#{rightimage[:root_mount][:uuid]}"
      set[:rightimage][:root_mount][:dump] = "1" 
      set[:rightimage][:root_mount][:fsck] = "1" 
    else
      raise "ERROR: unsupported virtual_environment #{node[:rightimage][:virtual_environment]} for cloudstack"
    end
end


# set rightscale stuff
set_unless[:rightimage][:rightlink_version] = ""
set_unless[:rightimage][:aws_access_key_id] = nil
set_unless[:rightimage][:aws_secret_access_key] = nil

# generate command to install getsshkey init script 
case rightimage[:platform]
  when "ubuntu" 
    set[:rightimage][:getsshkey_cmd] = "chroot $GUEST_ROOT update-rc.d getsshkey start 20 2 3 4 5 . stop 1 0 1 6 ."
    set[:rightimage][:mirror_file] = "sources.list.erb"
    set[:rightimage][:mirror_file_path] = "/etc/apt/sources.list"
  when "centos"
    set[:rightimage][:getsshkey_cmd] = "chroot $GUEST_ROOT chkconfig --add getsshkey && \
               chroot $GUEST_ROOT chkconfig --level 4 getsshkey on"
    set[:rightimage][:mirror_file] = "CentOS.repo.erb"
    set[:rightimage][:mirror_file_path] = "/etc/yum.repos.d/CentOS.repo"
  when UNKNOWN

end

# set default mirrors and EC2 endpoint
case rightimage[:region]
  when "us-east"
    set[:rightimage][:mirror] = "http://ec2-us-east-mirror.rightscale.com"
    set[:rightimage][:ec2_endpoint] = "https://ec2.us-east-1.amazonaws.com"
  when "us-west"
    set[:rightimage][:mirror] = "http://ec2-us-west-mirror.rightscale.com"
    set[:rightimage][:ec2_endpoint] = "https://ec2.us-west-1.amazonaws.com"
  when "eu-west"
    set[:rightimage][:mirror] = "http://ec2-eu-west-mirror.rightscale.com"
    set[:rightimage][:ec2_endpoint] = "https://ec2.eu-west-1.amazonaws.com"
  when "ap-southeast"
    set[:rightimage][:mirror] = "http://ec2-ap-southeast-mirror.rightscale.com"
    set[:rightimage][:ec2_endpoint] = "https://ec2.ap-southeast-1.amazonaws.com"
  when "ap-northeast"
    set[:rightimage][:mirror] = "http://ec2-ap-northeast-mirror.rightscale.com"
    set[:rightimage][:ec2_endpoint] = "https://ec2.ap-northeast-1.amazonaws.com"
  else
    set[:rightimage][:mirror] = "http://mirror.rightscale.com"
    set[:rightimage][:ec2_endpoint] = "https://ec2.us-east-1.amazonaws.com"
end #if rightimage[:cloud] == "ec2" 

# if ubuntu then figure out the numbered name
case rightimage[:release]
  when "hardy" 
    set[:rightimage][:release_number] = "8.04"
  when "intrepid" 
    set[:rightimage][:release_number] = "8.10"
  when "jaunty" 
    set[:rightimage][:release_number] = "9.04"
  when "karmic" 
    set[:rightimage][:release_number] = "9.10"
  when "lucid" 
    set[:rightimage][:release_number] = "10.04"
  when "maverick" 
    set[:rightimage][:release_number] = "10.10" 
  else 
    set[:rightimage][:release_number] = rightimage[:release]
end

# Select kernel to use based on cloud
#case rightimage[:cloud]
#when "vmops", "euca", "openstack"
case rightimage[:release]
when "5.2" 
  set[:rightimage][:kernel_id] = "2.6.18-92.1.22.el5.centos.plus"
  rightimage[:kernel_id] << "xen" if rightimage[:virtual_environment] == "xen"
when "5.4" 
  set[:rightimage][:kernel_id] = "2.6.18-164.15.1.el5.centos.plus"
  rightimage[:kernel_id] << "xen" if rightimage[:virtual_environment] == "xen"
when "5.6"
  set[:rightimage][:kernel_id] = "2.6.18-238.19.1.el5.centos.plus"
  rightimage[:kernel_id] << "xen" if rightimage[:virtual_environment] == "xen"
when "lucid"
  set[:rightimage][:kernel_id] = "2.6.32-31-server"
  rightimage[:kernel_id] << "kvm" if rightimage[:virtual_environment] == "kvm"
  #rightimage[:kernel_id] << "esxi" if rightimage[:virtual_environment] == "esxi"
end

case rightimage[:cloud]
when "ec2"
  # Using pvgrub kernels
  case rightimage[:region]
  when "us-east"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-805ea7e9"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-825ea7eb"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "us-west"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-83396bc6"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-8d396bc8"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "eu-west" 
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-64695810"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-62695816"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "ap-southeast"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-a4225af6"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-aa225af8"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "ap-northeast"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-ec5df7ed"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-ee5df7ef"
      set[:rightimage][:ramdisk_id] = nil
    end
  end
end # case rightimage[:cloud]
