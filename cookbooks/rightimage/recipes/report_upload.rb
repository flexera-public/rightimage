rightscale_marker :begin

class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

# Inject base image MD5 checksums.
# Partitioned and unpartitioned.
ruby_block "base_md5_checksums" do
  only_if { node[:rightimage][:build_mode] == "base" }
  block do
    require 'json'

    # Open existing JSON file placed in /mnt/rightimage-temp .
    hob = Hash.new
    File.open("#{temp_root}/#{loopback_filename(partitioned?)}.js","r") do |f|
      hob = JSON.load(f)
    end

    # Checksum unpartioned.

    # Inject the MD5 checksum.
    hob["image"]["compressed-md5"] = `md5sum #{temp_root}/#{loopback_filename(false)}.gz`.split[0]

    # Write back to unpartitioned image's JSON.
    File.open("#{temp_root}/#{loopback_filename(false)}.js","w") do |f|
      f.write(JSON.pretty_generate(hob))
    end

    # Checksum partitioned.

    # Inject the MD5 checksum.
    hob["image"]["compressed-md5"] = `md5sum #{temp_root}/#{loopback_filename(true)}.gz`.split[0]

    # Write to partitioned image's JSON.
    File.open("#{temp_root}/#{loopback_filename(true)}.js","w") do |f|
      f.write(JSON.pretty_generate(hob))
    end
  end
end

# Full image vars.
full_image_path = target_raw_root+"/"+image_name+"."+node[:rightimage][:image_type]
compressed_full_image_path = target_raw_root+"/"+image_name+"."+image_file_ext

# Inject full image MD5 checksums.
# Compressed and uncompressed.
ruby_block "full_md5_checksums" do
  only_if { node[:rightimage][:build_mode] == "full" }
  block do
    require 'json'

    # Open existing JSON file placed in /mnt/rightimage-temp .
    hob = Hash.new
    File.open("#{temp_root}/#{loopback_filename(partitioned?)}.js","r") do |f|
      hob = JSON.load(f)
    end

    # Uncompressed MD5 sum.
    hob["image"]["md5"] = `md5sum #{full_image_path}`.split[0]

    # Compressed MD5 sum.
    hob["image"]["compressed-md5"] = `md5sum #{compressed_full_image_path}`.split[0]

    # Write to full image's JSON.
    File.open("#{temp_root}/#{loopback_filename(partitioned?)}.js","w") do |f|
      f.write(JSON.pretty_generate(hob))
    end
  end
end


# Upload JSON files.
  # Base and Full cases. 

# Upload vars.
if (node[:rightimage][:build_mode] == "base")
  image_s3_path = guest_platform+"/"+guest_platform_version+"/"+guest_arch+"/"+timestamp[0..3]
  image_upload_bucket = node[:rightimage][:base_image_bucket]
elsif (node[:rightimage][:build_mode] == "full")
  image_s3_path = node[:rightimage][:hypervisor]+"/"+guest_platform+"/"+guest_platform_version
  image_upload_bucket = "rightscale-#{node[:rightimage][:cloud]}-dev"
  # Add compressed extensions to image name and remove last extension to compensate for s3index.
  full_image_rootname = (image_name+"."+image_file_ext).split(".").slice(0..-2).join(".")
end

# Base image case:

# Upload partitioned JSON file.
json_partitioned = temp_root+"/"+"#{loopback_filename(false)}.js"

rightimage_upload json_partitioned do
  provider "rightimage_upload_s3"
  only_if { node[:rightimage][:build_mode] == "base" }
  endpoint 's3-us-west-2.amazonaws.com'
  remote_path  "#{image_upload_bucket}/#{image_s3_path}"
  action :upload
end

# Upload unpartitioned JSON file.
json_unpartitioned = temp_root+"/"+"#{loopback_filename(true)}.js"

rightimage_upload json_unpartitioned do
  provider "rightimage_upload_s3"
  only_if { node[:rightimage][:build_mode] == "base" }
  endpoint 's3-us-west-2.amazonaws.com'
  remote_path  "#{image_upload_bucket}/#{image_s3_path}"
  action :upload
end

# Full image case:

# Rename JSON file to match packaged image.
bash "upload_JSON_reports" do
  cwd temp_root
  flags "-ex"
  code <<-EOH
  mv #{loopback_filename(partitioned?)}.js #{full_image_rootname}.js
  EOH
end

json_full_image = temp_root+"/"+"#{full_image_rootname}.js"

rightimage_upload json_full_image do
  provider "rightimage_upload_s3"
  only_if { node[:rightimage][:build_mode] == "full" }
  endpoint 's3-us-west-1.amazonaws.com'
  remote_path  "#{image_upload_bucket}/#{image_s3_path}"
  action :upload
end

rightscale_marker :end
