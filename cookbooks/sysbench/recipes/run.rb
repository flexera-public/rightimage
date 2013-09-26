

sysbench node[:sysbench][:report_file] do
  mysql_db node[:sysbench][:mysql_db]
  mysql_user node[:sysbench][:mysql_user]
  mysql_password node[:sysbench][:mysql_password]
  action :run
end
