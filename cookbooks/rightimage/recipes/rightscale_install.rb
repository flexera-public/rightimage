rightscale_marker :begin

class Chef::Recipe
  include RightScale::RightImage::Helper
end

class Chef::Resource
  include RightScale::RightImage::Helper
end

bash "insert_bashrc" do 
  # note that ubuntu uses /etc/bash.bashrc and sources it automatically for us
  # also note that .bashrc in /skel already has this code so it should work 
  # normally for rightlink created users
  flags "+e -x"
  code <<-EOS
    grep ". /etc/bashrc" #{guest_root}/root/.bashrc
    if [ "$?" == "2" -o "$?" == "1" ]; then
cat <<-BASHRC >> #{guest_root}/root/.bashrc
# Source global definitions
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi
BASHRC
    fi
  EOS
end

directory "#{guest_root}/etc/rightscale.d" do
  action :create
  recursive true
end

# Put the freeze-date, build-date, and rightlink version in a hint file.
ruby_block "create_hint_file" do
  block do
    require 'json'

    hint = Hash.new
    # Pull from Chef input.
    hint["freeze-date"] = mirror_freeze_date
    # Current date.
    hint["build-date"] = Time.new.strftime("%Y%m%d")
    hint["build-id"] = "#{node[:rightimage][:build_id]}"
    # Pull from chef input if full image.
    if node[:rightimage][:build_mode] == "full"
      hint["rightlink-version"] = "#{node[:rightimage][:rightlink_version]}"
      hint["hypervisor"] = "#{node[:rightimage][:hypervisor]}"
    end

    # Save hash as JSON file.
    File.open("#{guest_root}/etc/rightscale.d/rightimage-release.js","w") do |f|
      f.write(JSON.pretty_generate(hint))
    end
  end
end


include_recipe "rightimage::rightscale_rightlink"

rightscale_marker :end
