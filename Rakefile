require 'rubygems'
require 'chef'
require 'json'


# The top of the repository checkout
TOP_DIR = File.expand_path(File.join(File.dirname(__FILE__), "."))
CB_DIR = TOP_DIR + "/cookbooks"

def execcmd(cmd)
  puts cmd
  `#{cmd}`
  raise "Command failed" unless $?.success?
end

class Hash
  alias :oldkeys :keys
  def keys
    oldkeys.sort
  end
end

def sort_metadata(file)
  puts "Sorting #{file}"
  data = ::JSON.load(::File.open(file, "r"))
  File.open(file,"w") { |f| f.puts(JSON.pretty_generate(data)) }
end


desc "Update metadata for all local repos with sorted keys"
task :metadata do
  execcmd("knife cookbook metadata -o #{CB_DIR} --all")
  Dir.glob(CB_DIR + "/*").each do |dir|
    if ::File.exists?(dir + "/metadata.json")
      sort_metadata(dir + "/metadata.json")
    end
  end
end
