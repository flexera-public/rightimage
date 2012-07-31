rightscale_marker :begin
class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

# Inject md5 sum of compresseded images.
ruby_block "compressed_md5_checksum" do
  block do
    require 'json'

    # Open existing json file placed in /mnt/storage.
    hob = Hash.new
    File.open("#{target_raw_root}/#{loopback_filename}.js","r") do |f|
      hob = JSON.load(f)
    end

    #---

    # Helper md5 checksum function
    #hob["image"]["raw-md5"] = calc_md5sum("#{base_root}.raw.gz")

    # Inject the md5 sum.
    hob["image"]["raw-md5"] = `md5sum #{base_root}.raw.gz`.split[0]

    # Cop-out for testing
    #hob["image"]["raw-md5"] = "TEST FAST!"

    # Write back to unpartitioned json file.
    File.open("#{target_raw_root}/#{loopback_filename}.js","w") do |f|
      f.write(JSON.pretty_generate(hob))

    #---

    # Inject the md5 sum.
    hob["image"]["raw-md5"] = `md5sum #{base_root}0.raw.gz`.split[0]

    # Cop-out for testing
    #hob["image"]["raw-md5"] = "TEST FAST!"

    # Write to partitioned json file.
    File.open("#{target_raw_root}/#{loopback_filename}0.js","w") do |f|
      f.write(JSON.pretty_generate(hob))
    end
  end
end

bash "upload json blobs" do
  cwd build_root
  not_if {`curl -o /dev/null --head --connect-timeout 10 --fail --silent --write-out %{http_code} http://#{base_image_upload_bucket}.s3.amazonaws.com/#{s3_path_base}/#{target_type}.js`.strip == "200" }
  flags "-ex"
  environment(cloud_credentials("ec2"))
  code <<-EOH
    # Upload JSON
    s3cmd put #{base_image_upload_bucket}:#{s3_path_base}/#{target_type}.js #{target_raw_root}/#{target_type}.js x-amz-acl:public-read
    s3cmd put #{base_image_upload_bucket}:#{s3_path_base}/#{target_type}0.js #{target_raw_root}/#{target_type}0.js x-amz-acl:public-read
  EOH
end

rightscale_marker :end
