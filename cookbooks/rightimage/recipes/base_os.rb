rightscale_marker :begin

# Install any dependencies
node[:rightimage][:host_packages].each { |p| package p.strip }

# Most of the heavy lifting, install the os from scratch
rightimage_os node[:rightimage][:platform] do
  platform_version node[:rightimage][:platform_version].to_f
  arch node[:rightimage][:arch]
  action :install
end

rightimage_os node[:rightimage][:platform] do
  action :repo_freeze
end

rightimage_bootloader "grub" do
  hypervisor node[:rightimage][:hypervisor]
  platform node[:rightimage][:platform]
  platform_version node[:rightimage][:platform_version].to_f
  cloud "none"
  action :install
end


# Common base image configurations 
bash "resolv.conf" do
  code <<-EOH
    echo "nameserver 8.8.4.4" > #{guest_root}/etc/resolv.conf
  EOH
end

template "#{guest_root}/etc/ssh/sshd_config" do
  source "sshd_config.erb"
  backup false
  variables({
    :permit_root_login => "without-password",
    :password_authentication => "no"
  })
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
    :driftfile => node[:rightimage][:platform] == "ubuntu" ? "/var/lib/ntp/ntp.drift" : "/var/lib/ntp/drift"
  })
end

rightimage_os node[:rightimage][:platform] do
  action :repo_unfreeze
end

# Clean up GUEST_ROOT image
rightimage guest_root do
  action :sanitize
end



rightscale_marker :end
