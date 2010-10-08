maintainer       "RightScale, Inc."
maintainer_email "cary@rightscale.com"
license          "All rights reserved"
description      "Installs/Configures devmode"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.rdoc'))
version          "0.1"

recipe "devmode::setup_cookbooks", "Used to setup Dropbox cookbook as instance cookbooks."
recipe "devmode::do_recipe_loop_step", "Used by do_recipe_loop as a remote recipe."
recipe "devmode::do_recipe_loop", "Reconverge the boot recipes <count> times."

attribute "devmode/converge_loop/total",
  :display_name => "Converge Loop Count",
  :default => "10",
  :recipes => [ "devmode::do_converge_loop", "devmode::do_converge_loop_step" ]

