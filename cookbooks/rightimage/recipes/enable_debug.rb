rightscale_marker :begin
class Chef::Resource
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end

####################
## DEBUG MODE STUFF  
####################
raise "ERROR: you must add 'Dev' in image name #{image_name} to enable debug mode" if (image_name !~ /Dev/) 

template "#{guest_root}/etc/ssh/sshd_config" do
  source "sshd_config.erb"
  backup false
  variables({
    :permit_root_login => "yes",
    :password_authentication => "yes"
  })
end

bash "setup root password" do 
  flags "-ex"
  code <<-EOH
    ## set random root passwd 
    echo 'echo root:#{generate_persisted_passwd} | chpasswd' > #{guest_root}/tmp/chpasswd
    chmod +x #{guest_root}/tmp/chpasswd
    chroot #{guest_root} /tmp/chpasswd
EOH
end

rightscale_marker :end
