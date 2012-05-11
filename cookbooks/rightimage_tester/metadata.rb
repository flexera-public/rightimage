maintainer       "RightScale, Inc."
maintainer_email "support@rightscale.com"
description      "A cookbook for testing RightImages"
version          "0.1.0"

depends "rightscale"

recipe "rightimage_tester::default", ""
recipe "rightimage_tester::dependencies", "Ensure dependencies are installed."
recipe "rightimage_tester::filesystem_permissions", "Check filesystem permissions."
recipe "rightimage_tester::filesystem_size", "Check root filesystem size."
recipe "rightimage_tester::java", "Check java installation."
recipe "rightimage_tester::ldconfig", "Ensure ldconfig runs."
recipe "rightimage_tester::modprobe", "Ensure modprobe runs."
recipe "rightimage_tester::packages", "Ensure packages can be installed."
recipe "rightimage_tester::rubygems", "Check rubygems installation."
recipe "rightimage_tester::special_strings","Check for special strings."
recipe "rightimage_tester::sshd_config", "Check sshd configuration."
recipe "rightimage_tester::sudo", "Check sudo configuration."

attribute "rightimage_tester/aws_access_key_id",
  :display_name => "AWS Access Key ID",
  :description => "AWS Access Key ID",
  :required => "required",
  :recipes => [ "rightimage_tester::special_strings" ]

attribute "rightimage_tester/aws_secret_access_key",
  :display_name => "AWS Secret Access Key",
  :description => "AWS Secret Access Key",
  :required => "required",
  :recipes => [ "rightimage_tester::special_strings" ]

attribute "rightimage_tester/test_ssh_security",
  :display_name => "Test SSH Security?",
  :description => "If set, checks various SSHd security settings.  Should be set to false on Rackspace Managed or Dev images.",
  :choice => [ "true", "false" ],
  :default => "true",
  :required => "optional"
