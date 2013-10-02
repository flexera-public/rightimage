actions :run

attribute :result_file, :kind_of => String, :name_attribute => true
attribute :mysql_db, :kind_of => String, :default => "sysbench"
attribute :mysql_password, :kind_of => String, :default => nil
attribute :mysql_user, :kind_of => String, :default => "sysbenchuser"
attribute :instance_type, :kind_of => String, :required => true
