#
# Cookbook Name:: virtual_monkey
# Recipe:: setup_apptest_database
#
# Copyright 2010, RightScale, Inc.
#
# All rights reserved - Do Not Redistribute
#

include_recipe "db_mysql::default"

SQL_BASE_DIR = "/root"
SQL_DUMP = "#{SQL_BASE_DIR}/app_test.sql"
SCHEMA = "app_test"

# Download lastest app_test mysql dump
# subversion "pull unified_app_test repo" do
#   repository "https://wush.net/svn/rightscale/unified_test_app/common/sql"
#   revision "HEAD"
#   destination SQL_BASE_DIR
#   action :sync
# end

remote_file "#{SQL_DUMP}" do
  source "app_test.sql"
end

# setup the mysql app_test database
# TODO: this code was stolen from db_mysql definition db_mysql_restore, port to use svn or git
bash "unpack mysqldump file: #{SQL_DUMP}" do
  not_if do `echo "show databases" | mysql | grep -q  "^#{SCHEMA}$"` end
  user "root"
  cwd "#{SQL_BASE_DIR}"
  code <<-EOH
    set -e
    if [ ! -f #{SQL_DUMP} ] 
    then 
      echo "ERROR: MySQL SQL_DUMP not found! File: '#{SQL_DUMP}'" 
      exit 1
    fi 
    mysqladmin -u root create #{SCHEMA} 
    gunzip < #{SQL_DUMP} | mysql -u root -b #{SCHEMA}
  EOH
  notifies :restart, resources(:service => "mysql")
end



 