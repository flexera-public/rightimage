#log "syncing output"
#$stdout.sync=(true) unless $stdout.sync

#log "inserting creds"
test_dir = node[:virtual_monkey][:test_dir]

ruby_block "add creds" do
  block do
   `sed -i s%@@AWS_ACCESS_KEY_ID@@%#{node[:virtual_monkey][:account][:id]}% #{test_dir}/vmonk/lib/cuke_monk.rb`
   `sed -i s%@@AWS_SECRET_ACCESS_KEY@@%#{node[:virtual_monkey][:account][:credentials]}% #{test_dir}/vmonk/lib/cuke_monk.rb`
 end
end

ruby "run cuke tests" do
  code <<-EOH
    
require 'rubygems'
require 'rest_connection'
require 'erb'
require "#{test_dir}/vmonk/lib/deployment_monk"
require "#{test_dir}/vmonk/lib/cuke_monk" 
require '/var/spool/ec2/meta-data.rb'

puts "changing dir" 
Dir.chdir test_dir

Chef:Log.info "creating deployment monk"
dm = DeploymentMonk.new(@node[:virtual_monkey][:deployment_prefix]+'_'+(rand 9999).to_s,@node[:virtual_monkey][:template_id_list])

#dm.clouds = [ 1 ] # east only

Chef:Log.info "loading common inputs"
# first process file
inputs = ERB.new  File.read(test_dir+"/vmonk/config/"+node[:virtual_monkey][:common_inputs_file])
File.open("/tmp/vmonk_inputs", 'w') {|f| f.write(inputs.result) }

#then load file
dm.load_common_inputs("/tmp/vmonk_inputs")

Chef:Log.info "generating variations"
dm.generate_variations

Chef:Log.info "getting deloyments"
deployments = dm.get_deployments

Chef:Log.info "creating cuke monk"
cm = CukeMonk.new()

Chef:Log.info "running cuke tests"
jobs = cm.run_tests(deployments,test_dir+node[:virtual_monkey][:cuke_test_list])

Chef:Log.info "generating reports"
msg = cm.generate_reports(jobs)

Chef:Log.info "destroying deployments" 
## TODO: destroy some
#dm.destroy_all


Chef:Log.info "emailing output"
Chef:Log.info `echo "set from=#{node[:cloud][:public_ip][0]}" >> /etc/Muttrc`
Chef:Log.info `echo "#{msg}" | mail -s "VMonk run complete" #{node[:virtual_monkey][:your_email]}`

Chef:Log.info "terminating"
#`init 0 `
  EOH
end
