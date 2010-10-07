#!/bin/bash +e

# # development env
# apt-get install -y vim
# ln -s /root/Dropbox/.vimrc /root/.vimrc
# 
# # sshkeys
# ln -s /root/Dropbox/keys/my_github_key /root/.ssh/id_rsa
# chmod 600 /root/Dropbox/keys/my_github_key
# 
# # right_link agent development
# #mv /opt/rightscale/right_link/agents /opt/rightscale/right_link/agents.orig
# #ln -s /root/Dropbox/right_link/agents/ /opt/rightscale/right_link/agents
# 
# # right_link lib development
# #mv /opt/rightscale/right_link/lib /opt/rightscale/right_link/lib.orig
# #ln -s /root/Dropbox/right_link/lib/ /opt/rightscale/right_link/lib
# 
# # right_resources development
# mv /opt/rightscale/sandbox/lib/ruby/gems/1.8/gems/right_resources_premium-0.0.1 /tmp/right_resources_premium-0.0.1
# ln -s /root/Dropbox/resources /opt/rightscale/sandbox/lib/ruby/gems/1.8/gems/right_resources_premium-0.0.1

# cookbook development
ln -s /root/Dropbox/cookbooks/my_cookbooks /root/my_cookbooks
ln -s /root/Dropbox/cookbooks/premium /root/premium
ln -s /root/Dropbox/cookbooks/public /root/public
ln -s /root/Dropbox/cookbooks/opscode /root/opscode

# This file will be read by devmode::setup_cookbooks to disable RightLink downloads and use your local repos. 
echo "/root/my_cookbooks/cookbooks,/root/premium/cookbooks,/root/public/cookbooks,/root/opscode" > /tmp/cookbooks_path.txt