rs_utils_marker :begin
rightimage_upload_vmops "Upload image to Xen" do
  api_url "http://173.227.0.170:8096"
  file_ext "vhd"
  action :upload
end
rs_utils_marker :end
