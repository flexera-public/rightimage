#
# Cookbook Name:: resat
# Recipe:: default
#

cucumber_run_features "run cuke tests" do
  cwd "#{node[:resat][:base_dir]}/tests"
  tags [ node[:resat][:test][:type] ]
end


