maintainer       "RightScale, Inc."
maintainer_email "support@rightscale.com"
description      "image building tools"
version          "0.0.1"

recipe "rightimage::default", "starts builds image automatically at boot. See 'manual_mode' input to enable." 
recipe "rightimage::build_image", "build image based on host platform"
recipe "rightimage::clean", "cleans everything" 
recipe "rightimage::base_ubuntu", "coordinate an ubuntu install" 
recipe "rightimage::base_centos", "coordinate a centos install" 
recipe "rightimage::base_sles", "coordinate a sles install" 
recipe "rightimage::bootstrap_ubuntu", "bootstraps a basic ubuntu image" 
recipe "rightimage::bootstrap_centos", "bootstraps a basic centos image" 
recipe "rightimage::bootstrap_sles", "bootstraps a basic sles image" 
recipe "rightimage::bootstrap_common", "common configuration for linux base images" 
recipe "rightimage::rightscale_install", "installs rightscale"
recipe "rightimage::cloud_add_ec2", "migrates the created image to ec2"
recipe "rightimage::cloud_add_euca", "migrates the created image to eucalyptus" 
recipe "rightimage::cloud_add_vmops", "adds requirements for cloudstack based on hypervisor choice"
recipe "rightimage::cloud_add_raw", "migrates the create image to a raw file -- useful for new cloud development"
recipe "rightimage::install_vhd-util", "install the vhd-util tool"
recipe "rightimage::do_tag_images", "adds rightscale tags to images"
recipe "rightimage::do_create_mci", "creates MCI for image(s) (only ec2 currently supported)"
recipe "rightimage::upload_ec2_s3", "bundle and upload s3 image (ec2 only)"
recipe "rightimage::upload_ec2_ebs", "create EBS image snapshot (ec2 only)"
recipe "rightimage::upload_vmops", "setup http server for download to test cloud"


attribute "rest_connection/user",
  :display_name => "API User",
  :description => "RightScale API username. Ex. you@rightscale.com",
  :required => true

attribute "rest_connection/pass",
  :display_name => "API Password",
  :description => "Rightscale API password.",
  :required => true
 
attribute "rest_connection/api_url",
  :display_name => "API URL",
  :description => "The rightscale account specific api url to use.  Ex. https://my.rightscale.com/api/acct/1234 (where 1234 is your account id)",
  :required => true

#
# required
#
attribute "rightimage/manual_mode",
  :display_name => "Manual Mode",
  :description => "Sets the template's operation mode. Ex. 'true' = don't build at boot time.",
  :default => "true",
  :recipes => [ "rightimage::default" ]

attribute "rightimage/platform",
  :display_name => "platform",
  :description => "the os of the image to build",
  :required => true
  
attribute "rightimage/release",
  :display_name => "release",
  :description => "the release of the image to build",
  :required => true
  
attribute "rightimage/arch",
  :display_name => "arch",
  :description => "the arch of the image to build",
  :required => true
  
attribute "rightimage/cloud",
  :display_name => "cloud",
  :description => "the cloud that the image will reside",
  :required => true
  
attribute "rightimage/region",
  :display_name => "region",
  :description => "the region that the image will reside",
  :required => true
  
attribute "rightimage/sandbox_repo_tag",
  :display_name => "sandbox_repo_tag",
  :description => "The tag on the sandbox repo from which to build rightscale package",
  :required => true
  
attribute "rightimage/rightlink_version",
  :display_name => "rightlink_version",
  :description => "The RightLink version we are building into our image",
  :required => true
  
attribute "rightimage/image_upload_bucket",
  :display_name => "image_upload_bucket",
  :description => "the bucket to upload the image to",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_euca" ,"rightimage::cloud_add_ec2", "rightimage::upload_ec2_s3", "rightimage::upload_ec2_ebs", "rightimage::do_tag_images" , "rightimage::do_create_mci" , "rightimage::base_centos" , "rightimage::base_ubuntu" , "rightimage::base_sles" , "rightimage::default", "rightimage::build_image" , "rightimage::upload_vmops" ]
  
attribute "rightimage/image_prefix",
  :display_name => "image_prefix",
  :description => "an optional prefix for the image name",
  :required => "optional",
  :recipes => [ "rightimage::cloud_add_euca" ,"rightimage::cloud_add_ec2", "rightimage::upload_ec2_s3", "rightimage::upload_ec2_ebs", "rightimage::do_tag_images" , "rightimage::do_create_mci" , "rightimage::base_centos" , "rightimage::base_ubuntu" , "rightimage::base_sles" , "rightimage::default", "rightimage::build_image" , "rightimage::cloud_add_vmops" ]
  
attribute "rightimage/image_postfix",
  :display_name => "image_postfix",
  :description => "an optional postfix for the image name",
  :required => "optional",
  :recipes => [ "rightimage::cloud_add_euca" ,"rightimage::cloud_add_ec2", "rightimage::upload_ec2_s3", "rightimage::upload_ec2_ebs", "rightimage::do_tag_images" , "rightimage::do_create_mci" , "rightimage::base_centos" , "rightimage::base_ubuntu" , "rightimage::base_sles" , "rightimage::default", "rightimage::build_image" , "rightimage::cloud_add_vmops" ]
  
attribute "rightimage/image_name_override",
  :display_name => "Image Name Override",
  :description => "The image name is created automaticaaly.  Set this value if you want to override the default image name.",
  :required => "optional"
  
attribute "rightimage/aws_account_number",
  :display_name => "aws_account_number",
  :description => "aws_account_number",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_euca" ,"rightimage::cloud_add_ec2", "rightimage::upload_ec2_s3", "rightimage::upload_ec2_ebs", "rightimage::do_tag_images" , "rightimage::do_create_mci" , "rightimage::base_centos" , "rightimage::base_ubuntu" , "rightimage::base_sles" , "rightimage::default", "rightimage::build_image" , "rightimage::cloud_add_vmops" ]
  
attribute "rightimage/aws_access_key_id",
  :display_name => "aws_access_key_id",
  :description => "aws_access_key_id",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_euca" ,"rightimage::cloud_add_ec2", "rightimage::upload_ec2_s3", "rightimage::upload_ec2_ebs", "rightimage::do_tag_images" , "rightimage::do_create_mci" , "rightimage::base_centos" , "rightimage::base_ubuntu" , "rightimage::base_sles" , "rightimage::default", "rightimage::build_image" , "rightimage::cloud_add_vmops" ]
  
attribute "rightimage/aws_secret_access_key",
  :display_name => "aws_secret_access_key",
  :description => "aws_secret_access_key",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_euca" ,"rightimage::cloud_add_ec2", "rightimage::upload_ec2_s3", "rightimage::upload_ec2_ebs", "rightimage::do_tag_images" , "rightimage::do_create_mci" , "rightimage::base_centos" , "rightimage::base_sles" , "rightimage::base_ubuntu" , "rightimage::default", "rightimage::build_image" , "rightimage::cloud_add_vmops"  ]
  
attribute "rightimage/aws_509_key",
  :display_name => "aws_509_key",
  :description => "aws_509_key",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_euca" ,"rightimage::cloud_add_ec2", "rightimage::upload_ec2_s3", "rightimage::upload_ec2_ebs", "rightimage::do_tag_images" , "rightimage::do_create_mci" , "rightimage::base_centos" , "rightimage::base_sles" , "rightimage::base_ubuntu" , "rightimage::default", "rightimage::build_image" ]
  
attribute "rightimage/aws_509_cert",
  :display_name => "aws_509_cert",
  :description => "aws_509_cert",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_euca" ,"rightimage::cloud_add_ec2", "rightimage::upload_ec2_s3", "rightimage::upload_ec2_ebs", "rightimage::do_tag_images" , "rightimage::do_create_mci" , "rightimage::base_centos" , "rightimage::base_sles" , "rightimage::base_ubuntu" , "rightimage::default", "rightimage::build_image" ]
 
attribute "rightimage/aws_access_key_id_for_upload",
  :display_name => "aws_access_key_id_for_upload",
  :description => "aws_access_key_id for the uplaod bucket",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_euca" ,"rightimage::cloud_add_ec2", "rightimage::upload_ec2_s3", "rightimage::upload_ec2_ebs", "rightimage::do_tag_images" , "rightimage::do_create_mci" , "rightimage::base_centos" , "rightimage::base_sles" , "rightimage::base_ubuntu" , "rightimage::default", "rightimage::build_image" , "rightimage::upload_vmops" ]
  
attribute "rightimage/aws_secret_access_key_for_upload",
  :display_name => "aws_secret_access_key_for_upload",
  :description => "aws_secret_access_key_for_upload",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_euca" ,"rightimage::cloud_add_ec2", "rightimage::upload_ec2_s3", "rightimage::upload_ec2_ebs", "rightimage::do_tag_images" , "rightimage::do_create_mci" , "rightimage::base_centos" , "rightimage::base_sles" , "rightimage::base_ubuntu" , "rightimage::default", "rightimage::build_image" , "rightimage::upload_vmops" ]

attribute "rightimage/debug",
  :display_name => "debug",
  :description => "toggles debug mode",
  :required => "optional",
  :recipes => [ "rightimage::base_centos" , "rightimage::base_sles" , "rightimage::base_ubuntu" , "rightimage::default", "rightimage::build_image" , "rightimage::bootstrap_centos" , "rightimage::bootstrap_sles" , "rightimage::bootstrap_ubuntu" ]

attribute "rightimage/install_mirror_date",
  :display_name => "install_mirror_date",
  :description => "date to install from",
  :required => "optional",
  :recipes => [ "rightimage::base_centos" , "rightimage::default", "rightimage::build_image" , "rightimage::bootstrap_centos" ]

attribute "rightimage/virtual_environment",
  :display_name => "Hypervisor",
  :description => "Which hypervisor is this image for? ['xen'|'kvm']",
  :required => "optional",
  :default => "xen"

## euca inputs  
attribute "rightimage/euca/user",
  :display_name => "euca user",
  :description => "euca user",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_euca" ]
  
attribute "rightimage/euca/walrus_url",
  :display_name => "walrus url",
  :description => "walrus url",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_euca" ]

attribute "rightimage/euca/euca_url",
  :display_name => "euca url",
  :description => "euca url",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_euca" ]

attribute "rightimage/euca/access_key_id",
  :display_name => "access key id",
  :description => "access key id",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_euca" ]

attribute "rightimage/euca/secret_access_key",
  :display_name => "secret access key",
  :description => "secret access key",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_euca" ]

attribute "rightimage/euca/user_admin",
  :display_name => "euca user admin",
  :description => "euca user for the admin acct",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_euca" ]
  
attribute "rightimage/euca/access_key_id_admin",
  :display_name => "access key id admin acct",
  :description => "access key id for admin acct",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_euca" ]

attribute "rightimage/euca/secret_access_key_admin",
  :display_name => "secret access key admin",
  :description => "secret access key for the admin acct",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_euca" ]

attribute "rightimage/euca/x509_key_admin",
  :display_name => "x509 key admin",
  :description => "x509 key for the admin acct",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_euca" ]

attribute "rightimage/euca/x509_cert_admin",
  :display_name => "x509 cert admin",
  :description => "x509 cert for the admin acct",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_euca" ]

attribute "rightimage/euca/x509_key",
  :display_name => "x509 key ",
  :description => "x509 key ",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_euca" ]

attribute "rightimage/euca/x509_cert",
  :display_name => "x509 cert ",
  :description => "x509 cert ",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_euca" ]

attribute "rightimage/euca/euca_cert",
  :display_name => "euca cert",
  :description => "euca cert",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_euca" ]

