maintainer       "RightScale, Inc."
maintainer_email "support@rightscale.com"
description      "A cookbook for testing RightImages"
license          "Apache v2.0"
version          "14.0.0"

depends "ros_upload"
depends "rightscale"
depends "rightscale_volume"
depends "sysbench"

recipe "rightimage_tester::default", "Default recipe. Does nothing currently."
recipe "rightimage_tester::apparmor", "Ensure apparmor is not installed."
recipe "rightimage_tester::apt_config", "Check apt configuration."
recipe "rightimage_tester::bad_files", "Check for bad files."
recipe "rightimage_tester::banned_packages", "Ensure no banned packages installed."
recipe "rightimage_tester::bashrc", "Ensure bashrc is sourced."
recipe "rightimage_tester::benchmark", "Run image benchmarks. Call report recipe after this one to upload to S3"
recipe "rightimage_tester::blank_passwords", "Ensure no blank passwords."
recipe "rightimage_tester::crontab", "Check crontab configuration."
recipe "rightimage_tester::dependencies", "Ensure dependencies are installed."
recipe "rightimage_tester::dupe_mounts", "Check for duplicate mounts."
recipe "rightimage_tester::filesystem_permissions", "Check filesystem permissions."
recipe "rightimage_tester::filesystem_size", "Check root filesystem size."
recipe "rightimage_tester::fstab", "Check fstab."
recipe "rightimage_tester::gemrc", "Ensure /root/.gem and .gemrc doesn't exist."
recipe "rightimage_tester::hostname", "Ensure hostname set."
recipe "rightimage_tester::image_name", "Check image name."
recipe "rightimage_tester::ipv6", "Ensure IPv6 is disabled."
recipe "rightimage_tester::java", "Check java installation."
recipe "rightimage_tester::ldconfig", "Ensure ldconfig runs."
recipe "rightimage_tester::modprobe", "Ensure modprobe runs."
recipe "rightimage_tester::ntp", "Ensure ntp service exists and can restart."
recipe "rightimage_tester::packages", "Ensure packages can be installed."
recipe "rightimage_tester::rackconnect", "Check for Rackspace Rackconnect automation failures."
recipe "rightimage_tester::reboot", "Ensure instance reboots."
recipe "rightimage_tester::report", "Generate and upload an image report"
recipe "rightimage_tester::resolvconf", "Verify resolvconf tail empty."
recipe "rightimage_tester::rightlink_core", "Ensure no RightLink core files."
recipe "rightimage_tester::rubygems", "Check rubygems installation."
recipe "rightimage_tester::selinux", "Ensure SELinux is disabled."
recipe "rightimage_tester::special_strings","Check for special strings."
recipe "rightimage_tester::sftp", "Ensure can sftp into self."
recipe "rightimage_tester::ssh", "Ensure can ssh into self."
recipe "rightimage_tester::sshd_config", "Check sshd configuration."
recipe "rightimage_tester::sudo", "Check sudo configuration."
recipe "rightimage_tester::volume_attach", "Ensure a volume can be attached."

recipe "rightimage_tester::xfs_crash", "Ensure instance does not crash when using XFS."

attribute "rightimage_tester/aws_access_key_id",
  :display_name => "AWS Access Key ID",
  :description => "AWS Access Key ID. Used to upload image report/benchmarks/",
  :required => "required",
  :recipes => [ "rightimage_tester::special_strings", "rightimage_tester::report" ]

attribute "rightimage_tester/aws_secret_access_key",
  :display_name => "AWS Secret Access Key",
  :description => "AWS Secret Access Key. used to upload image report/benchmarks",
  :required => "required",
  :recipes => [ "rightimage_tester::special_strings", "rightimage_tester::report" ]

attribute "rightimage_tester/report_name",
  :display_name => "Report Name",
  :description => "Upload a json file to s3 detailing benchmark, image tester, and image report results with specified name. This is generally a mix of the image id or name and cloud tested on.  For example: us-west-1/RightImage_CentOS_6.4_x64_v13.5.0.1",
  :required => "required",
  :recipes => [ "rightimage_tester::report" ]

attribute "rightimage_tester/instance_type",
  :display_name => "Instance Type",
  :description => "The instance type, such as m1.small. Inserted into the benchmark results.",
  :required => "recommended",
  :recipes => [ "rightimage_tester::benchmark" ]

attribute "rightimage_tester/root_size",
  :display_name => "Root Filesystem Size",
  :description => "If set, verifies root filesystem size.  Specify size in GB.  Most RightImages are 10GB.",
  :default => "10",
  :required => "recommended",
  :recipes => [ "rightimage_tester::filesystem_size" ]

attribute "rightimage_tester/test_ipv6",
  :display_name => "Verify IPv6 disabled?",
  :description => "If set, verifies IPv6 is diabled.  Should be set to false on Softlayer.",
  :choice => [ "true", "false" ],
  :default => "true",
  :required => "recommended",
  :recipes => [ "rightimage_tester::ipv6" ]

attribute "rightimage_tester/test_ssh_security",
  :display_name => "Test SSH Security?",
  :description => "If set, checks various SSHd security settings.  Should be set to false on Rackspace Managed or Dev images.",
  :choice => [ "true", "false" ],
  :default => "true",
  :required => "recommended",
  :recipes => [ "rightimage_tester::sshd_config" ]
