rightscale_marker :begin

ruby_block "delete image id list" do
  block do
    # add to global id store for use by other recipes
    id_list = RightImage::IdList.new(Chef::Log)
    id_list.clear
  end
end
rightscale_marker :end
