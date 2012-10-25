
action :upload do
  require 'rubygems'
  require 'fog'
  file = new_resource.file
  path_bits = new_resource.remote_path.split("/",2)
  bucket_name = path_bits.shift
  s3_path = path_bits.shift || ""
  s3_file = s3_path.dup
  endpoint = new_resource.endpoint || 's3-us-west-1.amazonaws.com'
  md5sum = calc_md5sum(file)

  if s3_path =~ /./ && s3_path !~ /\/$/
    s3_file << "/"
  end
  s3_file << ::File.basename(file)

  Chef::Log.info("bucket: #{bucket_name}")
  Chef::Log.info("upload path: #{s3_path}")
  Chef::Log.info("file to upload: #{file}")
  Chef::Log.info("endpoint: #{endpoint}")
  Chef::Log.info("file md5sum #{md5sum}")

  Chef::Log.info("Init fog...")
  storage =
    Fog::Storage.new(
      :provider               => 'AWS',
      :host                   => endpoint,
      :aws_secret_access_key  => node[:rightimage][:aws_secret_access_key],
      :aws_access_key_id      => node[:rightimage][:aws_access_key_id],
      :persistent => false
  )

  Chef::Log.info("Get bucket #{bucket_name}...")  
  b = storage.directories.get(bucket_name)
  raise "ERROR: Bucket not found: #{bucket_name} -- please verify your image_upload_bucket and creds" unless b
  aws_file = b.files.find { |f| f.key == s3_file }
  if aws_file && aws_file.etag == md5sum
    Chef::Log.info("File #{s3_file} is already uploaded and md5sum matches, skipping upload")
  else
    if aws_file
      Chef::Log.warn("WARNING: image already uploaded but md5sum doesn't match: OVERWRITING!!")
    end

    Chef::Log::info('Initiating upload')
    created_file = b.files.create(
      :key    => s3_file,
      :body   => ::File.open(file),
      :public => true
    )

    Chef::Log::info('Checking the uploaded object')
    b = storage.directories.get(bucket_name)
    aws_file = b.files.find { |f| f.key == s3_file }
    raise "Could not find file [#{s3_file}] in bucket" unless aws_file
    Chef::Log::info(aws_file)
    raise "ETag[#{aws_file.etag}] and MD5[#{md5sum}] don't match" unless aws_file.etag.to_s == md5sum.to_s
  end
end
