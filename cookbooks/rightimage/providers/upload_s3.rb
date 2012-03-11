class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

action :upload do
#  part_dir = "/mnt/parts"

#  directory part_dir do
#    action :delete
#    recursive true
#  end

#  directory part_dir do
#    action :create
#  end

  ruby_block "Upload image to s3" do
    file = new_resource.image_location
    bucket_name = new_resource.bucket
    s3_path = new_resource.s3_path
    s3_path += "/" if s3_path !~ /\/$/
    s3_file = s3_path + ::File.basename(file)

    Chef::Log.info("bucket: #{bucket_name}")
    Chef::Log.info("s3_path: #{s3_path}")
    Chef::Log.info("file to upload: #{file}")

    block do 
      require 'rubygems'
      require 'fog'
      Chef::Log.info("Init fog...")
      storage = 
        Fog::Storage.new(
          :provider               => 'AWS',
          :host                   => 's3-us-west-1.amazonaws.com',
          :aws_secret_access_key  => node[:rightimage][:aws_secret_access_key],
          :aws_access_key_id      => node[:rightimage][:aws_access_key_id],
          :persistent => false
      )

      Chef::Log.info("Get bucket #{bucket_name}...")  
      b = storage.directories.get(bucket_name)
      raise "ERROR: Bucket not found: #{bucket_name} -- please verify your image_upload_bucket and creds" unless b
      b.files.each { |f| Chef::Log.warn "WARNING: image already exists -- OVERWRITING!!" if f.key == s3_file }
      
#      Chef::Log::info("Splitting file...")
#      `cd #{part_dir} && split -b 100m #{file}`
   
      Chef::Log::info('Initiating upload')
      file = b.files.create(
        :key    => s3_file,
        :body   => ::File.open(file),
        :public => true
      )

#      Chef::Log::info('Initiating multipart uploads')
#
#      response = storage.initiate_multipart_upload(bucket_name, s3_file, { 'x-amz-acl' => 'public-read' })
#      upload_id = response.body['UploadId']
#      Chef::Log::info("Upload ID: #{upload_id}")
#      
#      parts = Dir.glob("#{part_dir}/*").sort
#      part_ids = []
#      parts.each_with_index do |part, position|
#        part_number = (position + 1).to_s
#        Chef::Log::info("Uploading #{part}")
#        ::File.open part do |part_file|
#          response = storage.upload_part bucket_name, s3_file, upload_id, part_number, part_file
#          part_ids << response.headers['ETag']
#          Chef::Log::info(response.inspect)
#        end
#      end
#      
#      Chef::Log::info("Parts' ETags: #{part_ids.inspect}")
#
#      Chef::Log::info('Pending multipart uploads')
#      response = storage.list_multipart_uploads bucket_name
#      Chef::Log::info(response.inspect)
#
#      Chef::Log::info('Completing multipart upload')
#      response = storage.complete_multipart_upload bucket_name, s3_file, upload_id, part_ids
#      Chef::Log::info(response.inspect)
#
#      Chef::Log::info('Pending multipart uploads')
#      response = storage.list_multipart_uploads bucket_name
#      Chef::Log::info(response.inspect)
#
#      Chef::Log::info('Checking the uploaded object')
#      response = storage.directories.get(bucket_name).files.get(s3_file)
#      Chef::Log::info(response.inspect)
    end
  end
end
      
