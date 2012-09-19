rightscale_marker :begin

class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

# Inject base image MD5 checksums.
# JSON file created for partitioned and unpartitioned cases.
ruby_block "base_md5_checksums" do
  only_if { node[:rightimage][:build_mode] == "base" }
  # Skip if MD5 has already been taken.
  # Evidenced by existing JSON file for non-partitioned image.
  not_if { File.exists?("#{temp_root}/#{loopback_rootname( (not partitioned?) )}.js") }  
  block do
    require 'json'

    # Open existing JSON file placed in /mnt/rightimage-temp .
    hob = Hash.new
    File.open("#{temp_root}/#{loopback_rootname(partitioned?)}.js","r") do |f|
      hob = JSON.load(f)
    end

    # Checksum unpartioned.

    # Inject the MD5 checksum.
    hob["image"]["compressed-md5"] = `md5sum #{temp_root}/#{loopback_filename(false)}.gz`.split[0]

    # Write back to unpartitioned image's JSON.
    File.open("#{temp_root}/#{loopback_rootname(false)}.js","w") do |f|
      f.write(JSON.pretty_generate(hob))
    end

    # Checksum partitioned.

    # Inject the MD5 checksum.
    hob["image"]["compressed-md5"] = `md5sum #{temp_root}/#{loopback_filename(true)}.gz`.split[0]

    # Write to partitioned image's JSON.
    File.open("#{temp_root}/#{loopback_rootname(true)}.js","w") do |f|
      f.write(JSON.pretty_generate(hob))
    end
  end
end

# Inject full image MD5 checksums.
# Compressed and uncompressed.
# JSON file re-saved after MD5 checksums to match image name.
ruby_block "full_md5_checksums" do
  only_if { node[:rightimage][:build_mode] == "full" }
  # Skip if MD5 has already been taken.
  not_if { File.exists?("#{temp_root}/#{image_name}.js") }
  block do
    require 'json'

    # Open JSON file placed in /mnt/rightimage-temp by "rightimage::image_report".
    hob = Hash.new
    File.open("#{temp_root}/#{loopback_rootname(partitioned?)}.js","r") do |f|
      hob = JSON.load(f)
    end

    # Uncompressed full image MD5 sum.

    # Eucalyptus + xen case.
    if (node[:rightimage][:cloud] == "eucalyptus" && node[:rightimage][:hypervisor] == "xen" )
      # Directory with uncompressed image and kernel directory.
      euca_dir = "#{target_raw_root}/#{image_name}"

      # Uncompressed image.
      euca_image_path = "#{euca_dir}/#{image_name}.#{uncomp_image_ext}"
      hob["image"]["image-md5"] = `md5sum #{euca_image_path}`.split[0]

      # Initial ramdisk.
      initrd_path = Dir.glob("#{euca_dir}/xen-kernel/initrd*")[0]
      hob["image"]["initrd-md5"] = `md5sum #{initrd_path}`.split[0]

      # Compressed kernel.
      vmlinuz_path = Dir.glob("#{euca_dir}/xen-kernel/vmlinuz*")[0]
      hob["image"]["vmlinuz-md5"] = `md5sum #{vmlinuz_path}`.split[0]

    # EC2 and GCE don't change the names of their raw images.
    elsif node[:rightimage][:cloud] =~ /ec2|google/
      hob["image"]["md5"] = `md5sum #{loopback_file(partitioned?)}`.split[0]
    # All other clouds.
    else
      uncompressed_full_image_path = "#{target_raw_root}/#{image_name}.#{uncomp_image_ext}"
      hob["image"]["md5"] = `md5sum #{uncompressed_full_image_path}`.split[0]
    end

    # EC2 and Azure images are not compressed before they are uploaded.
    if not node[:rightimage][:cloud] =~ /ec2|azure/
      # Compressed MD5 sum.
      compressed_full_image_path = "#{target_raw_root}/#{image_name}.#{image_file_ext}"
      hob["image"]["compressed-md5"] = `md5sum #{compressed_full_image_path}`.split[0]
    end

    # Google adds its own kernel during image upload.
    if node[:rightimage][:cloud] == "google"
      # Make a note of that fact.
      hob["kernel"]["release"] = "GCE kernel injected at boot time."
      # Google also disables module loading.
      hob.delete("modules")
    end

    # Write full image's JSON matching image name.
    File.open("#{temp_root}/#{image_name}.js","w") do |f|
      f.write(JSON.pretty_generate(hob))
    end
  end
end


# Upload JSON files.
  # Base and Full cases. 

# Upload vars.
if (node[:rightimage][:build_mode] == "base")
  image_s3_path = "#{guest_platform}/#{guest_platform_version}/#{guest_arch}/#{timestamp[0..3]}"
  image_upload_bucket = node[:rightimage][:base_image_bucket]
elsif (node[:rightimage][:build_mode] == "full")
  image_s3_path = node[:rightimage][:hypervisor]+"/#{guest_platform}/#{guest_platform_version}"
  image_upload_bucket = "rightscale-"+node[:rightimage][:cloud]+"-dev"
end

# Base image case:

# Upload partitioned JSON file.
json_partitioned = "#{temp_root}/#{loopback_rootname(false)}.js"

rightimage_upload json_partitioned do
  provider "rightimage_upload_s3"
  only_if { node[:rightimage][:build_mode] == "base" }
  endpoint 's3-us-west-2.amazonaws.com'
  remote_path  "#{image_upload_bucket}/#{image_s3_path}"
  action :upload
end

# Upload unpartitioned JSON file.
json_unpartitioned = "#{temp_root}/#{loopback_rootname(true)}.js"

rightimage_upload json_unpartitioned do
  provider "rightimage_upload_s3"
  only_if { node[:rightimage][:build_mode] == "base" }
  endpoint 's3-us-west-2.amazonaws.com'
  remote_path  "#{image_upload_bucket}/#{image_s3_path}"
  action :upload
end

# Full image case:

json_full_image ="#{temp_root}/#{image_name}.js"

rightimage_upload json_full_image do
  provider "rightimage_upload_s3"
  only_if { node[:rightimage][:build_mode] == "full" }
  endpoint 's3-us-west-1.amazonaws.com'
  remote_path  "#{image_upload_bucket}/#{image_s3_path}"
  action :upload
end

rightscale_marker :end
