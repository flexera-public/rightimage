action :package do
  ruby_block "reload-yum-cache"  do
    only_if { node[:platform] =~ /centos|redhat/i }
    block do
      Chef::Provider::Package::Yum::YumCache.instance.reload
    end
  end

  case node[:platform]
    when "centos", /redhat/i
      vhd_util_deps=%w{git ncurses-devel dev86 iasl SDL python-devel libgcrypt-devel uuid-devel openssl-devel}
      vhd_util_deps << (el6? ? "libuuid-devel" : "e2fsprogs-devel")
    when "ubuntu"
      vhd_util_deps=%w{libncurses5-dev bin86 bcc iasl libsdl1.2-dev python-dev libgcrypt11-dev uuid-dev libssl-dev gettext libc6-dev libc6-dev:i386}
      vhd_util_deps << (node[:rightimage][:platform_version].to_f < 12.04 ? "libsdl1.2debian-all" : "libsdl1.2debian")
    else
      raise "ERROR: platform #{node[:platform]} not supported. Please feel free to add support ;) "
  end

  vhd_util_deps.each { |p| package p }

  cookbook_file "/tmp/vhd-util-patch" do 
    source "vhd-util-patch"
  end

  bash "install_vhd-util" do 
    not_if "which vhd-util"
    flags "-ex"
    code <<-EOF
      rm -rf /mnt/vhd && mkdir /mnt/vhd && cd /mnt/vhd
      # Mercurial repo generated with command 'hg clone --rev 21560 http://xenbits.xensource.com/xen-4.0-testing.hg'
      wget -q #{node[:rightimage][:s3_base_url]}/files/vhd-util-rev21560.tar.gz 
      tar zxf vhd-util-rev21560.tar.gz 
      cd xen-4.0-testing.hg
      patch --forward -p1 < /tmp/vhd-util-patch
      make install-tools
      cd tools/blktap2/
      make 
      make install
    EOF
  end

  # Xen tools libs install into /usr/lib64, not in search path on Ubuntu 12.04
  execute "echo '/usr/lib64' > /etc/ld.so.conf.d/usr-lib64.conf && ldconfig" do
    only_if { ::File.exists?"/etc/ld.so.conf.d" }
    creates "/etc/ld.so.conf.d/usr-lib64.conf"
  end

  bash "package XEN image" do 
    cwd target_raw_root
    flags "-ex"
    code <<-EOH
      raw_image="#{loopback_rootname}.raw"
      vhd_image=${raw_image}.vhd
      qemu-img convert -f qcow2 -O raw #{loopback_file} $raw_image
      vhd-util convert -s 0 -t 1 -i $raw_image -o $vhd_image
      vhd-util convert -s 1 -t 2 -i $vhd_image -o #{image_name}.vhd
      bzip2 -k #{image_name}.vhd
    EOH
  end
end
