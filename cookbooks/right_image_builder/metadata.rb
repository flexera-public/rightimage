maintainer       "RightScale, Inc."
maintainer_email "cary@rightscale.com"
license          "All rights reserved"
description      "Installs/Configures right_image_builder"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.rdoc'))
version          "0.1"

depends "resource:repo['right_image_builder']" # not really in metadata spec yet. Format TBD.

recipe "right_image_builder::default", "Installs environment in which to run the image builder."

grouping "repo/right_image_builder",
 :display_name => "Git Client Default Settings",
 :description => "Settings for managing a Git source repository",
 :databag => true       # proposed metadata addition

attribute "repo/right_image_builder/provider",
  :display_name => "Repository Provider Type",
  :description => "",
  :default => "repo_git"

attribute "repo/right_image_builder/repository",
  :display_name => "Repository Url",
  :description => "",
  :default => "git@github.com:rightscale/right_image_builder.git"
  
attribute "repo/right_image_builder/branch",
  :display_name => "Branch/Tag",
  :description => "",
  :required => "optional"
  
attribute "repo/right_image_builder/ssh_key",
  :display_name => "SSH Key",
  :description => "your github key",
  :required => "required"
  
  
  
grouping "repo/image_sandbox",
 :display_name => "Git Client image_sandbox Settings",
 :description => "Settings for managing a Git source repository",
 :databag => true       # proposed metadata addition

attribute "repo/image_sandbox/provider",
  :display_name => "Repository Provider Type",
  :description => "",
  :default => "repo_git"

attribute "repo/image_sandbox/repository",
  :display_name => "Repository Url",
  :description => "",
  :required => "required"
  
attribute "repo/image_sandbox/branch",
  :display_name => "Branch/Tag",
  :description => "",
  :required => "optional"
  
attribute "repo/image_sandbox/ssh_key",
  :display_name => "SSH Key",
  :description => "your github key",
  :required => "required"
  
  
grouping "repo/virtualmonkey",
 :display_name => "Git Client virtualmonkey Settings",
 :description => "Settings for managing a Git source repository",
 :databag => true       # proposed metadata addition

attribute "repo/virtualmonkey/provider",
  :display_name => "Repository Provider Type",
  :description => "",
  :default => "repo_git"

attribute "repo/virtualmonkey/repository",
  :display_name => "Repository Url",
  :description => "",
  :required => "required"
  
attribute "repo/virtualmonkey/branch",
  :display_name => "Branch/Tag",
  :description => "",
  :required => "optional"
  
attribute "repo/virtualmonkey/ssh_key",
  :display_name => "SSH Key",
  :description => "your github key",
  :required => "required"


