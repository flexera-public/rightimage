maintainer       "RightScale, Inc."
maintainer_email "cary@rightscale.com"
license          "All rights reserved"
description      "Installs/Configures resat"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.rdoc'))
version          "0.1"

depends "git"
depends "cucumber"
  
attribute "resat/git_key",
  :display_name => "Git Repository Credentials",
  :description => "The private SSH key of the git repository.",
  :require => true

attribute "resat/test/type",
  :display_name => "Test Type",
  :description => "Selects deployment config directory, also which tagged features should be run. See http://wiki.github.com/aslakhellesoy/cucumber/tags",
  :require => true,
  :recipes => [ "resat::do_run_features", "resat::do_deployment_create",  "resat::do_deployment_destroy", "resat::do_deployment_reboot", "resat::do_deployment_shutdown" ]

attribute "resat/test/template",
  :display_name => "Template Type",
  :description => "The type of ServerTemplate to test.",
  :require => true,
  :recipes => [ "resat::do_deployment_create",  "resat::do_deployment_destroy", "resat::do_deployment_reboot", "resat::do_deployment_shutdown" ]

attribute "resat/test/os",
  :display_name => "Test Platform",
  :description => "The platform to test on.",
  :require => true,
  :recipes => [ "resat::do_deployment_create",  "resat::do_deployment_destroy", "resat::do_deployment_reboot", "resat::do_deployment_shutdown" ]
