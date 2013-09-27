maintainer       "RightScale, Inc"
maintainer_email "support@rightscale.com"
license          "Apache v2.0"
description      "Installs and configures the sysbench"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.0.1"

depends "db"
depends "db_msyql"

recipe "sysbench::default", "Install sysbench"
recipe "sysbench::run", "Run sysbench"

attribute "sysbench/result_file",
  :required => "recommended",
  :display_name => "Report Output Location",
  :description => "Where to output results of sysbench run. In json format.",
  :default => "/tmp/result.json"
