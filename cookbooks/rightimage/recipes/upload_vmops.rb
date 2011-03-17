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

r = gem_package "right_aws" do
  gem_binary "/opt/rightscale/sandbox/bin/gem"
  action :nothing
end
r.run_action(:install)
Gem.clear_paths

#TODO: Refactor this stanza as a LWRP?
ruby_block "upload and index s3" do
  block do
    require 'rubygems'
    require 'right_aws'
    
    s3_id = node[:rightimage][:aws_access_key_id_for_upload]
    s3_secret = node[:rightimage][:aws_secret_access_key_for_upload]
    
    env = { 
      "AWS_CALLING_FORMAT=SUBDOMAIN" => "SUBDOMAIN",
      "AWS_ACCESS_KEY_ID" => s3_id,
      "AWS_SECRET_ACCESS_KEY" => s3_secret
    }
    
    bucket = node[:rightimage][:image_upload_bucket]
    hypervisor = node[:rightimage][:virtual_environment]
    os = node[:rightimage][:platform]
    ver = node[:rightimage][:release]
    suffix = (hypervisor == "xen") ? "vhd.bz2" : "qcow2" 
    key = "#{hypervisor}/#{os}/#{ver}/#{image_name}.{suffix}"
    file = "/mnt/#{image_name}.#{suffix}"  
    cmd = "s3cmd put --progress #{bucket}:#{key} #{file} x-amz-acl:public-read"
    
    Chef::Log.info("Uploading to S3...")
    Chef::Log.info("CMD: #{cmd}")
    Chef::Log.info("ENV: #{env.inspect}")
#    Chef::Mixin::Command.run_command(:command => cmd, :environment => env)
    s3 = RightAws::S3.new(s3_id, s3_secret)
    b = s3.bucket(bucket)
    raise "ERROR: Bucket not found: #{bucket} -- please verify your image_upload_bucket and creds" unless b
#    b.put(key, File.open(file), {}, 'public-read')

    # Update index.html for s3 bucket
    indexer = RightImage::S3HtmlIndexer.new(bucket, s3_id, s3_secret)
    indexer.to_html("/tmp/index.html")
    indexer.upload_index("/tmp/index.html")
  end
end

include_recipe "rightimage::upload_vmops_#{node[:rightimage][:virtual_environment]}" 