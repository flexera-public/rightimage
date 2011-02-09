# Common base image configurations 

template "#{node[:rightimage][:mount_dir]}/etc/ssh/sshd_config" do
  source "sshd_config.erb"
  variables({
    :permit_root_login => "without-password",
    :password_authentication => "no"
  })
end


####################
## DEBUG MODE STUFF  
####################
if node[:rightimage][:debug] == "true"
  
  raise "ERROR: you must add 'Dev' to the image to enable debug mode" unless (image_name =~ /Dev/) != nil 
  
  template "#{node[:rightimage][:mount_dir]}/etc/ssh/sshd_config" do
    only_if { node[:rightimage][:debug] == "true"  && (image_name =~ /dev/i) != nil }
    source "sshd_config.erb"
    variables({
      :permit_root_login => "yes",
      :password_authentication => "yes"
    })
  end

  bash "setup root password" do 
    only_if { node[:rightimage][:debug] == "true"  && (image_name =~ /dev/i) != nil }
    code <<-EOH
      set -e
      set -x
      ## set root passwd to 'rightscale'
      echo 'echo root:rightscale | chpasswd' > #{node[:rightimage][:mount_dir]}/tmp/chpasswd
      chmod +x #{node[:rightimage][:mount_dir]}/tmp/chpasswd
      chroot #{node[:rightimage][:mount_dir]} /tmp/chpasswd
  EOH
  end

end