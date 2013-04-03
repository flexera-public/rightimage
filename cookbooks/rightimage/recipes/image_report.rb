rightscale_marker :begin

class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

# Current rightimage_tools gem filename.
RI_TOOL_GEM = Dir.entries(File.dirname(__FILE__)+"/../files/default/").grep(/rightimage_tools.*.gem/).first

# Stage rightimge_tools gem in image.
cookbook_file "#{guest_root}/tmp/#{RI_TOOL_GEM}" do
  source RI_TOOL_GEM
  mode "0644"
  backup false
end

# This folder does not exist yet, so create it.
# Store hint files in here.
directory "#{guest_root}/etc/rightscale.d" do
  owner "root"
  group "root"
  recursive true
end

# Put the freeze-date, build-date, and rightlink version in a hint file.
ruby_block "create_hint_file" do
  block do
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

# Directory does not exist yet, so create it.
# This will store the compressed image and reports.
directory temp_root do
  owner "root"
  group "root"
  recursive true
end

bash "run_report_tool" do
  code <<-EOH
  /usr/sbin/chroot #{guest_root} gem install --no-rdoc --no-ri /tmp/#{RI_TOOL_GEM}

  # Extra path for Ubuntu.
  PATH=$PATH:/usr/local/bin
  
  # Prints report to log.
  /usr/sbin/chroot #{guest_root} report_tool print

  # Move JSON file out of image to receive MD5 checksum.
  mv #{guest_root}/tmp/report.js #{temp_root}/#{loopback_rootname}.js
  
  # Uninstall rightimage tools and some related gems.  Note that cloud providers
  # may install their own rubygems, so don't remove everything
  for gem in rest_connection right_api_client right_aws right_http_connection rightimage_tools; do 
    /usr/sbin/chroot #{guest_root} gem uninstall -aIx $gem || true
  done
  EOH
end

# Clean up report tool.
file "#{guest_root}/tmp/#{RI_TOOL_GEM}" do
  backup false
  action :delete 
end

rightscale_marker :end
