class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

# Clean up guest image
rightimage node[:rightimage][:mount_dir] do
  action :sanitize
end

bash "serve /mnt via http" do
  code <<-EOH
    set -x
    yum -y install httpd
    rm /etc/httpd/conf.d/welcome*
    rm -rf /var/www/html
    ln -s /mnt /var/www/html
    service httpd start
  EOH
end

["libxml2-devel", "libxslt-devel"].each do |p| 
  r = package p do 
    action :nothing 
  end
  r.run_action(:install)
end

r = gem_package "right_aws" do
  gem_binary "/opt/rightscale/sandbox/bin/gem"
  action :nothing
end
r.run_action(:install)

r = gem_package "fog" do
  gem_binary "/opt/rightscale/sandbox/bin/gem"
  action :nothing
end
r.run_action(:install)
Gem.clear_paths

ruby_block "upload and index s3" do
  only_if { false }  #TODO: fix this
  block do
    require 'rubygems'
    require 'fog'
    
    s3_id = node[:rightimage][:aws_access_key_id_for_upload]
    s3_secret = node[:rightimage][:aws_secret_access_key_for_upload]
    
    env = { 
      "AWS_CALLING_FORMAT=SUBDOMAIN" => "SUBDOMAIN",
      "AWS_ACCESS_KEY_ID" => s3_id,
      "AWS_SECRET_ACCESS_KEY" => s3_secret
    }
    
    bucket_name = node[:rightimage][:image_upload_bucket]
    hypervisor = node[:rightimage][:virtual_environment]
    os = node[:rightimage][:platform]
    ver = node[:rightimage][:release]
    suffix = (hypervisor == "xen") ? "vhd.bz2" : "qcow2" 
    key = "#{hypervisor}/#{os}/#{ver}/#{image_name}.{suffix}"
    file = "/mnt/#{image_name}.#{suffix}"  
    cmd = "s3cmd put --progress #{bucket_name}:#{key} #{file} x-amz-acl:public-read"
    
    Chef::Log.info("Uploading to S3...")
    Chef::Log.info("key: #{key}")
    Chef::Log.info("file: #{file}")
#    Chef::Mixin::Command.run_command(:command => cmd, :environment => env)
#    s3 = RightAws::S3.new(s3_id, s3_secret)
#    b = s3.bucket(bucket_name)
#    raise "ERROR: Bucket not found: #{bucket_name} -- please verify your image_upload_bucket and creds" unless b
#    b.put(key, File.open(file), {}, 'public-read')

    Chef::Log.info("Init fog...")
    storage = 
      Fog::Storage.new(
        :provider               => 'AWS',
        :aws_secret_access_key  => s3_secret,
        :aws_access_key_id      => s3_id)
  
    Chef::Log.info("Get bucket #{bucket_name}...")  
    b = storage.directories.get(bucket_name)
    Chef::Log.info("Got bucket #{b.inspect}") 
    raise "ERROR: Bucket not found: #{bucket_name} -- please verify your image_upload_bucket and creds" unless b
    b.files.each { |f| Chef::Log.warn "WARNING: image already exists -- OVERWRITING!!" if f.key == key }
#    b.files.create(:key=>key, :public=>true, :body=>::File.open(file))
    
    puts "Splitting file..."
    `mkdir /mnt/parts ; cd /mnt/parts ; split -b 100m #{file}`
 
    puts 'Initiating multipart uploads'
    response = storage.initiate_multipart_upload bucket_name, key
    upload_id = response.body['UploadId']
    puts "Upload ID: #{upload_id}"
    
    parts = Dir.glob('/mnt/parts/*').sort
    part_ids = []
    parts.each_with_index do |part, position|
      part_number = (position + 1).to_s
      puts "Uploading #{part}"
      File.open part do |part_file|
        response = storage.upload_part bucket_name, key, upload_id, part_number, part_file
        part_ids << response.headers['ETag']
      end
    end
    
    puts "Parts' ETags: #{part_ids.inspect}", "\n\n"

    puts 'Pending multipart uploads'
    response = storage.list_multipart_uploads bucket_name
    puts response.inspect, "\n\n"

    puts 'Completing multipart upload'
    response = storage.complete_multipart_upload bucket_name, key, upload_id, part_ids
    puts response.inspect, "\n\n"

    puts 'Pending multipart uploads'
    response = storage.list_multipart_uploads bucket_name
    puts response.inspect, "\n\n"

    puts 'Checking the uploaded object'
    response = storage.directories.get(bucket_name).files.get(key)
    puts response.inspect, "\n\n"
    
    # Update index.html for s3 bucket
    indexer = RightImage::S3HtmlIndexer.new(bucket_name, s3_id, s3_secret)
    indexer.to_html("/tmp/index.html")
    indexer.upload_index("/tmp/index.html")
  end
end

include_recipe "rightimage::upload_vmops_#{node[:rightimage][:virtual_environment]}" 