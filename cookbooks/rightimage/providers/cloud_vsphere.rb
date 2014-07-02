class Chef::Resource
  include RightScale::RightImage::Helper
end



action :configure do
  rightimage_cloud "cloudstack" do
    image_name  helper_image_name
  
    hypervisor        node[:rightimage][:hypervisor]
    arch              node[:rightimage][:arch]
    platform          node[:rightimage][:platform]
    platform_version  node[:rightimage][:platform_version].to_f
  
    action :configure
  end

  # Create metadata mount directory. 
  directory "#{guest_root}/mnt/metadata" do
    owner "root"
    group "root"
    mode "0750"
    action :create
    recursive true
  end 
end

action :package do
  rightimage_image node[:rightimage][:image_type] do
    action :package
  end
end

action :upload do

  raise "Upload not yet implemented."

  # add to global id store for use by other recipes
  ruby_block "store id" do
    block do
    
      id_list = RightImage::IdList.new(Chef::Log)
      id_list.add(image_id)
    end
  end
end
