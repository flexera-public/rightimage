rs_utils_marker :begin
rightlink_file="rightscale_#{node[:rightimage][:rightlink_version]}-#{node[:rightimage][:platform]}_#{node[:rightimage][:release_number]}-" + ((node[:rightimage][:platform] == "ubuntu") && (node[:rightimage][:arch] == "x86_64") ? "amd64" : node[:rightimage][:arch]) + "." + (node[:rightimage][:platform] =~ /centos|rhel/ ? "rpm" : "deb")

bash "download_rightlink" do
  flags "-x"
  location1 ="#{node[:rightimage][:rightlink_version]}/#{rightlink_file}"
  location2 ="#{node[:rightimage][:rightlink_version]}/#{node[:rightimage][:platform]}/#{rightlink_file}"
  code <<-EOC
    mkdir -p #{node[:rightimage][:mount_dir]}/root/.rightscale
    
    buckets=( rightscale_rightlink rightscale_rightlink_dev )
    locations=( #{location1} #{location2})
    
    for bucket in ${buckets[@]}
    do
      for location in ${locations[@]}
      do
        code=$(curl -o #{node[:rightimage][:mount_dir]}/root/.rightscale/#{rightlink_file} --connect-timeout 10 --fail --silent --write-out %{http_code} http://s3.amazonaws.com/$bucket/$location)
        return=$?
        echo "BUCKET: $bucket LOCATION: $location RETURN: $return CODE: $code"
        [[ "$return" -eq "0" && "$code" -eq "200" ]] && break 2
      done
    done

    if test -f #{node[:rightimage][:mount_dir]}/root/.rightscale/#{rightlink_file}; then
      exit 0
    else
      echo "Failed to download RightLink.  Place the #{rightlink_file} in the S3 bucket and re-run"
      exit 1
    fi
  EOC
end

execute "insert_rightlink_version" do 
  command  "echo -n " + node[:rightimage][:rightlink_version] + " > " + node[:rightimage][:mount_dir] + "/etc/rightscale.d/rightscale-release"
end

cookbook_file "#{node[:rightimage][:mount_dir]}/etc/init.d/rightimage" do
  source "rightimage"
  backup false
  mode "0755"
end

bash "install_rightlink" do 
  flags "-ex"
  code <<-EOC
    rm -rf #{node[:rightimage][:mount_dir]}/opt/rightscale/

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
rs_utils_marker :end
