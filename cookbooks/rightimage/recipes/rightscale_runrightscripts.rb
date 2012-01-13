rs_utils_marker :begin
mount_dir = node[:rightimage][:mount_dir]
package_release_version = node[:rightimage][:rightlink_version]
target_platform = node[:rightimage][:platform]

remote_file "#{mount_dir}/etc/init.d/righthostname" do
  mode "0755"
  source "righthostname"
  backup false
end


bash "install_runrightscripts" do 
  not_if "test -e #{node[:rightimage][:mount_dir]}/etc/init.d/rightimage"
  code <<-EOC
    set -e 
    set -x
    curl -o #{mount_dir}/tmp/rightscale_scripts.tgz http://s3.amazonaws.com/rightscale_scripts/rightscale_scripts_v#{package_release_version}.tgz
    tar -xzf #{mount_dir}/tmp/rightscale_scripts.tgz -C #{mount_dir}/opt/
    chroot #{mount_dir} ln -f /opt/rightscale/etc/init.d/rightscale /etc/init.d/rightscale
    chmod +x #{mount_dir}/opt/rightscale/etc/init.d/rightscale
    chmod +x #{mount_dir}/etc/init.d/rightscale
    if [ "#{target_platform}" == "ubuntu" ]; then
      chroot #{mount_dir} update-rc.d rightscale start 91 2 3 4 5 . stop 1 0 1 6 .
      chroot #{mount_dir} update-rc.d righthostname start 90 2 3 4 5 . stop 1 0 1 6 .
    elif [ "#{target_platform}" == "centos" ]; then
      chroot #{mount_dir} chkconfig --add rightscale
      chroot #{mount_dir} chkconfig --add righthostname
    fi  
    chroot #{mount_dir} ln -f /opt/rightscale/etc/motd /etc/motd
    echo v#{package_release_version} > #{mount_dir}/etc/rightscale-release
  EOC
end
rs_utils_marker :end
