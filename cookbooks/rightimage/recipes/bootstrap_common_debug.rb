rs_utils_marker :begin
class Chef::Resource
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end

####################
## DEBUG MODE STUFF  
####################
if node[:rightimage][:debug] == "true"

  raise "ERROR: you must add 'Dev' in image name #{image_name} to enable debug mode" if (image_name !~ /Dev/) 
  
  template "#{guest_root}/etc/ssh/sshd_config" do
    only_if { ((node[:rightimage][:debug] == "true") && (image_name =~ /Dev/))  }
    source "sshd_config.erb"
    backup false
    variables({
      :permit_root_login => "yes",
      :password_authentication => "yes"
    })
  end

  bash "setup root password" do 
    only_if { ((node[:rightimage][:debug] == "true")  && (image_name =~ /Dev/))  }
    flags "-ex"
    code <<-EOH
      ## set random root passwd 
      echo 'echo root:#{generate_persisted_passwd} | chpasswd' > #{guest_root}/tmp/chpasswd
      chmod +x #{guest_root}/tmp/chpasswd
      chroot #{guest_root} /tmp/chpasswd
  EOH
  end

end

log "Add RightLink 5.6 backwards compatibility symlink"
bash "rightlink56 symlink" do
#  not_if "test -L #{guest_root}/var/spool/#{node[:rightimage][:cloud]}"
  code <<-EOH
    file=/var/spool/#{node[:rightimage][:cloud]}
    rm -rf #{guest_root}$file
    chroot #{guest_root} ln -s /var/spool/cloud $file
  EOH
end
rs_utils_marker :end
