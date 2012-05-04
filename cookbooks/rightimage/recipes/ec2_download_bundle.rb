#
# Cookbook Name:: rightimage
# Recipe:: ec2_download_bundle
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
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

rs_utils_marker :begin
class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end

# Force set region input
full_region = node[:ec2][:placement][:availability_zone][0..-2]
split = full_region.split("-")
number = split.last.chomp
region = split[0..-2].join("-")
region << "-" + split.last if number != "1"
node[:rightimage][:region] = region

directory guest_root do
  action :create
end 
directory target_raw_root do
  action :create
end 
directory migrate_temp_bundled do
  recursive true
  action :create
end 
directory migrate_temp_unbundled do
  action :create
end 

bash "download bundle" do
  flags "-ex"
  environment ({'EC2_HOME' => "/home/ec2" })
  code <<-EOH
#create keyfiles for bundle
    echo "#{node[:rightimage][:aws_509_key]}" > /tmp/AWS_X509_KEY.pem
    echo "#{node[:rightimage][:aws_509_cert]}" > /tmp/AWS_X509_CERT.pem

    /home/ec2/bin/ec2-download-bundle -b #{node[:rightimage][:image_source_bucket]} -a #{node[:rightimage][:aws_access_key_id]} -s #{node[:rightimage][:aws_secret_access_key]} -p #{node[:rightimage][:image_name]} -k /tmp/AWS_X509_CERT.pem --debug --retry -d #{migrate_temp_bundled}
    /home/ec2/bin/ec2-unbundle -m #{migrate_temp_bundled}/#{node[:rightimage][:image_name]}.manifest.xml -k /tmp/AWS_X509_KEY.pem -d #{migrate_temp_unbundled} -s #{migrate_temp_bundled}
    ln -s #{migrate_temp_unbundled}/#{node[:rightimage][:image_name]} #{loopback_file(partitioned?)}

    #remove keys
    rm -f /tmp/AWS_X509_KEY.pem
    rm -f /tmp/AWS_X509_CERT.pem
  EOH
end
rs_utils_marker :end
