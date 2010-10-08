execute "insert_rightscale_release" do 
  command  "echo -n " + node[:right_image_creator][:rightscale_release] + " > " + node[:right_image_creator][:mount_dir] + "/etc/rightscale.d/rightscale-release"
end

bash "checkout_repo" do 
  not_if "test -e #{node[:right_image_creator][:mount_dir]}/tmp/sandbox_builds"
  code <<-EOC
    set -e
    cd #{node[:right_image_creator][:mount_dir]}/tmp
    if [ -d sandbox_builds ]; then mv sandbox_builds sandbox_builds.$RANDOM; fi
    git clone git@github.com:rightscale/sandbox_builds.git 
    cd sandbox_builds 
    git reset #{node[:right_image_creator][:git_repo]} --hard
    git submodule init 
    git submodule update
    cd repos/right_net
    git submodule init 
    git submodule update
    cd ../..

  EOC
end

bash "build_rightlink" do 
  not_if "ls #{node[:right_image_creator][:mount_dir]}/tmp/sandbox_builds/dist/ | grep rightscale" 
  code <<-EOC
    set -e
    set -x
    export ARCH=#{node[:right_image_creator][:arch]}
    cat <<-CHROOT_SCRIPT > #{node[:right_image_creator][:mount_dir]}/tmp/build_rightlink.sh
#!/bin/bash -ex
cd /tmp/sandbox_builds
export RS_VERSION=#{node[:right_image_creator][:rightscale_release]}
rake submodules:sandbox:create   
rake right_link:#{node[:right_image_creator][:package_type]}:build
export AWS_ACCESS_KEY_ID=#{node[:right_image_creator][:aws_access_key_id_for_upload]}
echo AAKI: #{node[:right_image_creator][:aws_access_key_id_for_upload]}
export AWS_SECRET_ACCESS_KEY=#{node[:right_image_creator][:aws_secret_access_key_for_upload]}
echo ASAK: #{node[:right_image_creator][:aws_secret_access_key_for_upload]}
export AWS_CALLING_FORMAT=SUBDOMAIN 

# echo rake right_link:#{node[:right_image_creator][:package_type]}:upload 
# rake right_link:#{node[:right_image_creator][:package_type]}:upload 

CHROOT_SCRIPT
    chmod +x #{node[:right_image_creator][:mount_dir]}/tmp/build_rightlink.sh
    chroot #{node[:right_image_creator][:mount_dir]} /tmp/build_rightlink.sh > /tmp/out
  EOC

end

bash "install_rightlink" do 
  not_if "test -e #{node[:right_image_creator][:mount_dir]}/etc/init.d/rightimage"
  code <<-EOC
    set -e
    rm -rf #{node[:right_image_creator][:mount_dir]}/opt/rightscale/
    install #{node[:right_image_creator][:mount_dir]}/tmp/sandbox_builds/seed_scripts/rightimage  #{node[:right_image_creator][:mount_dir]}/etc/init.d/rightimage --mode=0755

    mkdir -p #{node[:right_image_creator][:mount_dir]}/root/.rightscale
    cp #{node[:right_image_creator][:mount_dir]}/tmp/sandbox_builds/dist/* #{node[:right_image_creator][:mount_dir]}/root/.rightscale
    chmod 0770 #{node[:right_image_creator][:mount_dir]}/root/.rightscale
    chmod 0440 #{node[:right_image_creator][:mount_dir]}/root/.rightscale/*

    if [ "#{node[:right_image_creator][:platform]}" == "ubuntu" ]; then
      chroot #{node[:right_image_creator][:mount_dir]} update-rc.d rightimage start 96 2 3 4 5 . stop 1 0 1 6 .
    else
      chroot #{node[:right_image_creator][:mount_dir]} chkconfig --add rightimage
    fi

  EOC
end
