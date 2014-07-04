maintainer       "RightScale, Inc."
maintainer_email "support@rightscale.com"
name             "rightimage"
description      "A cookbook for building RightImages"
version          "14.1.0"
license          "Apache v2.0"

depends "ros_upload"
depends "rightimage_tester"
depends "loopback_fs"
depends "rightscale"
depends "rightscale_volume"

depends "rightimage_cloud_vagrant"

recipe "rightimage::default", "starts builds image automatically at boot. See 'manual_mode' input to enable." 
recipe "rightimage::build_image", "build image based on host platform"
recipe "rightimage::build_base", "build base image based on host platform"
recipe "rightimage::clean", "cleans everything" 
recipe "rightimage::rebundle", "coordinate a rebundled image build (redhat on on ec2 or rackspace)"
recipe "rightimage::base_os", "build a base image"
recipe "rightimage::enable_debug", "enables a root login on image for debugging purposes"
recipe "rightimage::rightscale_rightlink", "installs rightlink"
recipe "rightimage::rightscale_install", "sets up rightscale specific customizations, then installs rightlink"
recipe "rightimage::cloud_add", "configures base os image for a specific cloud"
recipe "rightimage::cloud_package", "packages RightImage for a specific cloud"
recipe "rightimage::cloud_upload", "upload and register image with cloud"
recipe "rightimage::upload_image_s3", "bundle and upload private cloud image to s3 bucket for distribution/download"
recipe "rightimage::base_upload", "upload raw image to s3"
recipe "rightimage::ec2_download_bundle","Downloads bundled image from EC2 S3."
recipe "rightimage::image_tests", "run some basic tests on mounted image such as grepping for credentials"

# Loopback filesystem recipes
recipe "rightimage::loopback_create", "creates and mounts loopback file system"
recipe "rightimage::loopback_copy", "creates non-partitioned loopback fs image from a partitioned one"
recipe "rightimage::loopback_download", "downloads base loopback image"
recipe "rightimage::loopback_unmount", "unmounts loopback file system"
recipe "rightimage::loopback_mount", "mounts loopback file system"
recipe "rightimage::loopback_resize", "resizes loopback file system"

recipe "rightimage::volume_create", "creates and attaches a volume"
recipe "rightimage::volume_destroy", "detatches and deletes a volume"

#
# required
#
attribute "rightimage/root_size_gb",
  :display_name => "Root Size GB",
  :description => "Sets the size of the virtual image. Units are in GB.",
  :default => "10",
  :recipes => [ "rightimage::default", "rightimage::build_base", "rightimage::build_image", "rightimage::loopback_copy", "rightimage::loopback_resize", "rightimage::loopback_mount", "rightimage::loopback_create", "rightimage::cloud_add", "rightimage::cloud_upload", "rightimage::cloud_package", "rightimage::rebundle" ]

attribute "rightimage/manual_mode",
  :display_name => "Manual Mode",
  :description => "Sets the template's operation mode. Ex. 'true' = don't build at boot time.",
  :choice => [ "true", "false" ],
  :default => "true",
  :recipes => [ "rightimage::default" ]

attribute "rightimage/build_mode",
  :display_name => "Build Mode",
  :description => "Build base image or full image.",
  :required => "required",
  :choice => [ "base", "full" ]

attribute "rightimage/platform",
  :display_name => "Guest OS Platform",
  :description => "The operating system for the virtual image.",
  :choice => [ "centos", "ubuntu", "suse", "rhel" ],
  :required => "optional"
  
attribute "rightimage/platform_version",
  :display_name => "Guest OS Version",
  :description => "The OS version to build into the virtual image.",
  :choice => [ "6.3", "6.4", "6.5", "12.04", "14.04" ],
  :required => "optional"
 
attribute "rightimage/arch",
  :display_name => "Guest OS Architecture",
  :description => "The architecture for the virtual image.",
  :choice => [ "x86_64", "i386" ],
  :required => "optional"
  
attribute "rightimage/cloud",
  :display_name => "Target Cloud",
  :description => "The supported cloud for the virtual image. If unset, build a generic base image.",
  :choice => [ "ec2", "cloudstack", "eucalyptus", "openstack", "rackspace", "rackspace-open-cloud", "azure", "google", "vagrant", "vsphere" ],
  :required => "recommended"
  
attribute "rightimage/region",
  :display_name => "EC2 Region",
  :description => "The EC2 region in which the image will reside",
  :choice => [ "us-east-1", "us-west-1", "us-west-2", "eu-west-1", "ap-southeast-1", "ap-southeast-2", "ap-northeast-1", "sa-east-1" ],
  :required => true
  
attribute "rightimage/rightlink_repo",
  :display_name => "RightLink Repository",
  :description => "Rightlink repository to use. For adhoc repos, supply the value 'adhoc-NAME', such as adhoc-pete.",
  :recipes => [ "rightimage::default", "rightimage::build_image", "rightimage::rightscale_rightlink", "rightimage::rebundle", "rightimage::rightscale_install"],
  :choice => [
    "rightlink-beta",
    "rightlink-nightly",
    "rightlink-production"
    ],
  :default => "rightlink-beta",
  :required => "optional"
  
attribute "rightimage/rightlink_version",
  :display_name => "RightLink Version",
  :description => "RightLink version to install.",
  :recipes => [ "rightimage::default", "rightimage::build_image", "rightimage::rightscale_rightlink", "rightimage::rebundle", "rightimage::rightscale_install"],
  :required => true
  
attribute "rightimage/image_upload_bucket",
  :display_name => "Image Upload Bucket",
  :description => "The bucket to upload the image to.",
  :required => "required",
  :recipes => [ "rightimage::base_upload", "rightimage::build_base", "rightimage::default", "rightimage::build_image" , "rightimage::upload_image_s3", "rightimage::ec2_download_bundle", "rightimage::cloud_upload", "rightimage::upload_image_s3", "rightimage::rebundle" ]

attribute "rightimage/image_name",
   :display_name => "Image Name",
   :description => "The name you want to give this new image.",
   :required => "required"

attribute "rightimage/rebundle_base_image_id",
  :display_name => "Rebundle Base Image ID",
  :description => "Cloud specific ID for the image to start with when building a rebundle image",
  :required => "optional",
  :default => "",
  :recipes => [ "rightimage::default", "rightimage::rebundle"]

attribute "rightimage/rebundle_git_repository",
  :display_name => "Rebundle Git Repository",
  :description => "Git repository to checkout from when building a rebundle image",
  :required => "optional",
  :default => "",
  :recipes => [ "rightimage::default", "rightimage::rebundle"]

attribute "rightimage/rebundle_git_revision",
  :display_name => "Rebundle Git Revision",
  :description => "Git repository revision to checkout from when building a rebundle image",
  :required => "optional",
  :default => "",
  :recipes => [ "rightimage::default", "rightimage::rebundle"]

attribute "rightimage/debug",
  :display_name => "Development Image?",
  :description => "If true, a random root password will be set for debugging purposes. If 'fixed_password', will set root password to rightimage/fixed_password, default 'rightcale11'. NOTE: you must include 'Dev' in the image name or the build with fail.",
  :choice => [ "true", "fixed_password", "false" ],
  :default => "false",
  :required => "optional"

attribute "rightimage/fixed_password",
  :display_name => "Fixed root password",
  :description => "Fixed password to use if rightimage/debug is set to 'fixed_password'",
  :default => "f1xedP@ss1",
  :required => "optional"

attribute "rightimage/mirror_freeze_date",
  :display_name => "Mirror freeze date",
  :description => "Day from which to pull OS, rightscale, and rubygem packages. Expected format is YYYYMMDD. If not supplied, will use latest available date.",
  :required => "recommended"


attribute "rightimage/rightscale_staging_mirror",
  :display_name => "Use RightScale staging mirror",
  :description => "Use the staging repo for RightScale Software repo. Used for development and testing",
  :default => "false",
  :choice => ["true", "false"],
  :required => "optional"

attribute "rightimage/build_id",
  :display_name => "Build ID",
  :description => "Unique identifier for the a image. When building a full image, this build_id must match the build_id of the base image you wish to use. The ID can't include underscores.  This value is usually the RightImage version, such as 13.2.1, or a combination of the version and the developers name or git sha used to build the code, such as 13.2.1-aef01c2d",
  :default => "0",
  :required => "recommended"

attribute "rightimage/hypervisor",
  :display_name => "Hypervisor",
  :description => "Which hypervisor is this image for?",
  :choice => [ "xen", "kvm", "esxi", "hyperv", "virtualbox" ],
  :required => "required"

attribute "rightimage/datacenter",
  :display_name => "Datacenter ID",
  :description => "Datacenter/Zone ID.  Defaults to 1.  Use US/UK for Rackspace Legacy. Use DFW/ORD/LON/SYD for Rackspace Open Cloud.",
  :default => "1",
  :required => "recommended"

attribute "rightimage/virtualization",
  :display_name => "Virtualization type",
  :description => "Virtualization type (EC2 only).  Defaults to pvm.",
  :choice => [ "hvm", "pvm" ],
  :default => "pvm",
  :required => "recommended"

attribute "rightimage/cloud_options",
  :display_name => "Cloud options",
  :description => "Cloud specific options.  Currently only applicable to Rackspace clouds.  Select 'managed' for Managed enabled accounts, 'rackconnect' for RackConnect enabled accounts.",
  :choice => ["", "managed", "rackconnect", "rackconnect,managed"],
  :default => "",
  :required => "recommended",
  :recipes => [ "rightimage::rebundle", "rightimage::default" ]

# AWS
aws_x509_recipes = ["rightimage::cloud_upload", "rightimage::rebundle", "rightimage::default", "rightimage::ec2_download_bundle"]
aws_api_recipes = aws_x509_recipes + ["rightimage::build_base", "rightimage::build_image", "rightimage::upload_image_s3", "rightimage::base_upload", "rightimage::image_tests" ]

attribute "rightimage/ec2/image_type",
  :display_name => "EC2 Image Type",
  :description => "Type of EC2 Image cloud_upload recipe will create",
  :default => "InstanceStore",
  :recipes => ["rightimage::build_image", "rightimage::default", "rightimage::cloud_upload"],
  :choice => [ "InstanceStore", "EBS" ],
  :required => "recommended"

attribute "rightimage/aws_account_number",
  :display_name => "aws_account_number",
  :description => "aws_account_number",
  :required => "required",
  :recipes => aws_api_recipes
  
attribute "rightimage/aws_access_key_id",
  :display_name => "aws_access_key_id",
  :description => "aws_access_key_id",
  :required => "required",
  :recipes => aws_api_recipes
  
attribute "rightimage/aws_secret_access_key",
  :display_name => "aws_secret_access_key",
  :description => "aws_secret_access_key",
  :required => "required",
  :recipes => aws_api_recipes
  
attribute "rightimage/aws_509_key",
  :display_name => "aws_509_key",
  :description => "aws_509_key",
  :required => "required",
  :recipes => aws_x509_recipes
  
attribute "rightimage/aws_509_cert",
  :display_name => "aws_509_cert",
  :description => "aws_509_cert",
  :required => "required",
  :recipes => aws_x509_recipes

# Eucalyptus
attribute "rightimage/euca/user_id",
  :display_name => "Eucalyptus User ID",
  :description => "The EC2_USER_ID value defined in your eucarc credentials file. User must have admin privileges.",
  :required => "required",
  :recipes => [ "rightimage::cloud_upload" ]
  
attribute "rightimage/euca/euca_url",
  :display_name => "Eucalyptus URL",
  :description => "Base URL to your Eucalyptus Cloud Controller. Don't include port. (Ex. http://<server_ip>)",
  :required => "required",
  :recipes => [ "rightimage::cloud_upload" ]

attribute "rightimage/euca/access_key_id",
  :display_name => "Eucalyptus Access Key",
  :description => "The EC2_ACCESS_KEY value defined in your eucarc credentials file. User must have admin privileges.",
  :required => "required",
  :recipes => [ "rightimage::cloud_upload" ]

attribute "rightimage/euca/secret_access_key",
  :display_name => "Eucalyptus Secret Access Key",
  :description => "The EC2_SECRET_KEY value defined in your eucarc credentials file. User must have admin privileges.",
  :required => "required",
  :recipes => [ "rightimage::cloud_upload" ]

attribute "rightimage/euca/x509_key",
  :display_name => "Eucalyptus x509 Private Key",
  :description => "The contents of the file pointed to by the EC2_PRIVATE_KEY value defined in your eucarc credentials file.",
  :required => "required",
  :recipes => [ "rightimage::cloud_upload" ]

attribute "rightimage/euca/x509_cert",
  :display_name => "Eucalyptus x509 Certificate",
  :description => "The contents of the file pointed to by the EC2_CERT value defined in your eucarc credentials file.",
  :required => "required",
  :recipes => [ "rightimage::cloud_upload" ]

attribute "rightimage/euca/euca_cert",
  :display_name => "Eucalyptus Cloud Certificate",
  :description => "The contents of the file pointed to by the EUCALYPTUS_CERT value defined in your eucarc credentials file.",
  :required => "required",
  :recipes => [ "rightimage::cloud_upload" ]

# Openstack
attribute "rightimage/openstack/hostname",
  :display_name => "Openstack Hostname",
  :description => "Hostname of Openstack Cloud Controller.",
  :required => "optional",
  :default => "",
  :recipes => [ "rightimage::cloud_upload" ]

attribute "rightimage/openstack/user",
  :display_name => "Openstack User",
  :description => "User to access API of Openstack Cloud Controller.",
  :required => "optional",
  :default => "",
  :recipes => [ "rightimage::cloud_upload" ]

attribute "rightimage/openstack/password",
  :display_name => "Openstack Password",
  :description => "Password for user to access API of Openstack Cloud Controller.",
  :required => "optional",
  :default => "",
  :recipes => [ "rightimage::cloud_upload" ]

attribute "rightimage/openstack/tenant",
  :display_name => "Openstack Tenant",
  :description => "Tenant ID for Openstack project.",
  :required => "optional",
  :default => "",
  :recipes => [ "rightimage::cloud_upload" ]

# CloudStack
attribute "rightimage/cloudstack/cdc_url",
  :display_name => "CloudStack API URL",
  :description => "URL to your CloudStack Cloud Controller. (Ex. http://<server_ip>:8080/client/api)",
  :required => "required",
  :recipes => [ "rightimage::cloud_upload" ]

attribute "rightimage/cloudstack/cdc_api_key",
  :display_name => "CloudStack API Key",
  :description => "CloudStack API key.",
  :required => "required",
  :recipes => [ "rightimage::cloud_upload" ]

attribute "rightimage/cloudstack/cdc_secret_key",
  :display_name => "CloudStack Secret Key",
  :description => "CloudStack secret key.",
  :required => "required",
  :recipes => [ "rightimage::cloud_upload" ]

# RackSpace
attribute "rightimage/rackspace/account",
  :display_name => "Rackspace Account ID",
  :description => "Rackspace Account ID",
  :required => "required",
  :recipes => [ "rightimage::rebundle", "rightimage::default" ]

attribute "rightimage/rackspace/api_token",
  :display_name => "Rackspace API Token",
  :description => "Rackspace API Token",
  :required => "required",
  :recipes => [ "rightimage::rebundle", "rightimage::default" ]

# Azure
attribute "rightimage/azure/shared_key",
  :display_name => "Azure Shared Key",
  :description => "Shared key for the storage account to upload the image to.  If supplied, will use Image Upload Bucket as the container to uplaod to.  If not supplied, will let Azure command line tool automatically determine a storage account and container to upload to. ",
  :required => "recommended",
  :recipes => [ "rightimage::cloud_upload" ]

attribute "rightimage/azure/storage_account",
  :display_name => "Azure Storage Account",
  :description => "Storage account to upload the image to. Required when supplying a Shared Key",
  :required => "recommended",
  :recipes => [ "rightimage::cloud_upload" ]

attribute "rightimage/azure/region",
  :display_name => "Azure Location",
  :required => "recommended",
  :choice => [ 'West Europe', 'North Europe', 'Southeast Asia', 'East Asia', 'West US', 'East US' ],
  :default => 'West US',
  :recipes => [ "rightimage::cloud_upload" ]

attribute "rightimage/azure/cert",
  :display_name => "Azure Management Certificate",
  :description => "Azure Management Certificate",
  :required => "required",
  :recipes => [ "rightimage::cloud_upload" ]

attribute "rightimage/azure/id",
  :display_name => "Azure Subscription ID",
  :description => "Azure Subscription ID",
  :required => "required",
  :recipes => [ "rightimage::cloud_upload" ]


# Google
attribute "rightimage/google/gc_access_key_id",
  :display_name => "Google access_key_id",
  :description => "Google storage (interoperable) access key id",
  :required => "optional",
  :recipes => [ "rightimage::cloud_upload" ]

attribute "rightimage/google/gc_secret_access_key",
  :display_name => "Google secret_access_key",
  :description => "Google storage (interoperable) secret access key",
  :required => "optional",
  :recipes => [ "rightimage::cloud_upload" ]

attribute "rightimage/google/project_id",
  :display_name => "Google Project ID",
  :description => "GCE Project ID to register this image for",
  :required => "optional",
  :recipes => [ "rightimage::cloud_upload", "rightimage::default", "rightimage::rebundle" ]

attribute "rightimage/google/client_email",
  :display_name => "Google client email",
  :description => "OAuth2 credentials client email for GCE. Pulled from gcutil conf",
  :required => "optional",
  :recipes => [ "rightimage::default", "rightimage::rebundle" ]

attribute "rightimage/google/client_secret",
  :display_name => "Google client secret",
  :description => "OAuth2 credentials client secret for GCE. Pulled from gcutil conf",
  :required => "optional",
  :recipes => [ "rightimage::cloud_upload" ]

attribute "rightimage/google/client_id",
  :display_name => "Google client id",
  :description => "OAuth2 credentials client id for GCE. Pulled from gcutil conf",
  :required => "optional",
  :recipes => [ "rightimage::cloud_upload" ]

attribute "rightimage/google/service_cert",
  :display_name => "Google certificate",
  :description => "OAuth2 credentials service account certificate for GCE. Pulled from gcutil conf",
  :required => "optional",
  :recipes => [ "rightimage::default", "rightimage::rebundle" ]

attribute "rightimage/google/service_key",
  :display_name => "Google private key",
  :description => "OAuth2 credentials service account private key for GCE. Pulled from gcutil conf",
  :required => "optional",
  :recipes => [ "rightimage::default", "rightimage::rebundle" ]

attribute "rightimage/google/refresh_token",
  :display_name => "Google OAuth2 credentials refresh token",
  :description => "Refresh token value for GCE. Pulled from gcutil conf",
  :required => "optional",
  :recipes => [ "rightimage::cloud_upload" ]

attribute "rightimage/build_dir",
  :display_name => "Build Directory",
  :description => "Temporary directory to store build collateral",
  :default => "/mnt/storage",
  :required => "optional"

attribute "rightimage/volume_size",
  :display_name => "Volume Size",
  :description => "If specified, creates a volume of specified size and mounts at rightimage/build_dir",
  :required => "optional",
  :recipes => [ "rightimage::default", "rightimage::build_image", "rightimage::volume_create" ]
