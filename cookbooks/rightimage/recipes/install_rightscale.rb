directory "#{node[:right_image_creator][:mount_dir]}/etc/rightscale.d" 

bash "install_rubygems" do 
  not_if  "chroot #{node[:right_image_creator][:mount_dir]} which gem" 
  code <<-EOC
set -e
set -x
ROOT=#{node[:right_image_creator][:mount_dir]}
wget -O $ROOT/tmp/rubygems.tgz http://rubyforge.org/frs/download.php/56227/rubygems-1.3.3.tgz
mkdir -p $ROOT/tmp/rubygems
tar -xzvf $ROOT/tmp/rubygems.tgz  -C $ROOT/tmp/rubygems
cat <<-CHROOT_SCRIPT > $ROOT/tmp/rubygems_install.sh
#!/bin/bash -ex
cd /tmp/rubygems/rubygems-1.3.3/
ruby setup.rb 
if [ "#{node[:right_image_creator][:platform]}" == "ubuntu" ]; then
  ln -sf /usr/bin/gem1.8 /usr/bin/gem
fi
gem source -a #{node[:right_image_creator][:mirror]}/rubygems/archive/latest/
gem source -r http://mirror.rightscale.com
gem install xml-simple net-ssh net-sftp 
gem install rake
updatedb
CHROOT_SCRIPT
chmod +x $ROOT/tmp/rubygems_install.sh
chroot $ROOT /tmp/rubygems_install.sh
EOC
end

remote_file "/tmp/s3sync.tgz" do 
   source "s3sync.tgz" 
   backup false
end

bash "install_s3_sync" do 
  code <<-EOC
    tar -xzf /tmp/s3sync.tgz -C #{node[:right_image_creator][:mount_dir]}/home
    chroot #{node[:right_image_creator][:mount_dir]} ln -sf /home/s3sync/s3sync.rb /usr/local/bin/s3sync
    chroot #{node[:right_image_creator][:mount_dir]} ln -sf /home/s3sync/s3cmd.rb /usr/local/bin/s3cmd
  EOC
end

# Install rightscale package based on revision number
if node[:right_image_creator][:rightscale_release] =~ /4\.[0-9]*\.[0-9]*/
  log "Building image with RunRightScripts package."
  include_recipe "right_image_creator::install_runrightscripts"
else
  log "Building image with RightLink package."
  include_recipe "right_image_creator::install_rightlink"
end

bash "setup_motd" do
  only_if { ::File.directory? "#{node[:right_image_creator][:mount_dir]}/etc/update-motd.d" } 
  code <<-EOC
      rm #{node[:right_image_creator][:mount_dir]}/etc/update-motd.d/10-help-text || true
      mv #{node[:right_image_creator][:mount_dir]}/etc/update-motd.d/99-footer #{node[:right_image_creator][:mount_dir]}/etc/update-motd.d/10-rightscale-message
  EOC
end

bash "insert_bashrc" do 
  code <<-EOS
    # Move the current .bashrc out of the way if it exists
    if [ -f #{node[:right_image_creator][:mount_dir]}/root/.bashrc ]; then
      mv  -f #{node[:right_image_creator][:mount_dir]}/root/.bashrc  \
             #{node[:right_image_creator][:mount_dir]}/root/save_bashrc
    fi
    # Put the RS special sauce at the top of the bashrc
cat <<-BASHRC >> #{node[:right_image_creator][:mount_dir]}/root/.bashrc

export PATH=\\$PATH:/home/ec2/bin
export EC2_HOME=/home/ec2

# Source global definitions
if [ -f /etc/bashrc ]; then
        . /etc/bashrc
fi
BASHRC
    if [ -f #{node[:right_image_creator][:mount_dir]}/root/save_bashrc ]; then
      # Append the existing bashrc to the one just created - if it exists
      cat #{node[:right_image_creator][:mount_dir]}/root/save_bashrc \
              >>  #{node[:right_image_creator][:mount_dir]}/root/.bashrc
      rm -f #{node[:right_image_creator][:mount_dir]}/root/save_bashrc
    fi
  EOS
end
