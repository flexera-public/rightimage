#
# Cookbook Name:: rightimage
# Recipe:: default
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

directory "/tmp/rightscale/rackspace_rebundle" do
  action :create
  recursive true
end

git "/tmp/rightscale/rackspace_rebundle" do
  repository "git@github.com:rightscale/rightimage_rebundle.git"
  revision "master"
  action :sync
end

bash "install bundler" do
  flags "-ex"
  code "gem install bundler --no-ri --no-rdoc"
end

bash "install bundled gems" do
  flags "-ex"
  code "bundle install"
  cwd "/tmp/rightscale/rackspace_rebundle"
end

bash "upload code to the instance" do
  flags "-e +x"
  code <<-EOH
  export AWS_ACCESS_KEY_ID=#{node[:rightimage][:aws_access_key_id]}
  export AWS_SECRET_ACCESS_KEY=#{node[:rightimage][:aws_secrete_access_key]}
  bundle exec bin/launch --provider #{node[:rightimage][:cloud]} --rightlink #{node[:rightimage][:sandbox_repo_tag]} --image-id #{node[:rightimage][:rebundle_base_image_id]}
  EOH
  cwd "/tmp/rightscale/rackspace_rebundle"
end

directory "/tmp/rightscale/dist" do
  action :create
  recursive true
end

bash "get the build package from remote" do
  flags "-ex"
  code "scp -i config/private_key root@`cat config/hostname`:/root/.rightscale/*.rpm ."
  cwd "/tmp/rightscale/dist"
end

# TODO - upload package to s3
# TODO - bundle instance
# TODO - kill running instance