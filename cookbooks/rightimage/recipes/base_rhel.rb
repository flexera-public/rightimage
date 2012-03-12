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

module BaseRhelConstants
  REBUNDLE_SOURCE_PATH  = "/tmp/rightscale/rightimage_rebundle"
  LOCAL_PACKAGE_PATH    = "/tmp/rightscale/dist"
end

directory BaseRhelConstants::REBUNDLE_SOURCE_PATH do
  action :create
  recursive true
end

git BaseRhelConstants::REBUNDLE_SOURCE_PATH do
  repository "git@github.com:rightscale/rightimage_rebundle.git"
  revision "master"
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
  flags "-e +x"
  environment({'AWS_ACCESS_KEY_ID'    => node[:rightimage][:aws_access_key_id],
               'AWS_SECRET_ACCESS_KEY'=> node[:rightimage][:aws_secret_access_key]})
  cwd BaseRhelConstants::REBUNDLE_SOURCE_PATH
  region_opt = node[:rightimage][:cloud] == "ec2" ? "--region #{node[:ec2][:placement][:availability_zone].chop}": ""
  code <<-EOH
  /opt/rightscale/sandbox/bin/ruby bin/launch --provider #{node[:rightimage][:cloud]} --image-id #{node[:rightimage][:rebundle_base_image_id]} #{region_opt} --flavor-id c1.medium --no-auto
  EOH
end

bash "upload code to the remote instance" do
  flags "-e +x"
  cwd BaseRhelConstants::REBUNDLE_SOURCE_PATH
  code <<-EOH
  /opt/rightscale/sandbox/bin/ruby bin/upload --rightlink #{node[:rightimage][:rightlink_version]} --no-checkout --no-configure
  EOH
end

bash "configure the remote instance" do
  flags "-e +x"
  cwd BaseRhelConstants::REBUNDLE_SOURCE_PATH
  code <<-EOH
  /opt/rightscale/sandbox/bin/ruby bin/configure --rightlink #{node[:rightimage][:rightlink_version]}
  EOH
end

directory BaseRhelConstants::LOCAL_PACKAGE_PATH do
  action :create
  recursive true
end 
 
bash "get the build package from remote" do
  flags "-ex"
  cwd BaseRhelConstants::REBUNDLE_SOURCE_PATH
  code "scp -i config/private_key root@`cat config/hostname`:/root/.rightscale/*.rpm #{BaseRhelConstants::LOCAL_PACKAGE_PATH}"
end

bash "bundle instance" do
  flags "-e +x"
  cwd BaseRhelConstants::REBUNDLE_SOURCE_PATH
  environment({'AWS_ACCESS_KEY_ID'    => node[:rightimage][:aws_access_key_id],
               'AWS_SECRET_ACCESS_KEY'=> node[:rightimage][:aws_secret_access_key]})
  code <<-EOH
  /opt/rightscale/sandbox/bin/ruby bin/bundle --name #{image_name} --aws-cert /tmp/AWS_X509_CERT.pem --aws-key /tmp/AWS_X509_KEY.pem
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
  flags "-e +x"
  cwd BaseRhelConstants::REBUNDLE_SOURCE_PATH
  code "/opt/rightscale/sandbox/bin/ruby bin/destroy"
end  

rs_utils_marker :end
