name             "rightimage_migrate"
maintainer       "RightScale, Inc."
maintainer_email "support@rightscale.com"
description      "A cookbook for migrating RightImages"
version          "14.0.2"
license          "Apache v2.0"

recipe "rightimage_migrate::default", "Migrate image"

ec2_regions = [ "us-east-1", "us-west-1", "us-west-2", "eu-west-1", "ap-southeast-1", "ap-southeast-2", "ap-northeast-1", "sa-east-1" ]

attribute "rightimage_migrate/aws_access_key_id",
  :display_name => "AWS Access Key ID",
  :description => "AWS Access Key ID",
  :required => "required"
  
attribute "rightimage_migrate/aws_secret_access_key",
  :display_name => "AWS Secret Access Key",
  :description => "AWS Secret Access Key",
  :required => "required"

attribute "rightimage_migrate/aws_509_cert",
  :display_name => "AWS x509 Cert",
  :description => "AWS x509 Cert, for instance store based images only",
  :required => "recommended"

attribute "rightimage_migrate/aws_509_key",
  :display_name => "AWS x509 Key",
  :description => "AWS x509 Key, for instance store based images only",
  :required => "recommended"

attribute "rightimage_migrate/destination_bucket",
  :display_name => "AWS S3 Destination Bucket",
  :description => "AWS S3 Destination Bucket, for instance store based images only",
  :required => "recommended"

attribute "rightimage_migrate/destination_region",
  :display_name => "Destination Region",
  :description => "Region to migrate to",
  :choice => ec2_regions,
  :required => "required"
  
attribute "rightimage_migrate/source_image",
  :display_name => "Source image name or ID",
  :description => "You may specify either an ami-id or an ec2 image name to migrate.",
  :required => "required"
  
attribute "rightimage_migrate/source_region",
  :display_name => "Source Region",
  :description => "Region to migrate from",
  :choice => ec2_regions,
  :required => "required"
