## when pasting a key into a json file, make sure to use the following command: 
## sed -e :a -e '$!N;s/\n/\\n/;ta' /path/to/key
## this seems not to work on os x

UNKNOWN = :unknown.to_s

set_unless[:rightimage][:debug] = false
set[:rightimage][:lang] = "en_US.UTF-8"
set[:rightimage][:root_size] = "2048"
set[:rightimage][:build_dir] = "/mnt/vmbuilder"
set[:rightimage][:mount_dir] = "/mnt/image"
set[:rightimage][:virtual_environment] = "xen"
set[:rightimage][:install_mirror] = "mirror.rightscale.com"
# for using apt-proxy
#set[:rightimage][:install_mirror] = "localhost:9999"
set_unless[:rightimage][:image_name_override] = ""
set_unless[:rightimage][:install_mirror_date] = "latest" 

# set base os packages
case rightimage[:platform]
when "ubuntu" 

    
  set[:rightimage][:guest_packages] = "ubuntu-standard binutils ruby1.8 curl unzip openssh-server ruby1.8-dev build-essential autoconf automake libtool logrotate rsync openssl openssh-server ca-certificates libopenssl-ruby1.8 subversion vim libreadline-ruby1.8 irb rdoc1.8 git-core liberror-perl libdigest-sha1-perl dmsetup emacs rake screen mailutils nscd bison ncurses-dev zlib1g-dev libreadline5-dev readline-common libxslt1-dev sqlite3 libxml2 flex libshadow-ruby1.8 postfix sysstat iptraf"

  set[:rightimage][:host_packages] = "openjdk-6-jre openssl ca-certificates"

  case rightimage[:release]
    when "maverick"
      rightimage[:host_packages] << " apt-cacher"
    else
      rightimage[:host_packages] << " apt-proxy"
  end

  set[:rightimage][:package_type] = "deb"
  rightimage[:guest_packages] << " euca2ools" if rightimage[:cloud] == "euca"

when "centos" 
  set[:rightimage][:guest_packages] = "wget mlocate nano logrotate ruby ruby-devel ruby-docs ruby-irb ruby-libs ruby-mode ruby-rdoc ruby-ri ruby-tcltk postfix openssl openssh openssh-askpass openssh-clients openssh-server curl gcc* zip unzip bison flex compat-libstdc++-296 cvs subversion autoconf automake libtool compat-gcc-34-g77 mutt sysstat rpm-build fping vim-common vim-enhanced rrdtool-1.2.27 rrdtool-devel-1.2.27 rrdtool-doc-1.2.27 rrdtool-perl-1.2.27 rrdtool-python-1.2.27 rrdtool-ruby-1.2.27 rrdtool-tcl-1.2.27 pkgconfig lynx screen yum-utils bwm-ng createrepo redhat-rpm-config redhat-lsb git nscd xfsprogs collectd swig"

  rightimage[:guest_packages] << " kernel-xen" if rightimage[:cloud] == "euca"

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
      set[:rightimage][:guest_packages] = rightimage[:guest_packages] + " linux-image-2.6.32-308-ec2 linux-image-2.6.32-305-ec2" 
      rightimage[:host_packages] << " python-vm-builder-ec2 devscripts"
    else
      set[:rightimage][:guest_packages] = rightimage[:guest_packages] + " linux-image-virtual" 
      rightimage[:host_packages] << " python-vm-builder  devscripts"
    end
  when "maverick"
    # python-vm-builder installed from custom debs
    rightimage[:host_packages] << " devscripts"
    set[:rightimage][:guest_packages] = rightimage[:guest_packages] + " linux-image-virtual grub-legacy-ec2"
end if rightimage[:platform] == "ubuntu" 

# set cloud stuff
case rightimage[:cloud]
  when "ec2" 
    set[:rightimage][:root_mount] = "/dev/sda1" 
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
  when "vmops"
    set[:rightimage][:fstab][:ephemeral_mount_opts] = "defaults"
    set[:rightimage][:root_mount] = "/dev/xvda"
    set[:rightimage][:ephemeral_mount] = "/dev/xvdb"
end

# set rightscale stuff
set_unless[:rightimage][:rightscale_release] = ""
set_unless[:rightimage][:aws_access_key_id] = nil
set_unless[:rightimage][:aws_secret_access_key] = nil

# generate command to install getsshkey init script 
case rightimage[:platform]
  when "ubuntu" 
    set[:rightimage][:getsshkey_cmd] = "chroot #{rightimage[:mount_dir]} update-rc.d getsshkey start 20 2 3 4 5 . stop 1 0 1 6 ."
    set[:rightimage][:mirror_file] = "sources.list.erb"
    set[:rightimage][:mirror_file_path] = "/etc/apt/sources.list"
  when "centos"
    set[:rightimage][:getsshkey_cmd] = "chroot #{rightimage[:mount_dir]} chkconfig --add getsshkey && \
               chroot #{rightimage[:mount_dir]} chkconfig --level 4 getsshkey on"
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

## figure out kernel to use
case rightimage[:release]
when UNKNOWN
when "hardy"
  case rightimage[:region]
  when "us-east"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:kernel_id] = "aki-a71cf9ce"
      set[:rightimage][:ramdisk_id] = "ari-a51cf9cc"
    when "x86_64"
      set[:rightimage][:kernel_id] = "aki-b51cf9dc"
      set[:rightimage][:ramdisk_id] = "ari-b31cf9da"
    end
  when "us-west"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:kernel_id] = "aki-873667c2"
      set[:rightimage][:ramdisk_id] = "ari-853667c0"
    when "x86_64"
      set[:rightimage][:kernel_id] = "aki-813667c4"
      set[:rightimage][:ramdisk_id] = "ari-833667c6"
    end
  when "eu-west" 
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:kernel_id] = "aki-7e0d250a"
      set[:rightimage][:ramdisk_id] = "ari-7d0d2509"
    when "x86_64"
      set[:rightimage][:kernel_id] = "aki-780d250c"
      set[:rightimage][:ramdisk_id] = "ari-7f0d250b"
    end
  when "ap-southeast"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:kernel_id] = "aki-15f58a47"
      set[:rightimage][:ramdisk_id] = "ari-37f58a65"
    when "x86_64"
      set[:rightimage][:kernel_id] = "aki-1df58a4f"
      set[:rightimage][:ramdisk_id] = "ari-35f58a67"
    end
  end
when "karmic"
  case rightimage[:region]
  when "us-east"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:kernel_id] = "aki-5f15f636"
      set[:rightimage][:ramdisk_id] = "ari-d5709dbc"
    when "x86_64"
      set[:rightimage][:kernel_id] = "aki-fd15f694"
      set[:rightimage][:ramdisk_id] = "ari-c515f6ac"
    end
  when "us-west"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:kernel_id] = "aki-733c6d36"
      set[:rightimage][:ramdisk_id] = "ari-632e7f26"
    when "x86_64"
      set[:rightimage][:kernel_id] = "aki-033c6d46"
      set[:rightimage][:ramdisk_id] = "ari-793c6d3c"
    end
  when "eu-west" 
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:kernel_id] = "aki-0c5e7578"
      set[:rightimage][:ramdisk_id] = "ari-39c2e94d"
    when "x86_64"
      set[:rightimage][:kernel_id] = "aki-a22a01d6"
      set[:rightimage][:ramdisk_id] = "ari-ac2a01d8"
    end
  when "ap-southeast"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:kernel_id] = "aki-87f38cd5"
      set[:rightimage][:ramdisk_id] = "ari-85f38cd7"
    when "x86_64"
      set[:rightimage][:kernel_id] = "aki-83f38cd1"
      set[:rightimage][:ramdisk_id] = "ari-81f38cd3"
    end
  end
# These come from http://uec-images.ubuntu.com/query/lucid/server/released.current.txt
# DO NOT LISTEN TO WHAT THE AMAZON WEB PAGE SAYS
# lucid server  release 20101020  ebs amd64 ap-southeast-1  ami-06067854  aki-6c06783e  
# lucid server  release 20101020  ebs i386  ap-southeast-1  ami-00067852  aki-70067822  
# lucid server  release 20101020  instance-store  amd64 ap-southeast-1  ami-14067846  aki-6c06783e  
# lucid server  release 20101020  instance-store  i386  ap-southeast-1  ami-60067832  aki-70067822  
# lucid server  release 20101020  ebs amd64 eu-west-1 ami-f6340182  aki-14340160  
# lucid server  release 20101020  ebs i386  eu-west-1 ami-f4340180  aki-62340116  
# lucid server  release 20101020  instance-store  amd64 eu-west-1 ami-1e34016a  aki-14340160  
# lucid server  release 20101020  instance-store  i386  eu-west-1 ami-4a34013e  aki-62340116  
# lucid server  release 20101020  ebs amd64 us-east-1 ami-4a0df923  aki-6a0cf803  
# lucid server  release 20101020  ebs i386  us-east-1 ami-480df921  aki-6603f70f  
# lucid server  release 20101020  instance-store  amd64 us-east-1 ami-da0cf8b3  aki-6a0cf803  
# lucid server  release 20101020  instance-store  i386  us-east-1 ami-a403f7cd  aki-6603f70f  
# lucid server  release 20101020  ebs amd64 us-west-1 ami-880c5ccd  aki-ea0c5caf  
# lucid server  release 20101020  ebs i386  us-west-1 ami-8c0c5cc9  aki-e40c5ca1  
# lucid server  release 20101020  instance-store  amd64 us-west-1 ami-860c5cc3  aki-ea0c5caf  
# lucid server  release 20101020  instance-store  i386  us-west-1 ami-e80c5cad  aki-e40c5ca1

when "lucid"
  case rightimage[:region]
  when "us-east"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:kernel_id] = "aki-6a0cf803"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:kernel_id] = "aki-6603f70f"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "us-west"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:kernel_id] = "aki-e40c5ca1"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:kernel_id] = "aki-ea0c5caf"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "eu-west" 
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:kernel_id] = "aki-62340116"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:kernel_id] = "aki-14340160"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "ap-southeast"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:kernel_id] = "aki-70067822"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:kernel_id] = "aki-6c06783e"
      set[:rightimage][:ramdisk_id] = nil
    end
  end
when "maverick"
  case rightimage[:region]
  when "us-east"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:kernel_id] = "aki-407d9529"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:kernel_id] = "aki-427d952b"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "us-west"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:kernel_id] = "aki-99a0f1dc"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:kernel_id] = "aki-9ba0f1de"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "eu-west" 
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:kernel_id] = "aki-4deec439"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:kernel_id] = "aki-4feec43b"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "ap-southeast"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:kernel_id] = "aki-13d5aa41"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:kernel_id] = "aki-11d5aa43"
      set[:rightimage][:ramdisk_id] = nil
    end
  end
when "5.4"
when "5.2"
  case rightimage[:region]
  when "us-east"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:kernel_id] = "aki-a71cf9ce"
      set[:rightimage][:ramdisk_id] = "ari-a51cf9cc"
    when "x86_64"
      set[:rightimage][:kernel_id] = "aki-b51cf9dc"
      set[:rightimage][:ramdisk_id] = "ari-b31cf9da"
    end
  when "us-west"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:kernel_id] = "aki-873667c2"
      set[:rightimage][:ramdisk_id] = "ari-853667c0"
    when "x86_64"
      set[:rightimage][:kernel_id] = "aki-813667c4"
      set[:rightimage][:ramdisk_id] = "ari-833667c6"
    end
  when "eu-west"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:kernel_id] = "aki-7e0d250a"
      set[:rightimage][:ramdisk_id] = "ari-7d0d2509"
    when "x86_64"
      set[:rightimage][:kernel_id] = "aki-780d250c"
      set[:rightimage][:ramdisk_id] = "ari-7f0d250b"
    end
  when "ap-southeast"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:kernel_id] = "aki-15f58a47"
      set[:rightimage][:ramdisk_id] = "ari-37f58a65"
    when "x86_64"
      set[:rightimage][:kernel_id] = "aki-1df58a4f"
      set[:rightimage][:ramdisk_id] = "ari-35f58a67"
    end
  end
end

## set kernel to use for vmops
case rightimage[:release]
when "5.2" 
  set[:rightimage][:vmops][:kernel] = "2.6.18-92.1.22.el5.centos.plusxen"
when "5.4" 
  set[:rightimage][:vmops][:kernel] = "2.6.18-164.15.1.el5.centos.plusxen"
end
