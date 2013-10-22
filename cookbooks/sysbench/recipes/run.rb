sysbench node[:sysbench][:result_file] do
  mysql_password node[:sysbench][:mysql_password]
  instance_type node[:sysbench][:instance_type]
  action :run
end
