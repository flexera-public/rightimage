maintainer       "RightScale, Inc."
maintainer_email "cary@rightscale.com"
license          "All rights reserved"
description      "Installs/Configures virtual_monkey"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.rdoc'))
version          "0.1"

attribute "db_mysql/bind_address",
  :display_name => "Database Bind Address",
  :default => "0.0.0.0"
  
attribute "virtual_monkey/deployment_prefix",
  :display_name => "Deployment Prefix",
  :description => "Prefix for test deployment names. Ex: vmonk_php_",
  :required => true,
  :recipes => [ "virtual_monkey::do_tests", "virtual_monkey::default" ]
  
attribute "virtual_monkey/common_inputs_file",
  :display_name => "Common Inputs File",
  :description => "Name of the virtual monkey common inputs file name. Ex: php.json",
  :required => true,
  :recipes => [ "virtual_monkey::do_tests", "virtual_monkey::default" ]
  
attribute "virtual_monkey/template_id_list",
  :display_name => "Template ID List",
  :description => "Array of ServerTemplate IDs to populate deployments with. Ex: 867509, 123093",
  :required => true,
  :recipes => [ "virtual_monkey::do_tests", "virtual_monkey::default" ]
  
attribute "virtual_monkey/cuke_test_list",
  :display_name => "Cucumber Test List",
  :description => "Which cuke test(s) to run.",
  :required => true,
  :recipes => [ "virtual_monkey::do_tests", "virtual_monkey::default" ]
  
attribute "virtual_monkey/your_email",
  :display_name => "Your Email Address",
  :description => "The email address we send results email to.",
  :recipes => [ "virtual_monkey::do_tests", "virtual_monkey::default" ]
  
attribute "virtual_monkey/code",
  :display_name => "PHP Application Code",
  :type => "hash"
  
attribute "virtual_monkey/code/url",
  :display_name => "Repository URL",
  :description => "Specify the URL location of the repository that contains the test code. Ex: git://github.com/mysite/myapp.git",
  :required => true,
  :recipes => [ "virtual_monkey::update_test_code", "virtual_monkey::default" ]

attribute "virtual_monkey/code/credentials",
  :display_name => "Repository Credentials",
  :description => "The private SSH key of the git repository.",
  :required => false,
  :default => "",
  :recipes => [ "virtual_monkey::update_test_code", "virtual_monkey::default" ]

attribute "virtual_monkey/code/branch",
  :display_name => "Repository Branch",
  :description => "The name of the branch within the git repository where the test code should be pulled from.",
  :default => "master",
  :recipes => [ "virtual_monkey::update_test_code", "virtual_monkey::default" ]
  

attribute "virtual_monkey/account/id",
  :display_name => "Remote Storage Account ID",
  :description => "The account ID that will be used to access the 'Remote Storage Container'.  For AWS, enter your AWS Access Key ID.  For Rackspace, enter your username.",
  :required => true,
  :recipes => [ "virtual_monkey::do_tests", "virtual_monkey::default" ]

attribute "virtual_monkey/account/credentials",
  :display_name => "Remote Storage Account Key",
  :description => "The account key that will be used to access the 'Remote Storage Container'.  For AWS, enter your AWS Secret Access Key.  For Rackspace, enter your API Key.",
  :required => true,
  :recipes => [ "virtual_monkey::do_tests", "virtual_monkey::default" ]
  
attribute "virtual_monkey/test_dir",
  :display_name => "Test Directory",
  :description => "Where should we place the tests?",
  :default => "/root/tests",
  :recipes => [ "virtual_monkey::update_test_code", "virtual_monkey::default" ]