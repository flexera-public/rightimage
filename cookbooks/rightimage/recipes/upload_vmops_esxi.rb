rightimage_upload_vmops "Upload image to ESXi" do
  api_url "http://72.52.126.24:8096"
  file_ext "vmdk"
  action :upload
end
