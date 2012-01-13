rs_utils_marker :begin
execute "umount -lf  #{node[:rightimage][:build_dir]}/proc || true"
execute "umount -lf  #{node[:rightimage][:mount_dir]}/proc || true"

directory node[:rightimage][:build_dir] do 
  action :delete
  recursive true
end

ruby_block "delete image id list" do
  block do
    # add to global id store for use by other recipes
    id_list = RightImage::IdList.new(Chef::Log)
    id_list.clear
  end
end
rs_utils_marker :end
