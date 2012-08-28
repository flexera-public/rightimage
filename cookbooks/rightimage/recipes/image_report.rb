rightscale_marker :begin

class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

# Stage report tool in image.
cookbook_file "#{guest_root}/tmp/report_tool.rb" do
  source "report_tool.rb"
  mode "0755"
end

# This folder does not exist yet, so create it.
# Store hint files in here.
directory "#{guest_root}/etc/rightscale.d" do
  owner "root"
  group "root"
  recursive true
end

# Provide the freeze-date and build-date to the chrooted report tool.
ruby_block "create_hint_file" do
  block do
    hint = Hash.new
    # Pull from Chef input.
    hint["freeze-date"] = "#{timestamp}"[0..7]
    # Current date.
    hint["build-date"] = Time.new.strftime("%Y%m%d")
    # Pull from chef input if full image.
    if node[:rightimage][:build_mode] == "full"
      hint["rightlink-version"] = "#{node[:rightimage][:rightlink_version]}"
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

bash "query_image" do
  cwd "/"
  code <<-EOH
  # If json is not installed, install it. Otherwise, don't.
  found="$(/usr/sbin/chroot #{guest_root} gem list json | grep -i json)"
  # Found is nil if json wasn't installed in image.
  if [ -z "$found" ]; then  
    /usr/sbin/chroot #{guest_root} gem install json
    # Sentinel for uninstall at end.
    found="false"
  fi

  # Run report tool in image chroot.
  # Prints report to log.
  /usr/sbin/chroot #{guest_root} /tmp/report_tool.rb "print"

  # Move json file out of image to receive md5.  
  mv #{guest_root}/tmp/report.js #{temp_root}/#{loopback_filename(false)}.js
  
  # If json was installed, uninstall it.
  if [ "$found" == "false" ]; then
    /usr/sbin/chroot #{guest_root} gem uninstall json
  fi
  EOH
end

# Clean up report tool.
file "#{guest_root}/tmp/report_tool.r" do action :delete end

rightscale_marker :end
