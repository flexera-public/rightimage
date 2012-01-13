rs_utils_marker :begin
directory "#{node[:rightimage][:mount_dir]}/etc/rightscale.d" 

# Install rightscale package based on revision number
if node[:rightimage][:rightlink_version] =~ /4\.[0-9]*\.[0-9]*/
  log "Building image with RunRightScripts package."
  include_recipe "rightimage::rightscale_runrightscripts"
else
  log "Building image with RightLink package."
  include_recipe "rightimage::rightscale_rightlink"
end

bash "setup_motd" do
  only_if { ::File.directory? "#{node[:rightimage][:mount_dir]}/etc/update-motd.d" } 
  code <<-EOC
    rm #{node[:rightimage][:mount_dir]}/etc/update-motd.d/10-help-text || true
    mv #{node[:rightimage][:mount_dir]}/etc/update-motd.d/99-footer #{node[:rightimage][:mount_dir]}/etc/update-motd.d/10-rightscale-message || true
  EOC
end

bash "insert_bashrc" do 
  code <<-EOS
    # Move the current .bashrc out of the way if it exists
    if [ -f #{node[:rightimage][:mount_dir]}/root/.bashrc ]; then
      mv  -f #{node[:rightimage][:mount_dir]}/root/.bashrc  \
             #{node[:rightimage][:mount_dir]}/root/save_bashrc
    fi
    # Put the RS special sauce at the top of the bashrc
cat <<-BASHRC >> #{node[:rightimage][:mount_dir]}/root/.bashrc

export PATH=\\$PATH:/home/ec2/bin
export EC2_HOME=/home/ec2

# Source global definitions
if [ -f /etc/bashrc ]; then
        . /etc/bashrc
fi
BASHRC
    if [ -f #{node[:rightimage][:mount_dir]}/root/save_bashrc ]; then
      # Append the existing bashrc to the one just created - if it exists
      cat #{node[:rightimage][:mount_dir]}/root/save_bashrc \
              >>  #{node[:rightimage][:mount_dir]}/root/.bashrc
      rm -f #{node[:rightimage][:mount_dir]}/root/save_bashrc
    fi
  EOS
end
rs_utils_marker :end
