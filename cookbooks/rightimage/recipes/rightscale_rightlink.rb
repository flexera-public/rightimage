rightlink_file="rightscale_#{node[:rightimage][:rightlink_version]}-#{node[:rightimage][:platform]}_#{node[:rightimage][:release_number]}-" + ((node[:rightimage][:platform] == "ubuntu") && (node[:rightimage][:arch] == "x86_64") ? "amd64" : node[:rightimage][:arch]) + "." + (node[:rightimage][:platform] == "centos" ? "rpm" : "deb")
tag=(node[:rightimage][:sandbox_repo_tag] != "" ? node[:rightimage][:sandbox_repo_tag] : "rightlink_package_#{node[:rightimage][:rightlink_version]}")

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
    git checkout #{tag} --force
    git submodule init 
    git submodule update
    cd repos/right_net
    git submodule init 
    git submodule update
    cd ../..
  EOC
end

directory "#{node[:rightimage][:mount_dir]}/root/.rightscale" do
  owner "root"
  group "root"
  mode "0440"
  action :create
  recursive true
end

bash "download_rightlink" do
  not_if "test -f #{node[:rightimage][:mount_dir]}/root/.rightscale/#{rightlink_file}"
  code <<-EOC
    set -x
    rightlink_ver="#{node[:rightimage][:rightlink_version]}"
    rightlink_os="#{node[:rightimage][:platform]}"
    
    buckets=( rightscale_rightlink rightscale_rightlink_dev )
    locations=( $rightlink_ver/$rightlink_os $rightlink_ver / )
    
    for bucket in ${buckets[@]}
    do
      for location in ${locations[@]}
      do
        code=$(curl -o #{node[:rightimage][:mount_dir]}/root/.rightscale/#{rightlink_file} --connect-timeout 10 --fail --silent --write-out %{http_code} http://s3.amazonaws.com/$bucket/$location/#{rightlink_file})
        return=$?
        echo "BUCKET: $bucket LOCATION: $location RETURN: $return CODE: $code"
        [[ "$return" -eq "0" && "$code" -eq "200" ]] && break 2
      done
    done

    exit 0
  EOC
end

bash "build_rightlink" do 
  not_if "test -f #{node[:rightimage][:mount_dir]}/root/.rightscale/#{rightlink_file}"

  code <<-EOC
    set -ex
    export ARCH=#{node[:rightimage][:arch]}
    cat <<-CHROOT_SCRIPT > #{node[:rightimage][:mount_dir]}/tmp/build_rightlink.sh
#!/bin/bash -ex
cd /tmp/sandbox_builds
export RS_VERSION=#{node[:rightimage][:rightlink_version]}
rake submodules:sandbox:create   
rake right_link:#{node[:rightimage][:package_type]}:build

CHROOT_SCRIPT
    chmod +x #{node[:rightimage][:mount_dir]}/tmp/build_rightlink.sh
    chroot #{node[:rightimage][:mount_dir]} /tmp/build_rightlink.sh > /dev/null
    rm -rf #{node[:rightimage][:mount_dir]}/tmp/build_rightlink.sh
  EOC
end

bash "install_rightlink" do 
  code <<-EOC
    set -ex
    rm -rf #{node[:rightimage][:mount_dir]}/opt/rightscale/
    install #{node[:rightimage][:mount_dir]}/tmp/sandbox_builds/seed_scripts/rightimage  #{node[:rightimage][:mount_dir]}/etc/init.d/rightimage --mode=0755

    mkdir -p #{node[:rightimage][:mount_dir]}/root/.rightscale
    [ -f #{node[:rightimage][:mount_dir]}/tmp/sandbox_builds/dist/* ] && cp #{node[:rightimage][:mount_dir]}/tmp/sandbox_builds/dist/* #{node[:rightimage][:mount_dir]}/root/.rightscale
    chmod 0770 #{node[:rightimage][:mount_dir]}/root/.rightscale
    chmod 0440 #{node[:rightimage][:mount_dir]}/root/.rightscale/*

    case "#{node[:rightimage][:platform]}" in 
      "ubuntu" )
        chroot #{node[:rightimage][:mount_dir]} update-rc.d rightimage start 96 2 3 4 5 . stop 1 0 1 6 .
        ;; 
      * )
        chroot #{node[:rightimage][:mount_dir]} chkconfig --add rightimage
        ;;
    esac
  EOC
end

# remove sandbox repo
directory "#{node[:rightimage][:mount_dir]}/tmp/sandbox_builds" do
  recursive true
  action :delete
end

bash "upload_rightlink" do
  code <<-EOC
    bucket="rightscale_rightlink"
    [ #{node[:rightimage][:debug]} == "true" ] && bucket="${bucket}_dev"
    rightlink_ver="#{node[:rightimage][:rightlink_version]}"
    rightlink_os="#{node[:rightimage][:platform]}"
    rightlink_path=$rightlink_ver/$rightlink_os/#{rightlink_file}
 
    curl --output /dev/null --head --silent --fail --connect-timeout 10 http://s3.amazonaws.com/$bucket/$rightlink_path
    if [ "$?" -ne "0" ]; then
      export AWS_ACCESS_KEY_ID=#{node[:rightimage][:aws_access_key_id_for_upload]}
      echo AAKI: #{node[:rightimage][:aws_access_key_id_for_upload]}
      export AWS_SECRET_ACCESS_KEY=#{node[:rightimage][:aws_secret_access_key_for_upload]}
      echo ASAK: #{node[:rightimage][:aws_secret_access_key_for_upload]}
      export AWS_CALLING_FORMAT=SUBDOMAIN 
      
      echo "Uploading RightLink $rightlink_ver to $bucket"
      set -ex
      s3cmd put $bucket:$rightlink_path #{node[:rightimage][:mount_dir]}/root/.rightscale/#{rightlink_file} x-amz-acl:public-read
    fi
  EOC
end
