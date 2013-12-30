action :upload do
  file = new_resource.file
  bucket_name = new_resource.container
  s3_file = new_resource.remote_path.dup
  user = new_resource.user
  password = new_resource.password

  if s3_file =~ /\/$/
    s3_file << ::File.basename(file)
  end


  Chef::Log.info("bucket: #{bucket_name}")
  Chef::Log.info("remote_path: #{s3_file}")
  Chef::Log.info("file to upload: #{file}")

  ruby "Upload image to s3" do
    environment(
      'AWS_ACCESS_KEY_ID'=>user,
      'AWS_SECRET_ACCESS_KEY'=>password
    )
    timeout 10800
    code <<-EOF
      require 'rubygems'
      require 'fog'

      def connect_storage(region)
        Fog::Storage.new(
          :provider               => 'AWS',
          :region                 => region,
          :aws_access_key_id      => ENV['AWS_ACCESS_KEY_ID'],
          :aws_secret_access_key  => ENV['AWS_SECRET_ACCESS_KEY']
        )
      end

      s3_file = '#{s3_file}'
      bucket_name = '#{bucket_name}'
      file     = '#{file}'
      default_region = 'us-east-1' # must be us-east-1 else fog can't get bucket location for other regions

      storage = connect_storage(default_region)
      b = storage.directories.get(bucket_name)

      # Reconnect to the endpoint if its in a different region
      if b.location != default_region
        storage = connect_storage(b.location)
        b = storage.directories.get(bucket_name)
      end

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
