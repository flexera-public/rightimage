require 'dm-core'
require 'right_aws'
require 'sdb/active_sdb'
require 'ruby-debug'

# TEST CRED
aws_access_key_id = "1EPVFPZVAGMQQ3YDA5G2"
aws_secret_access_key = "nuSHnVayKx98A6A0z9HLS1Wly9K09F4CHgUaz2Y6"

RightAws::ActiveSdb.establish_connection(aws_access_key_id, aws_secret_access_key)
class SharedDns < RightAws::ActiveSdb::Base
  def self.monkey
    debugger
    puts "blah"
  end

end


sqlitedb = File.join(File.dirname(__FILE__), "..", "..", "features", "shared.db")
puts "using #{sqlitedb}"
DataMapper.setup(:default, "sqlite3:#{sqlitedb}")

class DeploymentSet
  include DataMapper::Resource
  property :id, Serial
  property :tag, String
end

class TemplateSet
  include DataMapper::Resource
  property :id, Serial
  has n, :templates
end

class Template
  include DataMapper::Resource
  property :unique_id, Serial
  property :id, Integer
  belongs_to :template_set  
end

class Job
  include DataMapper::Resource
  property :id, Serial
  property :pid, Integer
  property :status, String
  property :deployment_href, String
  has n, :log_files 
end

class LogFile
  include DataMapper::Resource
  property :id, Serial
  property :file, String
  belongs_to :job
end

