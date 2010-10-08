#TODO: this needs it's paths fixed up

ruby_block "Cleanup EBS Volumes" do
  block do
    
require 'rubygems'
require 'optparse'
require 'ostruct'
require 'date'
require 'benchmark'
require  'ftools'
require '/usr/lib/ruby/gems/1.8/gems/resat-0.7.3/lib/rdoc_patch'
require '/usr/lib/ruby/gems/1.8/gems/resat-0.7.3/lib/engine'
 
# define  options for getting a volume id using resat engine 
def get_volumes_options
  options = OpenStruct.new
  options.verbose = false
  options.quiet = false
  options.norecursion = false
  options.failonerror = false
  options.variables = {}
  options.config =  "/root/right_test/resat/config/config_#{ENV['CONFIG_FILE']}.yaml"
  options.schemasdir = '/usr/lib/ruby/gems/1.8/gems/resat-0.7.3/schemas'
  options.loglevel = "info"
  options.logfile = "/tmp/resat.log"
  options.target =  '/root/right_test/resat/scenarios/server_template_scenarios/cleanup/resat_get_volumes.yaml'
  options
end

# define options for deleting a volume using resat engine 
def delete_volume_options(volume_id)
  options = OpenStruct.new
  options.variables = { 'volume_id' => volume_id }
  options.verbose = false
  options.quiet = false
  options.norecursion = false
  options.failonerror = false
  options.config = "/root/right_test/resat/config/config_#{ENV['CONFIG_FILE']}.yaml"
  options.schemasdir = '/usr/lib/ruby/gems/1.8/gems/resat-0.7.3/schemas'
  options.loglevel = "info"
  options.logfile = "/tmp/resat.log"
  options.target = '/root/right_test/resat/scenarios/server_template_scenarios/cleanup/resat_delete_volumes.yaml'
  options
end


Resat::Log.init(get_volumes_options)
has_volumes = true
#get IDs and if any exist, delete the volume with that ID number
while has_volumes do
  engine = Resat::Engine.new(get_volumes_options)
  engine.run
  has_volumes = engine.succeeded? && Resat::Variables.include?('volume_id')
  if has_volumes
    engine = Resat::Engine.new(delete_volume_options(Resat::Variables['volume_id']))
    engine.run
  end
  break unless engine.succeeded?
end

  end
end