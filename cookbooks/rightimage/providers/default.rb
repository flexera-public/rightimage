 class Chef::Provider
   include RightScale::RightImage::Helper
 end

action :sanitize do

  ruby_block "sanitize" do
    block do
      util = RightImage::Util.new(new_resource.name, Chef::Log)
      skip_files = [node[:rightimage][:fstab][:ephemeral][:mount]]
      util.sanitize({:skip_files => skip_files})
    end
  end
  
end
