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
  revision "jes_add_sandbox_option"
  action :sync
end

bash "install bundler" do
  flags "-ex"
  code "gem install bundler --no-ri --no-rdoc"
end

bash "install bundled gems" do
  flags "-ex"
  code "bundle install"
  cwd BaseRhelConstants::REBUNDLE_SOURCE_PATH
end

bash "upload code to the instance" do
  flags "-e +x"
  environment({'AWS_ACCESS_KEY_ID'    => node[:rightimage][:aws_access_key_id],
               'AWS_SECRET_ACCESS_KEY'=> node[:rightimage][:aws_secret_access_key]})
  code <<-EOH
  bundle exec bin/launch --provider #{node[:rightimage][:cloud]} --rightlink #{node[:rightimage][:rightlink_version]} --image-id #{node[:rightimage][:rebundle_base_image_id]} --sandbox-revision #{node[:rightimage][:sandbox_repo_tag]} --flavor-id c1.medium
  EOH
  cwd BaseRhelConstants::REBUNDLE_SOURCE_PATH
end

directory BaseRhelConstants::LOCAL_PACKAGE_PATH do
  action :create
  recursive true
end

bash "get the build package from remote" do
  flags "-ex"
  code "scp -i config/private_key root@`cat config/hostname`:/root/.rightscale/*.rpm #{BaseRhelConstants::LOCAL_PACKAGE_PATH}"
  cwd BaseRhelConstants::REBUNDLE_SOURCE_PATH
end

# TODO - upload package to s3
# TODO - bundle instance
# TODO - kill running instance