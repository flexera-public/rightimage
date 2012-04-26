rs_utils_marker :begin
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

module BaseRhelConstants
  REBUNDLE_SOURCE_PATH  = "/tmp/rightscale/rightimage_rebundle"
  LOCAL_PACKAGE_PATH    = "/tmp/rightscale/dist"
end

packages = case node[:platform]
           when "ubuntu" then %w(libxml2-dev libxslt1-dev)
           when "centos", /redhat/ then %w(libxml2-devel libxslt-devel)
           end 

packages.each { |p| package p }

directory BaseRhelConstants::REBUNDLE_SOURCE_PATH do
  action :create
  recursive true
end

git BaseRhelConstants::REBUNDLE_SOURCE_PATH do
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
  code "/opt/rightscale/sandbox/bin/gem install bundler --no-ri --no-rdoc"
end

bash "install bundled gems" do
  flags "-ex"
  code "/opt/rightscale/sandbox/bin/bundle install"
  cwd BaseRhelConstants::REBUNDLE_SOURCE_PATH
end

bash "launch the remote instance" do
  flags "-ex"
  environment(cloud_credentials)
  cwd BaseRhelConstants::REBUNDLE_SOURCE_PATH
  region_opt = case node[:rightimage][:cloud]
               when "ec2" then "#{node[:ec2][:placement][:availability_zone].chop}"
               when /rackspace/i then "#{node[:rightimage][:datacenter]}"
               else ""
               end

  region_opt = "--region #{region_opt}" if region_opt =~ /./
  resize_opt = node[:rightimage][:cloud] == "ec2" ? "--resize #{node[:rightimage][:root_size_gb]}" : ""
  flavor_opt = node[:rightimage][:cloud] == "ec2" ? "--flavor-id c1.medium" : ""
  zone = node[:rightimage][:datacenter].to_s.empty? ? "US" : node[:rightimage][:datacenter]
  name_opt   = node[:rightimage][:cloud] =~ /rackspace/i ? "--hostname ri-rebundle-#{node[:rightimage][:platform]}-#{zone.downcase}" : ""
  code <<-EOH
  /opt/rightscale/sandbox/bin/ruby bin/launch --provider #{node[:rightimage][:cloud]} --image-id #{node[:rightimage][:rebundle][:base_image_id]} #{region_opt} #{flavor_opt} #{name_opt} #{resize_opt} --no-auto
  EOH
end

bash "upload code to the remote instance" do
  flags "-ex"
  cwd BaseRhelConstants::REBUNDLE_SOURCE_PATH
  freeze_date_opt = ""
  if timestamp
    freeze_date_opt = "--freeze-date #{timestamp[0..3]}-#{timestamp[4..5]}-#{timestamp[6..7]}"
  end

  code <<-EOH
  /opt/rightscale/sandbox/bin/ruby bin/upload --rightlink #{node[:rightimage][:rightlink_version]} #{freeze_date_opt} --no-checkout --no-configure
  EOH
end

bash "configure the remote instance" do
  flags "-ex"
  cwd BaseRhelConstants::REBUNDLE_SOURCE_PATH
  debug_opt = node[:rightimage][:debug] == "true" ? "--debug" : ""
  code <<-EOH
  /opt/rightscale/sandbox/bin/ruby bin/configure --rightlink #{node[:rightimage][:rightlink_version]} #{debug_opt}
  EOH
end

bash "run clean script on remote instance" do
  flags "-ex"
  cwd BaseRhelConstants::REBUNDLE_SOURCE_PATH
  code <<-EOH
  /opt/rightscale/sandbox/bin/ruby bin/clean
  EOH
end

bash "bundle instance" do
  flags "-ex"
  cwd BaseRhelConstants::REBUNDLE_SOURCE_PATH
  environment(cloud_credentials)
  certs_opt = node[:rightimage][:cloud] == "ec2" ? "--aws-cert /tmp/AWS_X509_CERT.pem --aws-key /tmp/AWS_X509_KEY.pem" : ""
  code <<-EOH
  /opt/rightscale/sandbox/bin/ruby bin/bundle --name #{node[:rightimage][:image_name]} #{certs_opt}
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
    ::File.open(::File.join(BaseRhelConstants::REBUNDLE_SOURCE_PATH,"config","imageid"), "r") { |f| image_id = f.read() }
    
    # add to global id store for use by other recipes
    id_list = RightImage::IdList.new(Chef::Log)
    id_list.add(image_id)
  end 
end

bash "destroy instance" do
  flags "-ex"
  cwd BaseRhelConstants::REBUNDLE_SOURCE_PATH
  environment(cloud_credentials)
  code "/opt/rightscale/sandbox/bin/ruby bin/destroy"
end  

rs_utils_marker :end
