class Chef::Node
 include RightScale::RightImage::Helper
end

# Rightlink strips /usr/local/bin out of the default path for, which is where
# Ubuntu installs python and ruby binstubs.  Setting JAVA_HOME to /usr here is
# a bit of a hack, the ec2 tools really only want JAVA_HOME to be set to the grandparent
# directory of the java executable.
set[:rightimage][:script_env] = {
  'PATH' => "/home/ec2/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
  'JAVA_HOME' => "/usr",
  'EC2_HOME' => "/home/ec2"
}

set_unless[:rightimage][:debug] = false
set[:rightimage][:lang] = "en_US.UTF-8"
set_unless[:rightimage][:root_size_gb] = "10"
set[:rightimage][:build_dir] = "/mnt/vmbuilder"
set[:rightimage][:guest_root] = "/mnt/image"
set_unless[:rightimage][:hypervisor] = "xen"
# Don't use cf-mirror because it causes hash sum mismatch errors on Ubuntu
# during an apt-get update using /latest. (w-6201)
set[:rightimage][:mirror] = "mirror.rightscale.com"
set_unless[:rightimage][:rightscale_staging_mirror] = "false"
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
set_unless[:rightimage][:bare_image] = "false"
default[:rightimage][:s3_base_url] =  "http://rightscale-rightimage.s3.amazonaws.com"

case node[:rightimage][:hypervisor]
when "xen" then set[:rightimage][:image_type] = "vhd"
when "esxi" then set[:rightimage][:image_type] = "vmdk"
when "kvm" then set[:rightimage][:image_type] = "qcow2"
when "hyperv" then set[:rightimage][:image_type] = "msvhd"
when "virtualbox" then set[:rightimage][:image_type] = "box"
else raise ArgumentError, "don't know what image format to use for #{node[:rightimage][:hypervisor]}!"
end

set[:rightimage][:host_packages] = []

# set base os packages
case rightimage[:platform]
when "ubuntu"
  rightimage[:host_packages] << " ca-certificates"
  rightimage[:host_packages] << " openjdk-6-jre"
  rightimage[:host_packages] << " openssl"

  if rightimage[:platform_version].to_f >= 10.10
    rightimage[:host_packages] << " devscripts"
  end

  if rightimage[:platform_version].to_f == 10.04
    rightimage[:host_packages] << " python-vm-builder-ec2"
  end

  if rightimage[:platform_version].to_f == 12.04
    rightimage[:host_packages] << " liburi-perl"
  end
when "centos","rhel"
  # For Centos 5, install custom ruby (1.8.7). so keep these in a separate variable 
  # These are the packages available on the rbel upstream mirror
  set[:rightimage][:ruby_packages] = "ruby ruby-devel ruby-irb ruby-libs ruby-rdoc ruby-ri ruby-tcltk"

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
    rightimage[:host_packages] << " #{p}"
  end
when "suse"
  rightimage[:host_packages] << " kiwi"
end

if rightimage[:bare_image] == "true"
  # set base os packages
  guest_packages =
  case rightimage[:platform]
  when "ubuntu" then %w(acpid openssh-clients openssh-server language-selector-common ubuntu-standard)
  when "centos", "rhel" then %w(acpid openssh-server openssl dhclient)
  end
else
  # set base os packages
  guest_packages =
  case rightimage[:platform]
  when "ubuntu" then %w(rightimage-extras)
  when "centos" then %w(rightimage-extras xfsprogs)
  when "rhel" then %w(rightimage-extras)
  end
end

set[:rightimage][:guest_packages] = guest_packages

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

set_unless[:rightimage][:rightlink_repo] = "rightlink-staging"


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
