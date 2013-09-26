rightscale_marker :begin

class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

# Freeze repo again since we will be installing packages here.
rightimage_os node[:rightimage][:platform] do
  action :repo_freeze
end

# Install ruby and rubygems.
bash "install rubygems" do
  flags "-ex"
  code <<-EOF
    guest_root=#{guest_root}

    case "#{node[:rightimage][:platform]}" in
    "centos"|"rhel")
      yum -c /tmp/yum.conf --installroot=$guest_root --disablerepo=rightscale-epel -y install ruby ruby-devel rubygems
      ;;
    "ubuntu")
      chroot $guest_root apt-get -y install ruby ruby-dev rubygems
      ;;
    esac
  EOF
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

ri_tools_dir = "/tmp/rightimage_tools"

# Stage rightimge_tools gem in image.
directory "#{guest_root}#{ri_tools_dir}"

cookbook_file "#{guest_root}#{ri_tools_dir}/rightimage_tools.tar.gz" do
  source "rightimage_tools.tar.gz"
  mode "0644"
  backup false
end

cookbook_file "#{guest_root}#{ri_tools_dir}/setup_rightimage_tools.sh" do
  source "setup_rightimage_tools.sh"
  mode "0755"
  backup false
end

execute "chroot #{guest_root} #{ri_tools_dir}/setup_rightimage_tools.sh" do
  environment(node[:rightimage][:script_env])
end

execute "chroot /mnt/image bash -c 'cd /tmp/rightimage_tools && bundle exec bin/report_tool print'" do
  environment(node[:rightimage][:script_env])
end

execute "mv -f #{guest_root}/tmp/report.js #{temp_root}/#{loopback_rootname}.js"

# Uninstall ruby and rubygems.
bash "uninstall rubygems" do
  flags "-ex"
  code <<-EOF
    guest_root=#{guest_root}

    case "#{node[:rightimage][:platform]}" in
    "centos"|"rhel")
      yum -c /tmp/yum.conf --installroot=$guest_root -y remove "ruby*"
      ;;
    "ubuntu")
      chroot $guest_root apt-get -y purge "ruby*"
      ;;
    esac
  EOF
end

rightimage_os node[:rightimage][:platform] do
  action :repo_unfreeze
end


rightscale_marker :end
