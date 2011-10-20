class Chef::Resource::Template
  include RightScale::RightImage::Helper
end
class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end

# Common base image configurations 

template "#{guest_root}/etc/ssh/sshd_config" do
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

  raise "ERROR: you must add 'Dev' in image name #{image_name} to enable debug mode" if (image_name !~ /Dev/) 
  
  template "#{guest_root}/etc/ssh/sshd_config" do
    only_if { ((node[:rightimage][:debug] == "true") && (image_name =~ /Dev/))  }
    source "sshd_config.erb"
    variables({
      :permit_root_login => "yes",
      :password_authentication => "yes"
    })
  end

  bash "setup root password" do 
    only_if { ((node[:rightimage][:debug] == "true")  && (image_name =~ /Dev/))  }
    code <<-EOH
      set -e
      set -x
      ## set random root passwd 
      echo 'echo root:#{generate_persisted_passwd} | chpasswd' > #{guest_root}/tmp/chpasswd
      chmod +x #{guest_root}/tmp/chpasswd
      chroot #{guest_root} /tmp/chpasswd
  EOH
  end

end
