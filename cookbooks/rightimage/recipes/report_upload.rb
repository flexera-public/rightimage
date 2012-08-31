rightscale_marker :begin

class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

# Inject md5 sum of compressed images.
ruby_block "compressed_md5_checksum" do
  block do
    require 'json'

    # Open existing json file placed in /mnt/rightimage-temp .
    hob = Hash.new
    File.open("#{temp_root}/#{loopback_filename(false)}.js","r") do |f|
      hob = JSON.load(f)
    end

    # Checksum unpartioned.

    # Inject the md5 sum.
    hob["image"]["compressed-md5"] = `md5sum #{temp_root}/#{loopback_filename(false)}.gz`.split[0]

    # Write back to unpartitioned json file.
    File.open("#{temp_root}/#{loopback_filename(false)}.js","w") do |f|
      f.write(JSON.pretty_generate(hob))
    end

    # Checksum partitioned.

    # Inject the md5 sum.
    hob["image"]["compressed-md5"] = `md5sum #{temp_root}/#{loopback_filename(true)}.gz`.split[0]

    # Write to partitioned json file.
    File.open("#{temp_root}/#{loopback_filename(true)}.js","w") do |f|
      f.write(JSON.pretty_generate(hob))
    end
  end
end

# Upload vars.
image_s3_path = guest_platform+"/"+guest_platform_version+"/"+guest_arch+"/"+timestamp[0..3]
# Switch after testing:
image_upload_bucket = node[:rightimage][:base_image_bucket]

# Upload base partitioned JSON file.
json_partitioned = temp_root+"/"+"#{loopback_filename(false)}.js"

rightimage_upload json_partitioned do
  provider "rightimage_upload_s3"
  only_if { node[:rightimage][:build_mode] == "base" }
  endpoint 's3-us-west-2.amazonaws.com'
  remote_path  "#{image_upload_bucket}/#{image_s3_path}"
  action :upload
end

# Upload base unpartitioned JSON file.
json_unpartitioned = temp_root+"/"+"#{loopback_filename(true)}.js"

rightimage_upload json_unpartitioned do
  provider "rightimage_upload_s3"
  only_if { node[:rightimage][:build_mode] == "base" }
  endpoint 's3-us-west-2.amazonaws.com'
  remote_path  "#{image_upload_bucket}/#{image_s3_path}"
  action :upload
end

rightscale_marker :end
