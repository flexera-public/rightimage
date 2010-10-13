maintainer       "RightScale, Inc."
maintainer_email "support@rightscale.com"
description      "image building tools"
version          "0.0.1"

recipe "right_image_creator::default", "build image based on host platform" 
recipe "right_image_creator::clean", "cleans everything" 
recipe "right_image_creator::do_ubuntu", "coordinate an ubuntu install" 
recipe "right_image_creator::do_centos", "coordinate a centos install" 
recipe "right_image_creator::do_sles", "coordinate a sles install" 
recipe "right_image_creator::bootstrap_ubuntu", "bootstraps a basic ubuntu image" 
recipe "right_image_creator::bootstrap_centos", "bootstraps a basic centos image" 
recipe "right_image_creator::bootstrap_sles", "bootstraps a basic sles image" 
recipe "right_image_creator::install_rightscale", "installs rightscale"
recipe "right_image_creator::do_ec2", "migrates the created image to ec2"
recipe "right_image_creator::do_euca", "migrates the created image to eucalyptus" 
recipe "right_image_creator::do_vmops", "migrates the created image to cloud.com" 
recipe "right_image_creator::install_vhd-util", "install the vhd-util tool"



#
# required
#
attribute "right_image_creator/platform",
  :display_name => "platform",
  :description => "the os of the image to build",
  :required => true
  
attribute "right_image_creator/release",
  :display_name => "release",
  :description => "the release of the image to build",
  :required => true
  
attribute "right_image_creator/arch",
  :display_name => "arch",
  :description => "the arch of the image to build",
  :required => true
  
attribute "right_image_creator/cloud",
  :display_name => "cloud",
  :description => "the cloud that the image will reside",
  :required => true
  
attribute "right_image_creator/region",
  :display_name => "region",
  :description => "the region that the image will reside",
  :required => true
  
attribute "right_image_creator/git_repo",
  :display_name => "git_repo",
  :description => "the git repo to checkout to build rightscale",
  :required => true
  
attribute "right_image_creator/rightscale_release",
  :display_name => "rightscale_release",
  :description => "the rightscale release of the image",
  :required => true
  
attribute "right_image_creator/image_upload_bucket",
  :display_name => "image_upload_bucket",
  :description => "the bucket to upload the image to",
  :required => "required",
  :recipes => [ "right_image_creator::do_euca" ,"right_image_creator::do_ec2" , "right_image_creator::do_centos" , "right_image_creator::do_ubuntu" , "right_image_creator::do_sles" , "right_image_creator::default" , "right_image_creator::do_vmops" ]
  
attribute "right_image_creator/image_prefix",
  :display_name => "image_prefix",
  :description => "an optional prefix for the image name",
  :required => "optional",
  :recipes => [ "right_image_creator::do_euca" ,"right_image_creator::do_ec2" , "right_image_creator::do_centos" , "right_image_creator::do_ubuntu" , "right_image_creator::do_sles" , "right_image_creator::default" , "right_image_creator::do_vmops" ]
  
attribute "right_image_creator/image_postfix",
  :display_name => "image_postfix",
  :description => "an optional postfix for the image name",
  :required => "optional",
  :recipes => [ "right_image_creator::do_euca" ,"right_image_creator::do_ec2" , "right_image_creator::do_centos" , "right_image_creator::do_ubuntu" , "right_image_creator::do_sles" , "right_image_creator::default" , "right_image_creator::do_vmops" ]
  
attribute "right_image_creator/image_name_override",
  :display_name => "Image Name Override",
  :description => "The image name is created automaticaaly.  Set this value if you want to override the default image name.",
  :required => "optional",
  :recipes => [ "right_image_creator::do_euca" ,"right_image_creator::do_ec2", "right_image_creator::default" , "right_image_creator::do_vmops" ]
  
attribute "right_image_creator/aws_account_number",
  :display_name => "aws_account_number",
  :description => "aws_account_number",
  :required => "required",
  :recipes => [ "right_image_creator::do_euca" ,"right_image_creator::do_ec2" , "right_image_creator::do_centos" , "right_image_creator::do_ubuntu" , "right_image_creator::do_sles" , "right_image_creator::default" , "right_image_creator::do_vmops" ]
  
attribute "right_image_creator/aws_access_key_id",
  :display_name => "aws_access_key_id",
  :description => "aws_access_key_id",
  :required => "required",
  :recipes => [ "right_image_creator::do_euca" ,"right_image_creator::do_ec2" , "right_image_creator::do_centos" , "right_image_creator::do_ubuntu" , "right_image_creator::do_sles" , "right_image_creator::default" , "right_image_creator::do_vmops" , "right_image_creator::do_vmops" ]
  
attribute "right_image_creator/aws_secret_access_key",
  :display_name => "aws_secret_access_key",
  :description => "aws_secret_access_key",
  :required => "required",
  :recipes => [ "right_image_creator::do_euca" ,"right_image_creator::do_ec2" , "right_image_creator::do_centos" , "right_image_creator::do_sles" , "right_image_creator::do_ubuntu" , "right_image_creator::default" , "right_image_creator::do_vmops" , "right_image_creator::do_vmops" ]
  
attribute "right_image_creator/aws_509_key",
  :display_name => "aws_509_key",
  :description => "aws_509_key",
  :required => "required",
  :recipes => [ "right_image_creator::do_euca" ,"right_image_creator::do_ec2" , "right_image_creator::do_centos" , "right_image_creator::do_sles" , "right_image_creator::do_ubuntu" , "right_image_creator::default" , "right_image_creator::do_vmops" ]
  
attribute "right_image_creator/aws_509_cert",
  :display_name => "aws_509_cert",
  :description => "aws_509_cert",
  :required => "required",
  :recipes => [ "right_image_creator::do_euca" ,"right_image_creator::do_ec2" , "right_image_creator::do_centos" , "right_image_creator::do_sles" , "right_image_creator::do_ubuntu" , "right_image_creator::default" , "right_image_creator::do_vmops" ]
 
attribute "right_image_creator/aws_access_key_id_for_upload",
  :display_name => "aws_access_key_id_for_upload",
  :description => "aws_access_key_id for the uplaod bucket",
  :required => "required",
  :recipes => [ "right_image_creator::do_euca" ,"right_image_creator::do_ec2" , "right_image_creator::do_centos" , "right_image_creator::do_sles" , "right_image_creator::do_ubuntu" , "right_image_creator::default" , "right_image_creator::do_vmops" ]
  
attribute "right_image_creator/aws_secret_access_key_for_upload",
  :display_name => "aws_secret_access_key_for_upload",
  :description => "aws_secret_access_key_for_upload",
  :required => "required",
  :recipes => [ "right_image_creator::do_euca" ,"right_image_creator::do_ec2" , "right_image_creator::do_centos" , "right_image_creator::do_sles" , "right_image_creator::do_ubuntu" , "right_image_creator::default" , "right_image_creator::do_vmops" ]


attribute "right_image_creator/debug",
  :display_name => "debug",
  :description => "toggles debug mode",
  :required => "optional",
  :recipes => [ "right_image_creator::do_centos" , "right_image_creator::do_sles" , "right_image_creator::do_ubuntu" , "right_image_creator::default" , "right_image_creator::bootstrap_centos" , "right_image_creator::bootstrap_sles" , "right_image_creator::bootstrap_ubuntu" ]


## euca inputs  
attribute "right_image_creator/euca/user",
  :display_name => "euca user",
  :description => "euca user",
  :required => "required",
  :recipes => [ "right_image_creator::do_euca" ]
  
attribute "right_image_creator/euca/walrus_url",
  :display_name => "walrus url",
  :description => "walrus url",
  :required => "required",
  :recipes => [ "right_image_creator::do_euca" ]

attribute "right_image_creator/euca/euca_url",
  :display_name => "euca url",
  :description => "euca url",
  :required => "required",
  :recipes => [ "right_image_creator::do_euca" ]

attribute "right_image_creator/euca/access_key_id",
  :display_name => "access key id",
  :description => "access key id",
  :required => "required",
  :recipes => [ "right_image_creator::do_euca" ]

attribute "right_image_creator/euca/secret_access_key",
  :display_name => "secret access key",
  :description => "secret access key",
  :required => "required",
  :recipes => [ "right_image_creator::do_euca" ]

attribute "right_image_creator/euca/user_admin",
  :display_name => "euca user admin",
  :description => "euca user for the admin acct",
  :required => "required",
  :recipes => [ "right_image_creator::do_euca" ]
  
attribute "right_image_creator/euca/access_key_id_admin",
  :display_name => "access key id admin acct",
  :description => "access key id for admin acct",
  :required => "required",
  :recipes => [ "right_image_creator::do_euca" ]

attribute "right_image_creator/euca/secret_access_key_admin",
  :display_name => "secret access key admin",
  :description => "secret access key for the admin acct",
  :required => "required",
  :recipes => [ "right_image_creator::do_euca" ]

attribute "right_image_creator/euca/x509_key_admin",
  :display_name => "x509 key admin",
  :description => "x509 key for the admin acct",
  :required => "required",
  :recipes => [ "right_image_creator::do_euca" ]

attribute "right_image_creator/euca/x509_cert_admin",
  :display_name => "x509 cert admin",
  :description => "x509 cert for the admin acct",
  :required => "required",
  :recipes => [ "right_image_creator::do_euca" ]

attribute "right_image_creator/euca/x509_key",
  :display_name => "x509 key ",
  :description => "x509 key ",
  :required => "required",
  :recipes => [ "right_image_creator::do_euca" ]

attribute "right_image_creator/euca/x509_cert",
  :display_name => "x509 cert ",
  :description => "x509 cert ",
  :required => "required",
  :recipes => [ "right_image_creator::do_euca" ]

attribute "right_image_creator/euca/euca_cert",
  :display_name => "euca cert",
  :description => "euca cert",
  :required => "required",
  :recipes => [ "right_image_creator::do_euca" ]

