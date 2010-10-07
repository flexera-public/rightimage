maintainer       "RightScale, Inc."
maintainer_email "cary@rightscale.com"
license          "All rights reserved"
description      "Installs/Configures dropbox"
version          "0.1"

recipe "dropbox::default", "Install dropbox and register instance."

attribute "dropbox",
  :display_name => "Dropbox Application Settings",
  :type => "hash"
  
#
# required attributes
#
attribute "dropbox/email",
  :display_name => "Dropbox User Email",
  :description => "Email address linked to your dropbox account.",
  :required => true,
  :recipes => [ "dropbox::default" ]

attribute "dropbox/password",
  :display_name => "Dropbox Password",
  :description => "Passwod for your dropbox user account.",
  :required => true,
  :recipes => [ "dropbox::default" ]
