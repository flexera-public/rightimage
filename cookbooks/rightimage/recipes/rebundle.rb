rightscale_marker :begin
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


class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end
class Chef::Resource::File
  include RightScale::RightImage::Helper
end

module Rebundle
  REBUNDLE_SOURCE_PATH  = "/tmp/rightscale/rightimage_rebundle"
end

packages = case node[:platform]
           when "ubuntu" then %w(libxml2-dev libxslt1-dev)
           when "centos", /redhat/ then %w(libxml2-devel libxslt-devel)
           end 

packages.each { |p| package p }

if node[:languages][:ruby][:version] >= "1.8.7"
  # Use system ruby if possible
  ruby_bin_dir = ::File.dirname(node[:languages][:ruby][:ruby_bin])
else
  ruby_bin_dir = "/opt/rightscale/sandbox/bin"
end

directory Rebundle::REBUNDLE_SOURCE_PATH do
  action :create
  recursive true 
end

# Disable prompting to verify host key since it breaks the automation
directory "/root/.ssh" do
  recursive true
  mode "0700"
end

bash "disable ssh ask to verify host key" do
  code <<-EOH
    grep "StrictHostKeyChecking no" /root/.ssh/config
    if [ "$?" == "2" -o "$?" == "1" ]; then
      echo "StrictHostKeyChecking no" >> /root/.ssh/config
    fi
  EOH
end

git Rebundle::REBUNDLE_SOURCE_PATH do
  repository node[:rightimage][:rebundle_git_repository]
  revision node[:rightimage][:rebundle_git_revision]
  action :sync
end

bash "setup keyfiles" do
  not_if { ::File.exists? "/tmp/AWS_X509_KEY.pem" }
  code <<-EOH
    echo "#{node[:rightimage][:aws_509_key]}" > /tmp/AWS_X509_KEY.pem
    echo "#{node[:rightimage][:aws_509_cert]}" > /tmp/AWS_X509_CERT.pem
  EOH
end

package "openssl" do
  only_if { node[:rightimage][:cloud] == "google" }
end

bash "setup google auth" do
  only_if { node[:rightimage][:cloud] == "google" }
  code <<-EOH
    openssl pkcs12 -export -out #{google_p12_path} -inkey #{node[:rightimage][:google][:service_key]} -in #{node[:rightimage][:google][:service_cert]} -passout pass:notasecret
    chmod 0400 #{google_p12_path}
  EOH
end

bash "check that image doesn't exist" do
  only_if { node[:rightimage][:cloud] == "ec2" }
  flags "-e"
  code <<-EOH
    #{setup_ec2_tools_env}
    set -x

    images=`/home/ec2/bin/ec2-describe-images --private-key /tmp/AWS_X509_KEY.pem --cert /tmp/AWS_X509_CERT.pem -o self --url #{node[:rightimage][:ec2_endpoint]} --filter name=#{image_name}`
    if [ -n "$images" ]; then
      echo "Found existing image, aborting:"
      echo $images
      exit 1
    fi 
  EOH
end

bash "install bundler" do
  flags "-ex"
  code "#{ruby_bin_dir}/gem install bundler --no-ri --no-rdoc --bindir #{ruby_bin_dir}"
end

bash "install bundled gems" do
  flags "-ex"
  code "#{ruby_bin_dir}/bundle install --deployment"
  cwd Rebundle::REBUNDLE_SOURCE_PATH
end

bash "launch the remote instance" do
  flags "-ex"
  environment(cloud_credentials)
  cwd Rebundle::REBUNDLE_SOURCE_PATH
  region_opt = case node[:rightimage][:cloud]
               when "ec2" then "#{node[:ec2][:placement][:availability_zone].chop}"
               when "google" || /rackspace/i then "#{node[:rightimage][:datacenter]}"
               else ""
               end

  region_opt = "--region #{region_opt}" if region_opt =~ /./
  resize_opt = node[:rightimage][:cloud] == "ec2" ? "--resize #{node[:rightimage][:root_size_gb]}" : ""
  flavor_opt = case node[:rightimage][:cloud]
               when "ec2" then "--flavor-id c1.medium"
               when "google" then "--flavor-id n1-standard-1"
               else ""
               end
  debug_opt = node[:rightimage][:debug] == "true" ? "--debug" : ""
  zone = node[:rightimage][:datacenter].to_s.empty? ? "US" : node[:rightimage][:datacenter]
  name_opt   = node[:rightimage][:cloud] =~ "google" || /rackspace/i ? "--hostname ri-rebundle-#{node[:rightimage][:platform]}" : ""
  name_opt << "-#{zone.downcase}" if node[:rightimage][:cloud] =~ /rackspace/i
  if node[:rightimage][:cloud] =~ /rackspace/i && !node[:rightimage][:cloud_options].to_s.empty?
    roles_opt = "--roles '#{node[:rightimage][:cloud_options]}'"
  else
    roles_opt = ""
  end
  ssh_user = node[:rightimage][:cloud] == "google" ? "--ssh-user google" : ""
  code <<-EOH
  #{ruby_bin_dir}/ruby bin/launch --provider #{node[:rightimage][:cloud]} --image-id #{node[:rightimage][:rebundle_base_image_id]} #{region_opt} #{flavor_opt} #{name_opt} #{resize_opt} #{debug_opt} #{roles_opt} #{ssh_user} --no-auto
  EOH
end

bash "upload code to the remote instance" do
  flags "-ex"
  cwd Rebundle::REBUNDLE_SOURCE_PATH
  freeze_date_opt = ""
  if mirror_freeze_date
    freeze_date_opt = "--freeze-date #{mirror_freeze_date[0..3]}-#{mirror_freeze_date[4..5]}-#{mirror_freeze_date[6..7]}"
  end
  debug_opt = node[:rightimage][:debug] == "true" ? "--debug" : ""
  staging_opt = node[:rightimage][:rightscale_staging_mirror] == "true" ? "--staging-mirror" : ""
  code <<-EOH
  #{ruby_bin_dir}/ruby bin/upload --rightlink #{node[:rightimage][:rightlink_version]} #{freeze_date_opt} #{debug_opt} #{staging_opt} --no-configure
  EOH
end

file google_p12_path do
  only_if { node[:rightimage][:cloud] == "google" }

  backup false
  action :delete
end

bash "configure the remote instance" do
  flags "-ex"
  cwd Rebundle::REBUNDLE_SOURCE_PATH
  debug_opt = node[:rightimage][:debug] == "true" ? "--debug" : ""
  code <<-EOH
  #{ruby_bin_dir}/ruby bin/configure --rightlink #{node[:rightimage][:rightlink_version]} #{debug_opt}
  EOH
end

bash "run clean script on remote instance" do
  flags "-ex"
  cwd Rebundle::REBUNDLE_SOURCE_PATH
  code <<-EOH
  #{ruby_bin_dir}/ruby bin/clean
  EOH
end

bash "bundle instance" do
  flags "-ex"
  cwd Rebundle::REBUNDLE_SOURCE_PATH
  environment(cloud_credentials)
  code <<-EOH
  #{ruby_bin_dir}/ruby bin/bundle --name #{node[:rightimage][:image_name]}
  EOH
end
#

bash "remove keys" do
  only_if { ::File.exists? "/tmp/AWS_X509_KEY.pem" }
  code <<-EOH
    #remove keys
    rm -f /tmp/AWS_X509_KEY.pem
    rm -f /tmp/AWS_X509_CERT.pem
  EOH
end 

ruby_block "store image id" do
  block do
    image_id = nil
    
    # read id which was written in previous stanza
    ::File.open(::File.join(Rebundle::REBUNDLE_SOURCE_PATH,"config","imageid"), "r") { |f| image_id = f.read() }
    
    # add to global id store for use by other recipes
    id_list = RightImage::IdList.new(Chef::Log)
    id_list.add(image_id)
  end 
end

bash "destroy instance" do
  flags "-ex"
  cwd Rebundle::REBUNDLE_SOURCE_PATH
  environment(cloud_credentials)
  code "#{ruby_bin_dir}/ruby bin/destroy"
end  

rightscale_marker :end
