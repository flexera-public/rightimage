node[:test][:provider] = "S3"
node[:test][:username] = node[:test][:s3][:user]
node[:test][:password] = node[:test][:s3][:key]

include_recipe 'lvmros_test::common'
