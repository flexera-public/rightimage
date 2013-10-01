actions :test

attribute :command, :kind_of => String
attribute :fail, :default => true, :kind_of => [ TrueClass, FalseClass ]
