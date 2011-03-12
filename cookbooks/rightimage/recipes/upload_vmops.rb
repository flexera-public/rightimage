class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

include_recipe "rightimage::upload_vmops_#{node[:rightimage][:virtual_environment]}" 