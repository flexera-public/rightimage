#
# Rakefile for Chef Server Repository
#
# Author:: Adam Jacob (<adam@opscode.com>)
# Copyright:: Copyright (c) 2008 Opscode, Inc.
# License:: Apache License, Version 2.0
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

require 'rubygems'
require 'chef'
require 'json'

require 'cucumber/rake/task'
Cucumber::Rake::Task.new do |t|
  t.cucumber_opts = %w{--format pretty}
end

# Load constants from rake config file.
###
# Company and SSL Details
###

# The company name - used for SSL certificates, and in srvious other places
COMPANY_NAME = "RightScale, Inc."

# The Country Name to use for SSL Certificates
SSL_COUNTRY_NAME = "US"

# The State Name to use for SSL Certificates
SSL_STATE_NAME = "CA"

# The Locality Name for SSL - typically, the city
SSL_LOCALITY_NAME = "Santa Barbara"

# What department?
SSL_ORGANIZATIONAL_UNIT_NAME = "cookbook_hackers"

# The SSL contact email address
SSL_EMAIL_ADDRESS = "cary@rightscale.com"

# License for new Cookbooks
# Can be :apachev2 or :none
NEW_COOKBOOK_LICENSE = :none

###
# Useful Extras (which you probably don't need to change)
###

# The top of the repository checkout
TOPDIR = File.expand_path(File.join(File.dirname(__FILE__), "."))

# Where to store certificates generated with ssl_cert
CADIR = File.expand_path(File.join(TOPDIR, "certificates"))

# Where to store the mtime cache for the recipe/template syntax check
TEST_CACHE = File.expand_path(File.join(TOPDIR, ".rake_test_cache"))


# Detect the version control system and assign to $vcs. Used by the update
# task in chef_repo.rake (below). The install task calls update, so this 
# is run whenever the repo is installed.
#
# Comment out these lines to skip the update.

if File.directory?(File.join(TOPDIR, ".svn"))
  $vcs = :svn
elsif File.directory?(File.join(TOPDIR, ".git"))
  $vcs = :git
end

# Load common, useful tasks from Chef.
# rake -T to see the tasks this loads.

load 'chef/tasks/chef_repo.rake'

# My tasks to help work with mulitple repos 
#
projects = %w[../cookbooks_premium ../cookbooks_public ./ ]
opscode = "." #"#{ENV['HOME']}/src/cookbooks"

desc "Update local repositories from upstream"
task :update do
  projects.each do |p|
    dir="#{opscode}/#{p}"
		Dir.chdir(dir) do
			puts "======================="
			puts "Dir: #{dir}"
      puts `git pull --rebase rightscale master`
			puts "======================="
    end
  end
end

desc "Push local repositories to origin"
task :push do
  projects.each do |p|
    dir="#{opscode}/#{p}"
		Dir.chdir(dir) do
			puts "======================="
			puts "Dir: #{dir}"
		  puts `git push`
			puts "======================="
    end
  end
end

desc "Commit any changes in local repos"
task :commit do
  projects.each do |p|
    dir="#{opscode}/#{p}"
		Dir.chdir(dir) do
			puts "======================="
			puts "Dir: #{dir}"
      puts `git add .`
		  puts `git commit -m 'development commit'`
			puts "======================="
    end
  end
end

desc "Show diff for all repos"
task :diff do
  projects.each do |p|
    dir="#{opscode}/#{p}"
		Dir.chdir(dir) do
			puts "======================="
			puts "Dir: #{dir}"
			puts `git diff`
			puts "======================="
    end
  end
end

desc "Show status for all repos"
task :status do
  projects.each do |p|
    dir="#{opscode}/#{p}"
		Dir.chdir(dir) do
			puts "======================="
			puts "Dir: #{dir}"
			puts `git status`
			puts "======================="
    end
  end
end
# 
# desc "Update metadata for all local repos"
# task :metadata do
#   projects.each do |p|
#     dir="#{opscode}/#{p}"
#     Dir.chdir(dir) do
#       puts "======================="
#       puts "Dir: #{dir}"
#       puts `rake metadata`
#       puts "======================="
#     end
#   end
# end
