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

# Create vars
image_s3_path = guest_platform+"/"+guest_platform_version+"/"+guest_arch+"/"+timestamp[0..3]
# Switch after testing:
image_upload_bucket = node[:rightimage][:base_image_bucket]

bash "upload_json_reports" do
  cwd temp_root
  flags "-ex"
  environment(cloud_credentials("ec2"))
  code <<-EOH
    s3cmd put #{image_upload_bucket}:#{image_s3_path}/#{loopback_filename(false)}.js #{loopback_filename(false)}.js x-amz-acl:public-read
    s3cmd put #{image_upload_bucket}:#{image_s3_path}/#{loopback_filename(true)}.js #{loopback_filename(true)}.js x-amz-acl:public-read
  EOH
end

rightscale_marker :end
