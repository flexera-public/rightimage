directory "#{node[:rightimage][:mount_dir]}/etc/rightscale.d" 

bash "install_rubygems" do 
  not_if  "chroot #{node[:rightimage][:mount_dir]} which gem" 
  code <<-EOC
set -e
set -x
ROOT=#{node[:rightimage][:mount_dir]}

function get_rubygems {
  wget -O $ROOT/tmp/rubygems.tgz $2 
  tar -xzvf $ROOT/tmp/rubygems.tgz  -C $ROOT/tmp
  mv $ROOT/tmp/rubygems-$1 $ROOT/tmp/rubygems
}

ruby_ver=`chroot $ROOT ruby --version`
if [[ $ruby_ver == *1.8.5* ]] ; then
  get_rubygems 1.3.3 http://rubyforge.org/frs/download.php/56227/rubygems-1.3.3.tgz
else
  get_rubygems 1.3.7 http://rubyforge.org/frs/download.php/70696/rubygems-1.3.7.tgz
fi

cat <<-CHROOT_SCRIPT > $ROOT/tmp/rubygems_install.sh
#!/bin/bash -ex
cd /tmp/rubygems
ruby setup.rb 
if [ "#{node[:rightimage][:platform]}" == "ubuntu" ]; then
  ln -sf /usr/bin/gem1.8 /usr/bin/gem
fi
gem source -a #{node[:rightimage][:mirror]}/rubygems/archive/latest/
gem source -r http://mirror.rightscale.com
gem install xml-simple net-ssh net-sftp 
gem install rake
updatedb
CHROOT_SCRIPT
chmod +x $ROOT/tmp/rubygems_install.sh
chroot $ROOT /tmp/rubygems_install.sh
EOC
end

# remote_file "/tmp/s3sync.tgz" do 
#    source "s3sync.tgz" 
#    backup false
# end
# 
# bash "install_s3_sync" do 
#   code <<-EOC
#     tar -xzf /tmp/s3sync.tgz -C #{node[:rightimage][:mount_dir]}/home
#     chroot #{node[:rightimage][:mount_dir]} cp -pf /home/s3sync/s3sync.rb /usr/local/bin/s3sync
#     chroot #{node[:rightimage][:mount_dir]} cp -pf /home/s3sync/s3cmd.rb /usr/local/bin/s3cmd
#   EOC
# end

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
      mv #{node[:rightimage][:mount_dir]}/etc/update-motd.d/99-footer #{node[:rightimage][:mount_dir]}/etc/update-motd.d/10-rightscale-message
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
