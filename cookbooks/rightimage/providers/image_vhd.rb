action :package do
  ruby_block "reload-yum-cache"  do
    only_if { node[:platform] =~ /centos|redhat/i }
    block do
      Chef::Provider::Package::Yum::YumCache.instance.reload
    end
  end

  case node[:platform]
    when "centos", /redhat/i
      vhd_util_deps=%w{git ncurses-devel dev86 iasl SDL python-devel libgcrypt-devel uuid-devel openssl-devel glib2-devel yajl-devel texinfo}
      vhd_util_deps << (el6? ? "libuuid-devel" : "e2fsprogs-devel")
    when "ubuntu"
      vhd_util_deps=%w{libncurses5-dev bin86 bcc iasl libsdl1.2-dev python-dev libgcrypt11-dev uuid-dev libssl-dev gettext libc6-dev libc6-dev:i386 libyajl-dev texinfo}
      vhd_util_deps << (node[:rightimage][:platform_version].to_f < 12.04 ? "libsdl1.2debian-all" : "libsdl1.2debian")
    else
      raise "ERROR: platform #{node[:platform]} not supported. Please feel free to add support ;) "
  end

  vhd_util_deps.each { |p| package p }

  # Pulled from: https://github.com/citrix-openstack/xenserver-utils/blob/984739db2198fbce23f61a90638b5b70c4bff5a0/blktap2.patch 
  cookbook_file "/tmp/vhd-util-patch" do 
    source "vhd-util-patch"
  end

  bash "install_vhd-util" do 
    not_if "which vhd-util"
    flags "-ex"
    code <<-EOF
      rm -rf /mnt/vhd && mkdir /mnt/vhd && cd /mnt/vhd
      # Pulled from: http://bits.xensource.com/oss-xen/release/4.2.0/xen-4.2.0.tar.gz
      wget -q #{node[:rightimage][:s3_base_url]}/files/xen-4.2.0.tar.gz
      tar zxf xen-4.2.0.tar.gz
      cd xen-4.2.0/tools
      patch --forward -p0 < /tmp/vhd-util-patch
      cd ..
      ./configure --disable-monitors --disable-ocamltools --disable-rombios --disable-seabios
      make
      cd tools/blktap2/
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
      rm -f ${vhd_image}.bak
      bzip2 #{image_name}.vhd
    EOH
  end
end
