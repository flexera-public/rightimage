class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

bash "sanity check" do
  flags "-x"
  code <<-EOH
    code=$(curl -o /dev/null --head --connect-timeout 10 --fail --silent --write-out %{http_code} http://rightscale-rightimage-base-dev.s3.amazonaws.com/#{s3_path})
    ret=$?

    case "$code" in
    "200")
      echo "File already exists"
      exit 1
      ;;
    "403"|"404")
      exit 0
      ;;
    *)
      echo "Curl returned: $ret; HTTP error code: $code"
      exit $ret
      ;;
    esac
  EOH
end

bash "compress base image" do
  cwd target_raw_root
  flags "-ex"
  code <<-EOH
    target_raw_file=#{target_raw_file}
    target_raw_zip_path=#{target_raw_zip_path}

    tar czvf $target_raw_zip_path $target_raw_file
  EOH
end

bash "upload base image" do
  environment ({ 'AWS_ACCESS_KEY_ID' => node[:rightimage][:aws_access_key_id], 'AWS_SECRET_ACCESS_KEY' => node[:rightimage][:aws_secret_access_key], 'AWS_CALLING_FORMAT' => 'SUBDOMAIN' })
  flags "-ex"
  code <<-EOH
    s3cmd put rightscale-rightimage-base-dev:#{s3_path} #{target_raw_zip_path} x-amz-acl:public-read
  EOH
end
