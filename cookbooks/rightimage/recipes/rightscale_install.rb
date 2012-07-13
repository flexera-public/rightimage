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
  # note that ubuntu uses /etc/bash.bashrc and sources it automatically for us
  # also note that .bashrc in /skel already has this code so it should work 
  # normally for rightlink created users
  flags "+e-x"
  code <<-EOS
    grep ". /etc/bashrc" #{guest_root}/root/.bashrc
    if [ "$?" == "2" -o "$?" == "1" ]; then
cat <<-BASHRC >> #{guest_root}/root/.bashrc
# Source global definitions
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi
BASHRC
    fi
  EOS
end
rightscale_marker :end
