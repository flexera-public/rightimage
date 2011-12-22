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
