action :upload do
  file = new_resource.file
  path_bits = new_resource.remote_path.split("/",2)
  bucket_name = path_bits.shift
  s3_path = path_bits.shift || ""
  s3_file = s3_path.dup
  endpoint = new_resource.endpoint || 's3-us-west-1.amazonaws.com'
  user = new_resource.user
  password = new_resource.password

  if s3_path =~ /./ && s3_path !~ /\/$/
    s3_file << "/"
  end
  s3_file << ::File.basename(file)

  Chef::Log.info("bucket: #{bucket_name}")
  Chef::Log.info("upload path: #{s3_path}")
  Chef::Log.info("file to upload: #{file}")
  Chef::Log.info("endpoint: #{endpoint}")

  ruby "Upload image to s3" do
    code <<-EOF
      require 'rubygems'
      require 'fog'

      s3_file = '#{s3_file}'
      bucket_name = '#{bucket_name}'
      file     = '#{file}'
      endpoint = '#{endpoint}'
      user     = '#{user}'
      password = '#{password}'

      storage =
        Fog::Storage.new(
          :provider               => 'AWS',
          :host                   => endpoint,
          :aws_access_key_id      => user,
          :aws_secret_access_key  => password,
          :persistent => false
      )

      b = storage.directories.get(bucket_name)
      raise "ERROR: Bucket not found: \#{bucket_name} -- please verify your image_upload_bucket and creds" unless b
      b.files.each { |f| puts "WARNING: image already exists -- OVERWRITING!!" if f.key == s3_file }

      puts 'Initiating upload'
      created_file = b.files.create(
        :key    => s3_file,
        :body   => ::File.open(file),
        :public => true
      )

      puts 'Checking the uploaded object'
      aws_file = storage.directories.get(bucket_name).files.find {|f| f.key == s3_file}
      md5sum = `md5sum \#{file}`.to_s.chomp.split[0]
      raise "Could not find file [\#{s3_file}] in bucket" unless aws_file
      puts aws_file
      raise "ETag[\#{aws_file.etag}] and MD5[\#{md5sum}] don't match" unless aws_file.etag.to_s == md5sum.to_s
    EOF
  end
end
