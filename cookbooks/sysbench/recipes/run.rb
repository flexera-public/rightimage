sysbench node[:sysbench][:result_file] do
  mysql_db "sysbench"
  mysql_user node[:sysbench][:mysql_user]
  mysql_password node[:sysbench][:mysql_password]
  action :run
end
