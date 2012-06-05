rightscale_marker :begin
class Chef::Resource
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end

is_dev_image = (image_name =~ /Dev/i)
raise "ERROR: you must add 'Dev' in image name #{image_name} to enable debug mode" unless is_dev_image

log "Enable SSH password authentication and root login"
template "#{guest_root}/etc/ssh/sshd_config" do
  only_if { ((node[:rightimage][:debug] == "true") && is_dev_image)  }
  source "sshd_config.erb"
  backup false
  variables({
    :permit_root_login => "yes",
    :password_authentication => "yes"
  })
end

log "Create random root password"
bash "setup root password" do 
  only_if { ((node[:rightimage][:debug] == "true") && is_dev_image)  }
  flags "-ex"
  code <<-EOH
    ## set random root passwd 
    echo 'echo root:#{generate_persisted_passwd} | chpasswd' > #{guest_root}/tmp/chpasswd
    chmod +x #{guest_root}/tmp/chpasswd
    chroot #{guest_root} /tmp/chpasswd
EOH
end

rightscale_marker :end
