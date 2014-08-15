rightscale_marker :begin
class Chef::Resource
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end

is_dev_image = (image_name =~ /Dev/i)
raise "ERROR: you must add 'Dev' in image name #{image_name} to enable debug mode" unless is_dev_image



if is_dev_image && ["true", "fixed_password"].include?(node[:rightimage][:debug])

  log "Enable SSH password authentication and root login"

  template "#{guest_root}/etc/ssh/sshd_config" do
    source "sshd_config.erb"
    backup false
    variables({
      :permit_root_login => "yes",
      :password_authentication => "yes"
    })
  end
  if node[:rightimage][:debug] == "fixed_password"
    password = node[:rightimage][:fixed_password]
  else
    password = generate_persisted_passwd
  end
  bash "setup root password" do 
    flags "-ex"
    code <<-EOH
      echo "echo 'root:#{password}' | chpasswd" > #{guest_root}/tmp/chpasswd
      chmod +x #{guest_root}/tmp/chpasswd
      chroot #{guest_root} /tmp/chpasswd
    EOH
  end
end

rightscale_marker :end
