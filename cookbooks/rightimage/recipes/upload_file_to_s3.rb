bash "Upload file to S3" do
  environment ({ 'AWS_ACCESS_KEY_ID' => node[:rightimage][:aws_access_key_id_for_upload], 'AWS_SECRET_ACCESS_KEY' => node[:rightimage][:aws_secret_access_key_for_upload], 'AWS_CALLING_FORMAT' => 'SUBDOMAIN' })
  code <<-EOH
    # $AWS_ACCESS_KEY_ID - AWS Cred must be in your environment
    # $AWS_SECRET_ACCESS_KEY - AWS Cred must be in your environment
    # $BUCKET - s3 bucket to upload to
    # $FILE_TO_UPLOAD - path to the file to be uploaded

    export key=`basename #{node[:rightimage][:file_to_upload]}`
    s3cmd put #{node[:rightimage][:image_upload_bucket]}:$key #{node[:rightimage][:file_to_upload]} x-amz-acl:public-read
  EOH
end
