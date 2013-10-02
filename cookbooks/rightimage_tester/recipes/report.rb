#
# Cookbook Name:: rightimage_tester
# Recipe:: report.rb 
#
# Copyright 2011, RightScale, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS ßOF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


include_recipe "ros_upload"

report_file = "/tmp/report.js"

package "wget"
package "ruby"
package "rubygems"

bash "generate_rightimage_report" do
  flags "-e"
  # /usr/local/bin stripped from path for RightLink v5.8
  environment('PATH'=>'/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin')
  code <<-EOF
    mkdir -p /tmp/rightimage_tools
    cd /tmp/rightimage_tools 

    # Don't use remote file, broken for 10.10 (CHEF-3140)
    wget --quiet http://rightscale-rightimage.s3.amazonaws.com/files/rightimage_tools_0.6.2.tar.gz
    tar zxf rightimage_tools_*.tar.gz

    gem install bundler --no-rdoc --no-ri
    # Use --deployment flag so no gems are installed to system
    # Private is github gems, don't install those.
    (bundle check || bundle install --deployment --without private development)
    bundle exec bin/report_tool print
  EOF
end

# Insert in benchmark results if the benchmark recipe was run
ruby_block "insert benchmark results" do
  block do
    image_report = JSON.parse(::File.read(report_file))

    if ::File.exists?(node[:rightimage_tester][:benchmark_results_file])
      benchmark_contents = JSON.parse(::File.read(node[:rightimage_tester][:benchmark_results_file]))
      image_report['benchmark'] = benchmark_contents
    end

    ::File.open(report_file,"w") do |f|
      f.puts(JSON.pretty_generate(image_report))
    end
  end
end

report_name = node[:rightimage_tester][:report_name].dup
report_name << ".json" unless report_name.include?('.json')
ros_upload report_file do
  provider "ros_upload_s3"
  user node[:rightimage_tester][:aws_access_key_id]
  password node[:rightimage_tester][:aws_secret_access_key]
  container "rightimage-reports"
  remote_path report_name
  action :upload
end
