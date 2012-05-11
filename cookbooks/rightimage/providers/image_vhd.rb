action :package do
  ruby_block "reload-yum-cache"  do
    only_if { node[:platform] =~ /centos|redhat/i }
    block do
      Chef::Provider::Package::Yum::YumCache.instance.reload
    end
  end

  case node[:platform]
    when "centos", /redhat/i
      vhd_util_deps=%w{mercurial git ncurses-devel dev86 iasl SDL python-devel libgcrypt-devel uuid-devel openssl-devel}
    when "ubuntu"
      vhd_util_deps=%w{mercurial libncurses5-dev bin86 bcc iasl libsdl1.2debian-all libsdl1.2-dev python-dev libgcrypt11-dev uuid-dev libssl-dev gettext}
    else
      raise "ERROR: plaform #{node[:platform]} not supported. Please feel free to add support ;) "
  end

  vhd_util_deps.each { |p| package p }

  remote_file "/tmp/vhd-util-patch" do 
    source "vhd-util-patch"
  end

  bash "install_vhd-util" do 
    not_if "which vhd-util"
    flags "-ex"
    code <<-EOF
      rm -rf /mnt/vhd && mkdir /mnt/vhd && cd /mnt/vhd
      hg clone --rev 21560 http://xenbits.xensource.com/xen-4.0-testing.hg
      cd xen-4.0-testing.hg/tools
      patch -p0 < /tmp/vhd-util-patch
      cd ..
      make install-tools
      cd tools/blktap2/
      make 
      make install
    EOF
  end

  bash "package XEN image" do 
    cwd temp_root
    flags "-ex"
    code <<-EOH
      raw_image=$(basename #{loopback_file(partitioned?)})
      vhd_image=${raw_image}.vhd
      vhd-util convert -s 0 -t 1 -i $raw_image -o $vhd_image
      vhd-util convert -s 1 -t 2 -i $vhd_image -o #{image_name}.vhd
      rm -f #{image_name}.vhd.bz2
      bzip2 -k #{image_name}.vhd
    EOH
  end
end
