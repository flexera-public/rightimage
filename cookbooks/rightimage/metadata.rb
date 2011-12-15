maintainer       "RightScale, Inc."
maintainer_email "support@rightscale.com"
description      "image building tools"
version          "0.0.1"

depends "block_device"

recipe "rightimage::default", "starts builds image automatically at boot. See 'manual_mode' input to enable." 
recipe "rightimage::build_image", "build image based on host platform"
recipe "rightimage::build_base", "build base image based on host platform"
recipe "rightimage::clean", "cleans everything" 
recipe "rightimage::base_ubuntu", "coordinate an ubuntu install" 
recipe "rightimage::base_centos", "coordinate a centos install" 
recipe "rightimage::base_sles", "coordinate a sles install"
recipe "rightimage::base_rhel", "coordinate a rhel install"
recipe "rightimage::bootstrap_ubuntu", "bootstraps a basic ubuntu image" 
recipe "rightimage::bootstrap_centos", "bootstraps a basic centos image" 
recipe "rightimage::bootstrap_sles", "bootstraps a basic sles image" 
recipe "rightimage::bootstrap_common", "common configuration for linux base images" 
recipe "rightimage::rightscale_install", "installs rightscale"
recipe "rightimage::cloud_add_ec2", "migrates the created image to ec2"
recipe "rightimage::cloud_add_euca", "migrates the created image to eucalyptus" 
recipe "rightimage::cloud_add_vmops", "adds requirements for cloudstack based on hypervisor choice"
recipe "rightimage::cloud_add_openstack", "adds requirements for openstack based on hypervisor choice"
recipe "rightimage::setup_loopback", "creates loopback file"
recipe "rightimage::do_destroy_loopback", "unmounts loopback file"
recipe "rightimage::install_vhd-util", "install the vhd-util tool"
recipe "rightimage::do_tag_images", "adds rightscale tags to images"
recipe "rightimage::do_create_mci", "creates MCI for image(s) (only ec2 currently supported)"
recipe "rightimage::upload_ec2_s3", "bundle and upload s3 image (ec2 only)"
recipe "rightimage::upload_ec2_ebs", "create EBS image snapshot (ec2 only)"
recipe "rightimage::upload_vmops", "setup http server for download to test cloud"
recipe "rightimage::upload_euca", "bundle and upload euca kernel, ramdisk and image"
recipe "rightimage::upload_openstack", "bundle and upload openstack kernel, ramdisk and image"
recipe "rightimage::upload_file_to_s3", "upload specified file to s3"
recipe "rightimage::base_upload", "compresses and uploads base image to s3"
recipe "rightimage::setup_or_restore", "setup block device (on base mode) or restore volume (on full mode)"

# Add each cloud name to an array to use for common inputs on each cloud.
cloud_add = []
cloud_upload = []

['euca', 'vmops', 'openstack'].each do |cloud|
  cloud_add << "rightimage::cloud_add_#{cloud}"
  cloud_upload << "rightimage::upload_#{cloud}"
end

cloud_add << "rightimage::cloud_add_ec2"
cloud_upload << "rightimage::upload_ec2_s3"
cloud_upload << "rightimage::upload_ec2_ebs"

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
attribute "rightimage/root_size_gb",
  :display_name => "Root Size GB",
  :description => "Sets the size of the virtual image. Units are in GB.",
  :choice => [ "10", "4", "2" ],
  :default => "10",
  :recipes => [ "rightimage::default", "rightimage::build_image" ] + cloud_add

attribute "rightimage/manual_mode",
  :display_name => "Manual Mode",
  :description => "Sets the template's operation mode. Ex. 'true' = don't build at boot time.",
  :choice => [ "true", "false" ],
  :default => "true",
  :recipes => [ "rightimage::default" ]

attribute "rightimage/build_mode",
  :display_name => "Build Mode",
  :description => "Build base or full image.",
  :required => true,
  :choice => [ "base", "full" ]

attribute "rightimage/platform",
  :display_name => "Guest OS Platform",
  :description => "The operating system for the virtual image.",
  :choice => [ "centos", "ubuntu", "suse", "rhel" ]
  
attribute "rightimage/release",
  :display_name => "Guest OS Release",
  :description => "The OS release/version to build into the virtual image.",
  :choice => [ "5.4", "5.6", "lucid", "maverick" ]
  
attribute "rightimage/arch",
  :display_name => "Guest OS Architecture",
  :description => "The architecture for the virtual image.",
  :choice => [ "i386", "x86_64" ]
  
attribute "rightimage/cloud",
  :display_name => "Target Cloud",
  :description => "The supported cloud for the virtual image.",
  :choice => [ "ec2", "vmops", "euca", "openstack", "rackspace" ],
  :required => true
  
attribute "rightimage/region",
  :display_name => "EC2 Region",
  :description => "The EC2 region in which the image will reside",
  :choice => [ "us-east", "us-west", "eu-west", "ap-southeast", "ap-northeast" ],
  :required => true
  
attribute "rightimage/sandbox_repo_tag",
  :display_name => "Sandbox Repository Tag",
  :description => "The tag on the sandbox_builds repo from which to build rightscale package.",
  :required => "optional"
  
attribute "rightimage/rightlink_version",
  :display_name => "RightLink Version",
  :description => "The RightLink version we are building into our image",
  :required => true
  
attribute "rightimage/image_upload_bucket",
  :display_name => "Image Upload Bucket",
  :description => "The bucket to upload the image to.",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_ec2", "rightimage::do_tag_images" , "rightimage::do_create_mci" , "rightimage::base_centos" , "rightimage::base_ubuntu" , "rightimage::base_sles" , "rightimage::default", "rightimage::build_image" , "rightimage::upload_file_to_s3" ] + cloud_upload

attribute "rightimage/file_to_upload",
  :display_name => "File To Upload",
  :description => "The absolute pathname of the file to upload to S3.",
  :required => "required",
  :recipes => [ "rightimage::upload_file_to_s3" ]

attribute "rightimage/image_name",
   :display_name => "Image Name",
   :description => "The name you want to give this new image.",
   :required => "required"

attribute "rightimage/download_rightlink",
  :display_name => "Should RightLink be downloaded?",
  :description => "Set to true to download RighLink form S3.  This recipe will fail if the expected version of RightLink is not in either of the dev or production buckets.",
  :choice => [ "yes", "no" ],
  :required => "required",
  :recipes => [ "rightimage::rightscale_install" ]

attribute "rightimage/rebundle_base_image_id",
  :display_name => "Starting Image Id",
  :description => "Cloud specific ID for the image to start with when building a rebundle image",
  :required => "required",
  :recipes => [ "rightimage::base_rhel" ]

attribute "rightimage/aws_account_number",
  :display_name => "aws_account_number",
  :description => "aws_account_number",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_ec2", "rightimage::upload_ec2_s3", "rightimage::upload_ec2_ebs", "rightimage::do_tag_images" , "rightimage::do_create_mci" , "rightimage::base_centos" , "rightimage::base_ubuntu" , "rightimage::base_sles" , "rightimage::default", "rightimage::build_image" , "rightimage::cloud_add_vmops", "rightimage::cloud_add_openstack" ]
  
attribute "rightimage/aws_access_key_id",
  :display_name => "aws_access_key_id",
  :description => "aws_access_key_id",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_ec2", "rightimage::upload_ec2_s3", "rightimage::upload_ec2_ebs", "rightimage::do_tag_images" , "rightimage::do_create_mci" , "rightimage::base_centos" , "rightimage::base_ubuntu" , "rightimage::base_sles", "rightimage::base_rhel" , "rightimage::default", "rightimage::build_image" , "rightimage::cloud_add_vmops", "rightimage::cloud_add_openstack", "rightimage::base_upload" ]
  
attribute "rightimage/aws_secret_access_key",
  :display_name => "aws_secret_access_key",
  :description => "aws_secret_access_key",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_ec2", "rightimage::upload_ec2_s3", "rightimage::upload_ec2_ebs", "rightimage::do_tag_images" , "rightimage::do_create_mci" , "rightimage::base_centos" , "rightimage::base_sles" , "rightimage::base_ubuntu", "rightimage::base_rhel" , "rightimage::default", "rightimage::build_image" , "rightimage::cloud_add_vmops", "rightimage::cloud_add_openstack", "rightimage::base_upload" ]
  
attribute "rightimage/aws_509_key",
  :display_name => "aws_509_key",
  :description => "aws_509_key",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_ec2", "rightimage::upload_ec2_s3", "rightimage::upload_ec2_ebs", "rightimage::do_tag_images" , "rightimage::do_create_mci" , "rightimage::base_centos" , "rightimage::base_sles" , "rightimage::base_ubuntu" , "rightimage::default", "rightimage::build_image" ]
  
attribute "rightimage/aws_509_cert",
  :display_name => "aws_509_cert",
  :description => "aws_509_cert",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_ec2", "rightimage::upload_ec2_s3", "rightimage::upload_ec2_ebs", "rightimage::do_tag_images" , "rightimage::do_create_mci" , "rightimage::base_centos" , "rightimage::base_sles" , "rightimage::base_ubuntu" , "rightimage::default", "rightimage::build_image" ]
 
attribute "rightimage/aws_access_key_id_for_upload",
  :display_name => "aws_access_key_id_for_upload",
  :description => "aws_access_key_id for the uplaod bucket",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_ec2", "rightimage::upload_ec2_s3", "rightimage::upload_ec2_ebs", "rightimage::do_tag_images" , "rightimage::do_create_mci" , "rightimage::base_centos" , "rightimage::base_sles" , "rightimage::base_ubuntu", "rightimage::base_rhel" , "rightimage::default", "rightimage::build_image" , "rightimage::upload_vmops", "rightimage::upload_file_to_s3" ]
  
attribute "rightimage/aws_secret_access_key_for_upload",
  :display_name => "aws_secret_access_key_for_upload",
  :description => "aws_secret_access_key_for_upload",
  :required => "required",
  :recipes => [ "rightimage::cloud_add_ec2", "rightimage::upload_ec2_s3", "rightimage::upload_ec2_ebs", "rightimage::do_tag_images" , "rightimage::do_create_mci" , "rightimage::base_centos" , "rightimage::base_sles" , "rightimage::base_ubuntu", "rightimage::base_rhel" , "rightimage::default", "rightimage::build_image" , "rightimage::upload_vmops", "rightimage::upload_file_to_s3" ]

attribute "rightimage/debug",
  :display_name => "Development Image?",
  :description => "If set, a random root password will be set for debugging purposes. NOTE: you must include 'Dev' in the image name or the build with fail.",
  :choice => [ "true", "false" ],
  :required => "optional",
  :recipes => [ "rightimage::base_centos" , "rightimage::base_sles" , "rightimage::base_ubuntu", "rightimage::base_rhel" , "rightimage::default", "rightimage::build_image" , "rightimage::bootstrap_centos" , "rightimage::bootstrap_sles" , "rightimage::bootstrap_ubuntu"] + cloud_add + cloud_upload

attribute "rightimage/install_mirror_date",
  :display_name => "Mirror Freeze Date",
  :description => "Repository archive date from which to pull packages. Default: latest",
  :required => "optional",
  :recipes => [ "rightimage::base_centos" , "rightimage::default", "rightimage::build_image", "rightimage::build_base", "rightimage::bootstrap_centos" ]

attribute "rightimage/virtual_environment",
  :display_name => "Hypervisor",
  :description => "Which hypervisor is this image for?",
  :choice => [ "xen", "kvm", "esxi" ],
  :required => "required"

## euca inputs  
attribute "rightimage/euca/user_id",
  :display_name => "Eucalyptus User ID",
  :description => "The EC2_USER_ID value defined in your eucarc credentials file. User must have admin privileges.",
  :required => "required",
  :recipes => [ "rightimage::upload_euca" ]
  
attribute "rightimage/euca/euca_url",
  :display_name => "Eucalyptus URL",
  :description => "Base URL to your Eucalyptus Cloud Controller. Don't include port. (Ex. http://<server_ip>)",
  :required => "required",
  :recipes => [ "rightimage::upload_euca" ]

attribute "rightimage/euca/access_key_id",
  :display_name => "Eucalyptus Access Key",
  :description => "The EC2_ACCESS_KEY value defined in your eucarc credentials file. User must have admin privileges.",
  :required => "required",
  :recipes => [ "rightimage::upload_euca" ]

attribute "rightimage/euca/secret_access_key",
  :display_name => "Eucalyptus Secret Access Key",
  :description => "The EC2_SECRET_KEY value defined in your eucarc credentials file. User must have admin privileges.",
  :required => "required",
  :recipes => [ "rightimage::upload_euca" ]

attribute "rightimage/euca/x509_key",
  :display_name => "Eucalyptus x509 Private Key",
  :description => "The contents of the file pointed to by the EC2_PRIVATE_KEY value defined in your eucarc credentials file.",
  :required => "required",
  :recipes => [ "rightimage::upload_euca" ]

attribute "rightimage/euca/x509_cert",
  :display_name => "Eucalyptus x509 Certificate",
  :description => "The contents of the file pointed to by the EC2_CERT value defined in your eucarc credentials file.",
  :required => "required",
  :recipes => [ "rightimage::upload_euca" ]

attribute "rightimage/euca/euca_cert",
  :display_name => "Eucalyptus Cloud Certificate",
  :description => "The contents of the file pointed to by the EUCALYPTUS_CERT value defined in your eucarc credentials file.",
  :required => "required",
  :recipes => [ "rightimage::upload_euca" ]

attribute "rightimage/openstack/hostname",
  :display_name => "Openstack Hostname",
  :description => "Hostname of Openstack Cloud Controller.",
  :required => "required",
  :recipes => [ "rightimage::upload_openstack" ]
