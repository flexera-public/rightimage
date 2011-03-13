class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

bash "serve /mnt via http" do
  code <<-EOH
    set -x
    yum -y install httpd
    rm /etc/httpd/conf.d/welcome*
    rm -rf /var/www/html
    ln -s /mnt /var/www/html
    service httpd start
  EOH
end

include_recipe "rightimage::upload_vmops_#{node[:rightimage][:virtual_environment]}" 