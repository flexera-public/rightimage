maintainer       "RightScale, Inc"
maintainer_email "support@rightscale.com"
license          "Apache v2.0"
description      "Installs and configures the sysbench"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.0.1"

recipe "sysbench::default", "Install sysbench"
recipe "sysbench::run", "Run sysbench"

# depends "db_msyql"

attribute "sysbench/result_file",
  :required => "required",
  :display_name => "Report Output Location",
  :description => "Where to output results of sysbench run. In json format.",
  :default => "/tmp/result.json"

attribute "sysbench/mysql_db",
  :required => "recommended",
  :display_name => "OLTP Test MySQL DB Name",
  :description => "Sample database name for OLTP test"

attribute "sysbench/mysql_user",
  :required => "recommended",
  :display_name => "OLTP Test MySQL User Name",
  :description => "Sample database user for OLTP test"

attribute "sysbench/mysql_password",
  :required => "recommended",
  :display_name => "OLTP Test MySQL Password Name",
  :description => "Sample database password for OLTP test"

