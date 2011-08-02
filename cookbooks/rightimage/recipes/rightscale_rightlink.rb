execute "insert_rightlink_version" do 
  command  "echo -n " + node[:rightimage][:rightlink_version] + " > " + node[:rightimage][:mount_dir] + "/etc/rightscale.d/rightscale-release"
end

bash "checkout_repo" do 
  not_if "test -e #{node[:rightimage][:mount_dir]}/tmp/sandbox_builds"
  code <<-EOC
    set -e
    cd #{node[:rightimage][:mount_dir]}/tmp
    if [ -d sandbox_builds ]; then mv sandbox_builds sandbox_builds.$RANDOM; fi
    git clone git@github.com:rightscale/sandbox_builds.git 
    cd sandbox_builds 
    git checkout #{node[:rightimage][:sandbox_repo_tag]} --force
    git submodule init 
    git submodule update
    cd repos/right_net
    git submodule init 
    git submodule update
    cd ../..

  EOC
end

bash "build_rightlink" do 
  not_if "ls #{node[:rightimage][:mount_dir]}/tmp/sandbox_builds/dist/ | grep rightscale" 
  code <<-EOC
    set -e
    set -x
    export ARCH=#{node[:rightimage][:arch]}
    cat <<-CHROOT_SCRIPT > #{node[:rightimage][:mount_dir]}/tmp/build_rightlink.sh
#!/bin/bash -ex
cd /tmp/sandbox_builds
export RS_VERSION=#{node[:rightimage][:rightlink_version]}
rake submodules:sandbox:create   
rake right_link:#{node[:rightimage][:package_type]}:build
export AWS_ACCESS_KEY_ID=#{node[:rightimage][:aws_access_key_id_for_upload]}
echo AAKI: #{node[:rightimage][:aws_access_key_id_for_upload]}
export AWS_SECRET_ACCESS_KEY=#{node[:rightimage][:aws_secret_access_key_for_upload]}
echo ASAK: #{node[:rightimage][:aws_secret_access_key_for_upload]}
export AWS_CALLING_FORMAT=SUBDOMAIN 

# echo rake right_link:#{node[:rightimage][:package_type]}:upload 
# rake right_link:#{node[:rightimage][:package_type]}:upload 

CHROOT_SCRIPT
    chmod +x #{node[:rightimage][:mount_dir]}/tmp/build_rightlink.sh
    chroot #{node[:rightimage][:mount_dir]} /tmp/build_rightlink.sh
    rm -rf #{node[:rightimage][:mount_dir]}/tmp/build_rightlink.sh
  EOC

end

bash "install_rightlink" do 
#  not_if "test -e #{node[:rightimage][:mount_dir]}/etc/init.d/rightimage"
  code <<-EOC
    set -e
    rm -rf #{node[:rightimage][:mount_dir]}/opt/rightscale/
    install #{node[:rightimage][:mount_dir]}/tmp/sandbox_builds/seed_scripts/rightimage  #{node[:rightimage][:mount_dir]}/etc/init.d/rightimage --mode=0755

    mkdir -p #{node[:rightimage][:mount_dir]}/root/.rightscale
    cp #{node[:rightimage][:mount_dir]}/tmp/sandbox_builds/dist/* #{node[:rightimage][:mount_dir]}/root/.rightscale
    chmod 0770 #{node[:rightimage][:mount_dir]}/root/.rightscale
    chmod 0440 #{node[:rightimage][:mount_dir]}/root/.rightscale/*

    if [ "#{node[:rightimage][:platform]}" == "ubuntu" ]; then
      chroot #{node[:rightimage][:mount_dir]} update-rc.d rightimage start 96 2 3 4 5 . stop 1 0 1 6 .
    else
      chroot #{node[:rightimage][:mount_dir]} chkconfig --add rightimage
    fi

    # remove sandbox repo
    rm -rf #{node[:rightimage][:mount_dir]}/tmp/sandbox_builds
  EOC
end
