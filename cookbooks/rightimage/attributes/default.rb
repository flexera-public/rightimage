class Chef::Node
 include RightScale::RightImage::Helper
end

set_unless[:rightimage][:debug] = false
set[:rightimage][:lang] = "en_US.UTF-8"
set_unless[:rightimage][:root_size_gb] = "10"
set[:rightimage][:guest_root] = "/mnt/image"
set_unless[:rightimage][:hypervisor] = "xen"
# Don't use cf-mirror because it causes hash sum mismatch errors on Ubuntu
# during an apt-get update using /latest. (w-6201)
set[:rightimage][:mirror] = "mirror.rightscale.com"
set_unless[:rightimage][:rightscale_staging_mirror] = "false"
set_unless[:rightimage][:cloud] = "ec2"
set[:rightimage][:root_mount][:label_dev] = "ROOT"
set[:rightimage][:root_mount][:dev] = "LABEL=#{rightimage[:root_mount][:label_dev]}"
set[:rightimage][:root_mount][:options] = "defaults"
set_unless[:rightimage][:virtualization] = "pvm"
set_unless[:rightimage][:base_image_bucket] = "rightscale-rightimage-base-dev"
set_unless[:rightimage][:platform] = guest_platform
set_unless[:rightimage][:platform_version] = guest_platform_version
set_unless[:rightimage][:arch] = guest_arch

default[:rightimage][:s3_base_url] =  "http://rightscale-rightimage.s3.amazonaws.com"


# Rightlink strips /usr/local/bin out of the default path for, which is where
# Ubuntu installs python and ruby binstubs.  Setting JAVA_HOME to /usr here is
# a bit of a hack, the ec2 tools really only want JAVA_HOME to be set to the grandparent
# directory of the java executable.
set[:rightimage][:script_env] = {
  'PATH' => "/home/ec2/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
  'JAVA_HOME' => "/usr",
  'EC2_HOME' => "/home/ec2",
  'PLATFORM' => node[:rightimage][:platform],
  'PLATFORM_VERSION' => node[:rightimage][:platform_version],
  'BASE_URL' => node[:rightimage][:s3_base_url]
}




case node[:rightimage][:hypervisor]
when "xen" then set[:rightimage][:image_type] = "vhd"
when "esxi" then set[:rightimage][:image_type] = "vmdk"
when "kvm" then set[:rightimage][:image_type] = "qcow2"
when "hyperv" then set[:rightimage][:image_type] = "msvhd"
when "virtualbox" then set[:rightimage][:image_type] = "box"
else raise ArgumentError, "don't know what image format to use for #{node[:rightimage][:hypervisor]}!"
end

node.set[:rightimage][:host_packages] = []

# set base os packages
case rightimage[:platform]
when "ubuntu"
  node.set[:rightimage][:host_packages] << " ca-certificates"
  node.set[:rightimage][:host_packages] << " openjdk-6-jre"
  node.set[:rightimage][:host_packages] << " openssl"

  if rightimage[:platform_version].to_f >= 10.10
    node.set[:rightimage][:host_packages] << " devscripts"
  end

  if rightimage[:platform_version].to_f == 12.04
    node.set[:rightimage][:host_packages] << " liburi-perl"
  end
when "centos","rhel"

  node.set[:rightimage][:host_packages] << " swig"

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
    node.set[:rightimage][:host_packages] << " #{p}"
  end
when "suse"
  rightimage[:host_packages] << " kiwi"
end

# set base os packages
guest_packages =
case rightimage[:platform]
when "ubuntu" then %w(acpid openssh-client openssh-server language-selector-common ntp ubuntu-standard rightimage-extras-base)
when "centos", "rhel" then %w(acpid ntp openssh-server openssl dhclient rightimage-extras-base)
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

    case rightimage[:platform]
      when "ubuntu" 
        set[:rightimage][:fstab][:swap] = "defaults,nobootwait"
        if rightimage[:platform_version].to_f >= 10.10
          set[:rightimage][:swap_mount] = "/dev/xvda3" unless rightimage[:arch]  == "x86_64"
        end
      when "centos", "rhel"
        set[:rightimage][:fstab][:swap] = "defaults"

        # CentOS 6.1-6.2 start SCSI device naming from e
        if rightimage[:platform_version].to_i == 6
          if rightimage[:platform_version].to_f.between?(6.1,6.2)
            set[:rightimage][:swap_mount] = "/dev/xvde3"  unless rightimage[:arch]  == "x86_64"
          else
            set[:rightimage][:swap_mount] = "/dev/xvda3"  unless rightimage[:arch]  == "x86_64"
          end
        end
    end
  else 
    set[:rightimage][:root_mount][:dump] = "1"
    set[:rightimage][:root_mount][:fsck] = "1"
end

# set rightscale stuff
set_unless[:rightimage][:rightlink_version] = ""

set_unless[:rightimage][:rightlink_repo] = "rightlink-staging"


# http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=637234#40
set[:rightimage][:root_mount][:options] = "errors=remount-ro,barrier=0" if rightimage[:platform] == "ubuntu" && rightimage[:platform_version].to_f >= 12.04 && rightimage[:hypervisor] == "xen"


# Set path to SFTP
set[:rightimage][:sshd][:sftp_path] = node[:rightimage][:platform] == "ubuntu" ? "/usr/lib/openssh/sftp-server" : "/usr/libexec/openssh/sftp-server"
