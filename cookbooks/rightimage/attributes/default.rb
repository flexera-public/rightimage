## when pasting a key into a json file, make sure to use the following command: 
## sed -e :a -e '$!N;s/\n/\\n/;ta' /path/to/key
## this seems not to work on os x
class Chef::Node
 include RightScale::RightImage::Helper
end

set_unless[:rightimage][:debug] = false
set[:rightimage][:lang] = "en_US.UTF-8"
set_unless[:rightimage][:root_size_gb] = "10"
set[:rightimage][:build_dir] = "/mnt/vmbuilder"
set[:rightimage][:guest_root] = "/mnt/image"
set_unless[:rightimage][:hypervisor] = "xen"
set[:rightimage][:mirror] = "cf-mirror.rightscale.com"
set_unless[:rightimage][:cloud] = "ec2"
set[:rightimage][:root_mount][:label_dev] = "ROOT"
set[:rightimage][:root_mount][:dev] = "LABEL=#{rightimage[:root_mount][:label_dev]}"
set_unless[:rightimage][:image_source_bucket] = "rightscale-us-west-2"

if rightimage[:platform] == "ubuntu"
  set[:rightimage][:mirror_date] = "#{timestamp[0..3]}/#{timestamp[4..5]}/#{timestamp[6..7]}"
  set[:rightimage][:mirror_url] = "http://#{node[:rightimage][:mirror]}/ubuntu_daily/#{node[:rightimage][:mirror_date]}"
else
  set[:rightimage][:mirror_date] = timestamp[0..7]
end


case node[:rightimage][:hypervisor]
when "xen" then set[:rightimage][:image_type] = "vhd"
when "esxi" then set[:rightimage][:image_type] = "vmdk"
when "kvm" then set[:rightimage][:image_type] = "qcow2"
else raise ArgumentError, "don't know what image format to use for #{node[:rightimage][:hypervisor]}!"
end

# set base os packages
case rightimage[:platform]
when "ubuntu"   
  set[:rightimage][:guest_packages] = "ubuntu-standard binutils ruby1.8 curl unzip openssh-server ruby1.8-dev build-essential autoconf automake libtool logrotate rsync openssl openssh-server ca-certificates libopenssl-ruby1.8 subversion vim libreadline-ruby1.8 irb rdoc1.8 git-core liberror-perl libdigest-sha1-perl dmsetup emacs rake screen mailutils nscd bison ncurses-dev zlib1g-dev libreadline5-dev readline-common libxslt1-dev sqlite3 libxml2 libxml2-dev flex libshadow-ruby1.8 postfix sysstat iptraf syslog-ng libarchive-dev tmux"

  set[:rightimage][:host_packages] = "openjdk-6-jre openssl ca-certificates"
when "centos","rhel"
  set[:rightimage][:guest_packages] = "wget mlocate nano logrotate ruby ruby-devel ruby-docs ruby-irb ruby-libs ruby-mode ruby-rdoc ruby-ri ruby-tcltk postfix openssl openssh openssh-askpass openssh-clients openssh-server curl gcc* zip unzip bison flex compat-libstdc++-296 cvs subversion autoconf automake libtool compat-gcc-34-g77 mutt sysstat rpm-build fping vim-common vim-enhanced rrdtool-1.2.27 rrdtool-devel-1.2.27 rrdtool-doc-1.2.27 rrdtool-perl-1.2.27 rrdtool-python-1.2.27 rrdtool-ruby-1.2.27 rrdtool-tcl-1.2.27 pkgconfig lynx screen yum-utils bwm-ng createrepo redhat-rpm-config redhat-lsb git nscd xfsprogs swig libarchive-devel tmux libxml2 libxml2-devel libxslt libxslt-devel dhclient sudo telnet"

  set[:rightimage][:host_packages] = "swig"
when "suse"
  set[:rightimage][:guest_packages] = "gcc"

  set[:rightimage][:host_packages] = "kiwi"
end


# set addtional release specific packages
case node[:rightimage][:platform_version]
  when "8.04"
    set[:rightimage][:guest_packages] = rightimage[:guest_packages] + " sysv-rc-conf debian-helper-scripts"
    rightimage[:host_packages] << " ubuntu-vm-builder"
  when "9.10"
    rightimage[:host_packages] << " python-vm-builder-ec2"
  when "10.04"
    if rightimage[:cloud] == "ec2"
      rightimage[:host_packages] << " python-vm-builder-ec2 devscripts"
    else
      rightimage[:host_packages] << " devscripts"
    end
  when "10.10"
    rightimage[:host_packages] << " devscripts"
end if rightimage[:platform] == "ubuntu" 

# set cloud stuff
# TBD Refactor this block to use consistent naming, figure out how to move logic into cloud providers
case rightimage[:cloud]
  when "ec2", "eucalyptus" 
    set[:rightimage][:root_mount][:dump] = "0" 
    set[:rightimage][:root_mount][:fsck] = "0" 
    set[:rightimage][:fstab][:ephemeral] = true
    # Might have to double check don't know if maverick should use kernel linux-image-ec2 or not
    set[:rightimage][:swap_mount] = "/dev/sda3" unless rightimage[:arch]  == "x86_64"
    set[:rightimage][:ephemeral_mount] = "/dev/sdb" 
    case rightimage[:platform]
      when "ubuntu" 
        set[:rightimage][:fstab][:ephemeral_mount_opts] = "defaults,nobootwait"
        set[:rightimage][:fstab][:swap] = "defaults,nobootwait"
        if rightimage[:platform_version].to_f >= 10.10
          set[:rightimage][:ephemeral_mount] = "/dev/xvdb"
          set[:rightimage][:swap_mount] = "/dev/xvda3" unless rightimage[:arch]  == "x86_64"
        end
      when "centos", "rhel"
        set[:rightimage][:fstab][:ephemeral_mount_opts] = "defaults"
        set[:rightimage][:fstab][:swap] = "defaults"

        # CentOS 6.1 and above start SCSI device naming from e
        if rightimage[:platform_version].to_f >= 6.1
          set[:rightimage][:ephemeral_mount] = "/dev/xvdf"
          set[:rightimage][:swap_mount] = "/dev/xvde3"  unless rightimage[:arch]  == "x86_64"
        end
    end
  when "cloudstack", "openstack"
    case rightimage[:hypervisor]
    when "xen"
      set[:rightimage][:fstab][:ephemeral] = false
      set[:rightimage][:ephemeral_mount] = nil
      set[:rightimage][:fstab][:ephemeral_mount_opts] = nil
      set[:rightimage][:grub][:root_device] = "/dev/xvda"
      set[:rightimage][:root_mount][:dump] = "1" 
      set[:rightimage][:root_mount][:fsck] = "1" 
    when "kvm"
      set[:rightimage][:fstab][:ephemeral] = false
      set[:rightimage][:ephemeral_mount] = "/dev/vdb"
      set[:rightimage][:fstab][:ephemeral_mount_opts] = "defaults"
      set[:rightimage][:grub][:root_device] = "/dev/vda"
      set[:rightimage][:root_mount][:dump] = "1" 
      set[:rightimage][:root_mount][:fsck] = "1" 
    when "esxi"
      set[:rightimage][:ephemeral_mount] = nil
      set[:rightimage][:fstab][:ephemeral_mount_opts] = nil
      set[:rightimage][:fstab][:ephemeral] = false
      set[:rightimage][:grub][:root_device] = "/dev/sda"
      set[:rightimage][:root_mount][:dump] = "1" 
      set[:rightimage][:root_mount][:fsck] = "1" 
    else
      raise "ERROR: unsupported hypervisor #{node[:rightimage][:hypervisor]} for cloudstack"
    end
end

# set rightscale stuff
set_unless[:rightimage][:rightlink_version] = ""

# generate command to install getsshkey init script 
case rightimage[:platform]
  when "ubuntu" 
    set[:rightimage][:getsshkey_cmd] = "chroot $GUEST_ROOT update-rc.d getsshkey start 20 2 3 4 5 . stop 1 0 1 6 ."
    set[:rightimage][:mirror_file] = "sources.list.erb"
    set[:rightimage][:mirror_file_path] = "/etc/apt/sources.list"
  when "centos", "rhel"
    set[:rightimage][:getsshkey_cmd] = "chroot $GUEST_ROOT chkconfig --add getsshkey && \
               chroot $GUEST_ROOT chkconfig --level 4 getsshkey on"
    set[:rightimage][:mirror_file] = "CentOS.repo.erb"
    set[:rightimage][:mirror_file_path] = "/etc/yum.repos.d/CentOS.repo"

end
