rightlink_file="rightscale_#{node[:rightimage][:rightlink_version]}-#{node[:rightimage][:platform]}_#{node[:rightimage][:release_number]}-" + ((node[:rightimage][:platform] == "ubuntu") && (node[:rightimage][:arch] == "x86_64") ? "amd64" : node[:rightimage][:arch]) + "." + (node[:rightimage][:platform] == "centos" ? "rpm" : "deb")

def get_last_release
  # lets just hard code this for now, fix it later
  # http://s3.amazonaws.com/rightscale_rightlink_dev/5.7.17/centos/2011-11-17-0900/rightscale_5.7.17-ubuntu_10.04-i386.deb
  "5.7.17/#{node[:rightimage][:platform]}/2011-11-17-0900/#{rightlink_file}"
end

bash "download_rightlink" do
  code <<-EOC
    set -x
    s3_file="#{get_last_release}
    
    buckets=( rightscale_rightlink_dev )
    locations=( #{rightlink_file} )
    
    for bucket in ${buckets[@]}
    do
      for location in ${locations[@]}
      do
        code=$(curl -o #{node[:rightimage][:mount_dir]}/root/.rightscale/#{rightlink_file} --connect-timeout 10 --fail --silent --write-out %{http_code} http://s3.amazonaws.com/$bucket/$s3_file)
        return=$?
        echo "BUCKET: $bucket LOCATION: $s3_file RETURN: $return CODE: $code"
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

remote_file "/tmp/rightimage" do
  source "rightimage"
end

bash "install_rightlink" do 
  code <<-EOC
    set -ex
    rm -rf #{node[:rightimage][:mount_dir]}/opt/rightscale/
    install /tmp/rightimage  #{node[:rightimage][:mount_dir]}/etc/init.d/rightimage --mode=0755

    mkdir -p #{node[:rightimage][:mount_dir]}/root/.rightscale
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
