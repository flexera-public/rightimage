rightscale_marker :begin
class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

# Stage report tool in image.
cookbook_file "/mnt/image/tmp/report_tool.rb" do
  source "report_tool.rb"
  mode "0755"
end

bash "query_image" do
  cwd "/"
  code <<-EOH
  # If json is not installed, install it. Otherwise, don't.
  found="$(/usr/sbin/chroot #{guest_root} gem list json | grep -i json)"
  # Found is nil if json wasn't in installed list.
  if [ -z "$found" ]; then  
    /usr/sbin/chroot #{guest_root} gem install json
    # Sentinel for uninstall at end.
    found="false"
  fi

  # Run report tool in image chroot.
  # Input determines if json is printed to log.
  if [ "#{node[:rightimage][:print_json]}" == "true" ]; then
    /usr/sbin/chroot #{guest_root} /tmp/report_tool.rb "print"
  else
    /usr/sbin/chroot #{guest_root} /tmp/report_tool.rb
  fi

  # Move json file out of image to receive md5.  
  mv /mnt/image/tmp/report.js #{temp_root}/#{loopback_filename(false)}.js
  
  # Clean up report tool.
  rm -f /mnt/image/tmp/report_tool.rb

  # If json was installed, uninstall it.
  if [ "$found" == "false" ]; then
    /usr/sbin/chroot #{guest_root} gem uninstall json
  fi
  EOH
end

rightscale_marker :end
