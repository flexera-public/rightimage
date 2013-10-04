# Currently makes a few assumptions, namely that the its on the same machine
# as the database, and it can use the root user to do its tests.
default[:sysbench][:result_file] = "/tmp/result.json"
default[:sysbench][:instance_type] = nil
default[:sysbench][:mysql_password] = "sysbenchdefault"

