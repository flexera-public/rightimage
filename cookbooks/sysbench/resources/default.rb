actions :run

attribute :result_file, :kind_of => String, :name_attribute => true
attribute :mysql_password, :kind_of => String, :default => nil
attribute :instance_type, :kind_of => String, :required => true
