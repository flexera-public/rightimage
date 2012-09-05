rightscale_marker :begin

class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

# Current rightimage_tools gem filename.
RI_TOOL_GEM = Dir.entries(File.dirname(__FILE__)+"/../files/default/").grep(/rightimage_tools.*.gem/)

# Stage rightimge_tools gem in image.
cookbook_file "#{guest_root}/tmp/#{RI_TOOL_GEM}" do
  mode "0755"
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
    hint["freeze-date"] = "#{timestamp}"[0..7]
    # Current date.
    hint["build-date"] = Time.new.strftime("%Y%m%d")
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

bash "query_image" do
  cwd "/"
  code <<-EOH
  # If rightimage_tools is not installed, install it. Otherwise, don't.
  found="$(/usr/sbin/chroot #{guest_root} gem list rightimage_tools | grep -i rightimage_tools)"
  # Found is nil if rightimage_tools wasn't installed in image.
  if [ -z "$found" ]; then
    # Install gem into image without documentation.  
    /usr/sbin/chroot #{guest_root} gem install --no-rdoc --no-ri /tmp/#{RI_TOOL_GEM}
    # Sentinel for uninstall at end.
    found="false"
  fi

  # Run report tool in image chroot.

  # Extra path for Ubuntu.
  PATH=$PATH:/usr/local/bin
  
  # Prints report to log.
  /usr/sbin/chroot #{guest_root} report_tool "print"

  # Move JSON file out of image to receive MD5 checksum.
  mv #{guest_root}/tmp/report.js #{temp_root}/#{loopback_filename(partitioned?)}.js
  
  # If rightimage_tools was installed, uninstall it.
  if [ "$found" == "false" ]; then
    /usr/sbin/chroot #{guest_root} gem uninstall rightimage_tools
  fi

  # For base and full images, uninstall all gems when finished.
  if [ "#{node[:rightimage][:build_mode]}" == "base" ] || [ "#{node[:rightimage][:build_mode]}" == "full" ]; then
    chroot /mnt/image/ gem list | cut -d" " -f1 | chroot /mnt/image/ xargs gem uninstall -aIx
  fi
  EOH
end

# Clean up report tool.
file "#{guest_root}/tmp/report_tool.rb" do action :delete end
file "#{guest_root}/tmp/#{RI_TOOL_GEM}" do action :delete end

rightscale_marker :end
