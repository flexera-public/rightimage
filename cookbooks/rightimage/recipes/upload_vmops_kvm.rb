rs_utils_marker :begin
rightimage_upload_vmops "Upload image to KVM" do
  api_url "http://72.52.126.24:8096"
  file_ext "qcow2.bz2"
  action :upload
end
rs_utils_marker :end
