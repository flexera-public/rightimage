base_dir = node[:test][:path][:src]
type = node[:resat][:test][:type]
template = node[:resat][:test][:template]
os = node[:resat][:test][:os]
senario_root = "#{base_dir}/tests/deployments/#{type}"
config_file = "#{senario_root}/config/#{template}/#{os}/config.yaml"
schema_path = "/usr/lib/ruby/gems/1.8/gems/resat-0.7.3/schemas"
log_file = node[:resat][:log_file]

execute "resat -f -c #{config_file} #{senario_root}/reboot.yaml -s #{schema_path} -F #{log_file}"
