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
set[:rightimage][:fstab][:ephemeral][:mount] = "/mnt/ephemeral"
set[:rightimage][:fstab][:ephemeral][:options] = "defaults"
set[:rightimage][:grub][:timeout] = "5"
set[:rightimage][:grub][:kernel][:options] = "consoleblank=0"
set[:rightimage][:root_mount][:label_dev] = "ROOT"
set[:rightimage][:root_mount][:dev] = "LABEL=#{rightimage[:root_mount][:label_dev]}"
set[:rightimage][:root_mount][:options] = "defaults"
set_unless[:rightimage][:image_source_bucket] = "rightscale-us-west-2"
set_unless[:rightimage][:base_image_bucket] = "rightscale-rightimage-base-dev"
set_unless[:rightimage][:platform] = guest_platform
set_unless[:rightimage][:platform_version] = guest_platform_version
set_unless[:rightimage][:arch] = guest_arch


case node[:rightimage][:hypervisor]
when "xen" then set[:rightimage][:image_type] = "vhd"
when "esxi" then set[:rightimage][:image_type] = "vmdk"
when "kvm" then set[:rightimage][:image_type] = "qcow2"
when "hyperv" then set[:rightimage][:image_type] = "msvhd"
when "virtualbox" then set[:rightimage][:image_type] = "box"
else raise ArgumentError, "don't know what image format to use for #{node[:rightimage][:hypervisor]}!"
end

set[:rightimage][:guest_packages] = []
rightimage[:guest_packages] << " acpid"
rightimage[:guest_packages] << " autoconf"
rightimage[:guest_packages] << " automake"
rightimage[:guest_packages] << " bison"
rightimage[:guest_packages] << " curl" # RightLink
rightimage[:guest_packages] << " flex"
rightimage[:guest_packages] << " libtool"
rightimage[:guest_packages] << " libxml2"
rightimage[:guest_packages] << " logrotate"
rightimage[:guest_packages] << " nscd"
rightimage[:guest_packages] << " ntp" # RightLink requires local time to be accurate (w-5025)
rightimage[:guest_packages] << " openssh-server"
rightimage[:guest_packages] << " openssl"
rightimage[:guest_packages] << " screen"
rightimage[:guest_packages] << " subversion"
rightimage[:guest_packages] << " sysstat"
rightimage[:guest_packages] << " tmux"
rightimage[:guest_packages] << " unzip"

set[:rightimage][:host_packages] = []

# set base os packages
case rightimage[:platform]
when "ubuntu"
  rightimage[:guest_packages] << " binutils"
  rightimage[:guest_packages] << " build-essential"
  rightimage[:guest_packages] << " ca-certificates"
  rightimage[:guest_packages] << " dhcp3-client"
  rightimage[:guest_packages] << " dmsetup"
  rightimage[:guest_packages] << " emacs"
  rightimage[:guest_packages] << " git-core" # RightLink
  rightimage[:guest_packages] << " iptraf"
  rightimage[:guest_packages] << " irb"
  rightimage[:guest_packages] << " libarchive-dev" # RightLink
  rightimage[:guest_packages] << " liberror-perl"
  rightimage[:guest_packages] << " libopenssl-ruby1.8"
  rightimage[:guest_packages] << " libreadline-ruby1.8"
  rightimage[:guest_packages] << " libshadow-ruby1.8"
  rightimage[:guest_packages] << " libxml2-dev" # RightLink
  rightimage[:guest_packages] << " libxslt1-dev" # RightLink
  rightimage[:guest_packages] << " mailutils"
  rightimage[:guest_packages] << " ncurses-dev"
  rightimage[:guest_packages] << " postfix"
  rightimage[:guest_packages] << " rake"
  rightimage[:guest_packages] << " rdoc1.8"
  rightimage[:guest_packages] << " readline-common"
  rightimage[:guest_packages] << " rsync"
  rightimage[:guest_packages] << " ruby1.8"
  rightimage[:guest_packages] << " ruby1.8-dev"
  rightimage[:guest_packages] << " sqlite3"
  rightimage[:guest_packages] << " ubuntu-standard"
  rightimage[:guest_packages] << " vim"
  rightimage[:guest_packages] << " zlib1g-dev"

  case rightimage[:platform_version]
  when "8.04"
  when "10.04"
  when "10.10"
    rightimage[:guest_packages] << " libdigest-sha1-perl"
    rightimage[:guest_packages] << " libreadline5-dev"
    rightimage[:guest_packages] << " linux-headers-virtual"
  else
    rightimage[:guest_packages] << " libreadline-gplv2-dev"
  end

  rightimage[:host_packages] << " ca-certificates"
  rightimage[:host_packages] << " openjdk-6-jre"
  rightimage[:host_packages] << " openssl"

  case rightimage[:platform_version]
  when "8.04"
    rightimage[:guest_packages] << " debian-helper-scripts"
    rightimage[:guest_packages] << " sysv-rc-conf"
    rightimage[:host_packages] << " ubuntu-vm-builder"
  when "9.10"
    rightimage[:host_packages] << " python-vm-builder-ec2"
  when "10.04"
    if rightimage[:cloud] == "ec2"
      rightimage[:host_packages] << " devscripts"
      rightimage[:host_packages] << " python-vm-builder-ec2"
    else
      rightimage[:host_packages] << " devscripts"
    end
  when "10.10"
    rightimage[:guest_packages] << " linux-image-virtual"
    rightimage[:host_packages] << " devscripts"
  when "12.04"
    rightimage[:guest_packages] << " linux-image-virtual"
    rightimage[:host_packages] << " devscripts"
    rightimage[:host_packages] << " liburi-perl"
    # extra-virtual contains the UDF kernel module (DVD format), needed for azure
    rightimage[:guest_packages] << " linux-image-extra-virtual"
  else
     rightimage[:host_packages] << " devscripts"
  end
when "centos","rhel"
  rightimage[:guest_packages] << " bwm-ng"
  rightimage[:guest_packages] << " compat-gcc-34-g77"
  rightimage[:guest_packages] << " compat-libstdc++-296"
  rightimage[:guest_packages] << " createrepo"
  rightimage[:guest_packages] << " cvs"
  rightimage[:guest_packages] << " dhclient"
  rightimage[:guest_packages] << " fping"
  rightimage[:guest_packages] << " gcc*"
  rightimage[:guest_packages] << " git" # RightLink
  rightimage[:guest_packages] << " libarchive-devel" # RightLink
  rightimage[:guest_packages] << " libxml2-devel" # RightLink
  rightimage[:guest_packages] << " libxslt"
  rightimage[:guest_packages] << " libxslt-devel" # RightLink
  rightimage[:guest_packages] << " lynx"
  rightimage[:guest_packages] << " mlocate"
  rightimage[:guest_packages] << " mutt"
  rightimage[:guest_packages] << " nano"
  rightimage[:guest_packages] << " openssh-askpass"
  rightimage[:guest_packages] << " openssh-clients"
  rightimage[:guest_packages] << " pkgconfig"
  rightimage[:guest_packages] << " redhat-lsb"
  rightimage[:guest_packages] << " redhat-rpm-config"
  rightimage[:guest_packages] << " rpm-build"
  rightimage[:guest_packages] << " ruby-docs"
  rightimage[:guest_packages] << " ruby-mode"
  rightimage[:guest_packages] << " sudo"
  rightimage[:guest_packages] << " swig"
  rightimage[:guest_packages] << " telnet"
  rightimage[:guest_packages] << " vim-common"
  rightimage[:guest_packages] << " vim-enhanced"
  rightimage[:guest_packages] << " wget"
  rightimage[:guest_packages] << " xfsprogs"
  rightimage[:guest_packages] << " yum-utils"

  # For Centos 5, install custom ruby (1.8.7). so keep these in a separate variable 
  # These are the packages available on the rbel upstream mirror
  set[:rightimage][:ruby_packages] = "ruby ruby-devel ruby-irb ruby-libs ruby-rdoc ruby-ri ruby-tcltk"
  if el6?
    rightimage[:guest_packages] << " " << rightimage[:ruby_packages]
  end

  rightimage[:host_packages] << " swig"

  extra_el_packages =
    if el6?
      " compat-db43" +
      " compat-expat1" +
      " openssl098e"
    else
      " db4" +
      " expat" +
      " openssl"
    end

  extra_el_packages.split.each do |p|
    rightimage[:guest_packages] << " #{p}"
    rightimage[:host_packages] << " #{p}"
  end
when "suse"
  rightimage[:guest_packages] << " gcc"

  rightimage[:host_packages] << " kiwi"
end

# set cloud stuff
# TBD Refactor this block to use consistent naming, figure out how to move logic into cloud providers
case rightimage[:cloud]
  when "ec2", "eucalyptus" 
    set[:rightimage][:root_mount][:dump] = "0" 
    set[:rightimage][:root_mount][:fsck] = "0" 
    # Might have to double check don't know if maverick should use kernel linux-image-ec2 or not
    set[:rightimage][:swap_mount] = "/dev/sda3" unless rightimage[:arch] == "x86_64"
    set[:rightimage][:fstab][:ephemeral][:dev] = "/dev/sdb"
    set[:rightimage][:grub][:timeout] = "0"

    case rightimage[:platform]
      when "ubuntu" 
        set[:rightimage][:fstab][:ephemeral][:options] = "defaults,nobootwait"
        set[:rightimage][:fstab][:swap] = "defaults,nobootwait"
        if rightimage[:platform_version].to_f >= 10.10
          set[:rightimage][:fstab][:ephemeral][:dev] = "/dev/xvdb"
          set[:rightimage][:swap_mount] = "/dev/xvda3" unless rightimage[:arch]  == "x86_64"
        end
      when "centos", "rhel"
        set[:rightimage][:fstab][:ephemeral][:options] = "defaults"
        set[:rightimage][:fstab][:swap] = "defaults"

        # CentOS 6.1-6.2 start SCSI device naming from e
        if rightimage[:platform_version].to_i == 6
          if rightimage[:platform_version].to_f.between?(6.1,6.2)
            set[:rightimage][:fstab][:ephemeral][:dev] = "/dev/xvdf"
            set[:rightimage][:swap_mount] = "/dev/xvde3"  unless rightimage[:arch]  == "x86_64"
          else
            set[:rightimage][:fstab][:ephemeral][:dev] = "/dev/xvdb"
            set[:rightimage][:swap_mount] = "/dev/xvda3"  unless rightimage[:arch]  == "x86_64"
          end
        end
    end
  when "azure"
    set[:rightimage][:grub][:timeout] = "0"
    # Ensure that all SCSI devices mounted in your kernel include an I/O timeout of 300 seconds or more. (w-5331)
    set[:rightimage][:grub][:kernel][:options] << " rootdelay=300 console=ttyS0"

    case rightimage[:platform]
    when "centos"
      set[:rightimage][:grub][:kernel][:options] << " numa=off"
    end
  when "vagrant"
# stuff here
  else 
    case rightimage[:hypervisor]
    when "xen"
      set[:rightimage][:fstab][:ephemeral][:dev] = nil
      set[:rightimage][:fstab][:ephemeral][:options] = nil
      set[:rightimage][:grub][:root_device] = "/dev/xvda"
      set[:rightimage][:root_mount][:dump] = "1" 
      set[:rightimage][:root_mount][:fsck] = "1" 
    when "kvm"
      set[:rightimage][:fstab][:ephemeral][:dev] = nil
      set[:rightimage][:fstab][:ephemeral][:options] = nil
      set[:rightimage][:grub][:root_device] = "/dev/vda"
      set[:rightimage][:root_mount][:dump] = "1" 
      set[:rightimage][:root_mount][:fsck] = "1" 
    when "esxi", "hyperv"
      set[:rightimage][:fstab][:ephemeral][:dev] = nil
      set[:rightimage][:fstab][:ephemeral][:options] = nil
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
  when "centos", "rhel"
    set[:rightimage][:getsshkey_cmd] = "chroot $GUEST_ROOT chkconfig --add getsshkey && \
               chroot $GUEST_ROOT chkconfig --level 4 getsshkey on"
end

# http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=637234#40
set[:rightimage][:root_mount][:options] = "errors=remount-ro,barrier=0" if rightimage[:platform] == "ubuntu" && rightimage[:platform_version].to_f >= 12.04 && rightimage[:hypervisor] == "xen"

set[:rightimage][:grub][:kernel][:options] << " console=hvc0" if rightimage[:hypervisor] == "xen"

# Start device naming from xvda instead of xvde (w-4893)
# https://bugzilla.redhat.com/show_bug.cgi?id=729586
set[:rightimage][:grub][:kernel][:options] << " xen_blkfront.sda_is_xvda=1" if rightimage[:platform] == "centos" && rightimage[:platform_version].to_f >= 6.3

# Specify if running in Xen domU or have grub detect automatically
set[:rightimage][:grub][:indomU] = node[:rightimage][:hypervisor] == "xen" ? "true":"detect"

# Set path to SFTP
set[:rightimage][:sshd][:sftp_path] = node[:rightimage][:platform] == "ubuntu" ? "/usr/lib/openssh/sftp-server" : "/usr/libexec/openssh/sftp-server"
