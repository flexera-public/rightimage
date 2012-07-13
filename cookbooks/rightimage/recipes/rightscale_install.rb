rightscale_marker :begin

class Chef::Recipe
  include RightScale::RightImage::Helper
end

class Chef::Resource
  include RightScale::RightImage::Helper
end

directory "#{guest_root}/etc/rightscale.d" 

# Install rightscale package based on revision number
if node[:rightimage][:rightlink_version] =~ /^4\.[0-9]*\.[0-9]*/
  raise "rightlink versions < 5 not supported"
else
  log "Building image with RightLink package."
  include_recipe "rightimage::rightscale_rightlink"
end

bash "insert_bashrc" do 
  code <<-EOS
    # Move the current .bashrc out of the way if it exists
    if [ -f #{guest_root}/root/.bashrc ]; then
      mv  -f #{guest_root}/root/.bashrc  \
             #{guest_root}/root/save_bashrc
    fi
    # Put the RS special sauce at the top of the bashrc
cat <<-BASHRC >> #{guest_root}/root/.bashrc

export PATH=\\$PATH:/home/ec2/bin
export EC2_HOME=/home/ec2

# Source global definitions
if [ -f /etc/bashrc ]; then
        . /etc/bashrc
fi
BASHRC
    if [ -f #{guest_root}/root/save_bashrc ]; then
      # Append the existing bashrc to the one just created - if it exists
      cat #{guest_root}/root/save_bashrc \
              >>  #{guest_root}/root/.bashrc
      rm -f #{guest_root}/root/save_bashrc
    fi
  EOS
end
rightscale_marker :end
