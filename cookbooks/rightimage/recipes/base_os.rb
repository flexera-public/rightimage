rightscale_marker :begin

class Chef::Resource
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end

# Install any dependencies
node[:rightimage][:host_packages].each { |p| package p.strip }

# Most of the heavy lifting, install the os from scratch
rightimage_os node[:rightimage][:platform] do
  platform_version node[:rightimage][:platform_version].to_f
  arch node[:rightimage][:arch]
  action :install
end

# Common base image configurations 
bash "resolv.conf" do
  code <<-EOH
    echo "nameserver 8.8.4.4" >> #{guest_root}/etc/resolv.conf
  EOH
end

bash "install_rubygems" do 
  not_if  "chroot #{guest_root} which gem"
  flags "-ex"
  code <<-EOC
ROOT=#{guest_root}

function get_rubygems {
  # Don't use wget -- Old versions have unreliable return codes (such as on CentOS 5)
  curl -o $ROOT/tmp/rubygems.tgz --fail --silent http://s3.amazonaws.com/rightscale_software/rubygems-$1.tgz
  tar -xzvf $ROOT/tmp/rubygems.tgz  -C $ROOT/tmp
  mv $ROOT/tmp/rubygems-$1 $ROOT/tmp/rubygems
}

ruby_ver=`chroot $ROOT ruby --version`
if [[ $ruby_ver == *1.8.5* ]] ; then
  get_rubygems 1.3.3
  # Newer versions of rake will not work with older versions of Ruby
  rake_ver="-v 0.9.2";
  install_rubygems=Y
elif [[ $ruby_ver == *1.8.7* ]] ; then
  get_rubygems 1.3.7
  rake_ver="";
  install_rubygems=Y
fi
# else if ruby is 1.9 it comes packaged with rubygems normally

cat <<-CHROOT_SCRIPT > $ROOT/tmp/rubygems_install.sh
#!/bin/bash -ex
cd /tmp/rubygems
ruby setup.rb 
CHROOT_SCRIPT

cat <<-CHROOT_SCRIPT > $ROOT/tmp/rubygems_links.sh
if [ ! -e /usr/bin/gem ] && [ -e /usr/bin/gem1.9.1 ]; then
  ln -sf /usr/bin/gem1.9.1 /usr/bin/gem
fi
if [ ! -e /usr/bin/gem ] && [ -e /usr/bin/gem1.8 ]; then
  ln -sf /usr/bin/gem1.8 /usr/bin/gem
fi
CHROOT_SCRIPT

chmod +x $ROOT/tmp/rubygems_install.sh
if [ "$install_rubygems" = "Y" ]; then
  chroot $ROOT /tmp/rubygems_install.sh > /dev/null 
fi
chroot $ROOT /tmp/rubygems_links.sh > /dev/null 
EOC
end

# Method recommened by CentOS:
# https://bugzilla.redhat.com/show_bug.cgi?id=641836#c17
bash "disable IPv6" do
  code <<-EOF
    guest_root=#{guest_root}
    file=$guest_root/etc/sysctl.conf
    grep "net.ipv6.conf.all.disable_ipv6" $file

    if [ "$?" == "1" ]; then
      echo -n "Disabling IPv6"
      cat <<-EOC >> $file
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOC
    else
      echo -n "IPv6 already disabled"
    fi
  EOF
end

# prevents rsyslog from dropping messages from rightlink w-4912
directory("#{guest_root}/etc/rsyslog.d"){ recursive true }
bash "turn off rsyslog rate limiting" do
  code "echo '$SystemLogRateLimitInterval 0' > #{guest_root}/etc/rsyslog.d/10-removeratelimit.conf"
end

bash "setup_motd" do
  only_if { ::File.directory? "#{guest_root}/etc/update-motd.d" }
  code <<-EOC
    rm #{guest_root}/etc/update-motd.d/10-help-text || true
    mv #{guest_root}/etc/update-motd.d/99-footer #{guest_root}/etc/update-motd.d/10-rightscale-message || true
  EOC
end

cookbook_file "#{guest_root}/etc/motd.tail" do 
  only_if { ::File.directory? "#{guest_root}/etc/update-motd.d" }
  source "motd"
  backup false
end

cookbook_file "#{guest_root}/etc/motd" do 
  not_if { ::File.directory? "#{guest_root}/etc/update-motd.d" }
  source "motd"
  backup false
end

# Configure NTP - RightLink requires local time to be accurate (w-5025)
template "#{guest_root}/etc/ntp.conf" do
  source "ntp.conf.erb"
  backup false
  variables({
    :driftfile => node[:rightimage][:platform] == "ubunutu" ? "/var/lib/ntp/ntp.drift" : "/var/lib/ntp/drift"
  })
end

# Clean up GUEST_ROOT image
rightimage guest_root do
  action :sanitize
end

rightscale_marker :end
