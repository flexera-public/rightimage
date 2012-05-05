rightscale_marker :begin

class Chef::Recipe
  include RightScale::RightImage::Helper
end

class Chef::Resource
  include RightScale::RightImage::Helper
end

rightlink_file="rightscale_#{node[:rightimage][:rightlink_version]}-#{node[:rightimage][:platform]}_#{node[:rightimage][:platform_version]}-" + ((node[:rightimage][:platform] == "ubuntu") && (node[:rightimage][:arch] == "x86_64") ? "amd64" : node[:rightimage][:arch]) + "." + (node[:rightimage][:platform] =~ /centos|rhel/ ? "rpm" : "deb")

bash "download_rightlink" do
  flags "-x"
  location1 ="#{node[:rightimage][:rightlink_version]}/#{rightlink_file}"
  location2 ="#{node[:rightimage][:rightlink_version]}/#{node[:rightimage][:platform]}/#{rightlink_file}"
  code <<-EOC
    mkdir -p #{guest_root}/root/.rightscale
    
    buckets=( rightscale_rightlink rightscale_rightlink_dev )
    locations=( #{location1} #{location2})
    
    for bucket in ${buckets[@]}
    do
      for location in ${locations[@]}
      do
        code=$(curl -o #{guest_root}/root/.rightscale/#{rightlink_file} --connect-timeout 10 --fail --silent --write-out %{http_code} http://s3.amazonaws.com/$bucket/$location)
        return=$?
        echo "BUCKET: $bucket LOCATION: $location RETURN: $return CODE: $code"
        [[ "$return" -eq "0" && "$code" -eq "200" ]] && break 2
      done
    done

    if test -f #{guest_root}/root/.rightscale/#{rightlink_file}; then
      exit 0
    else
      echo "Failed to download RightLink.  Place the #{rightlink_file} in the S3 bucket and re-run"
      exit 1
    fi
  EOC
end

execute "insert_rightlink_version" do 
  command  "echo -n " + node[:rightimage][:rightlink_version] + " > " + guest_root + "/etc/rightscale.d/rightscale-release"
end

cookbook_file "#{guest_root}/etc/init.d/rightimage" do
  source "rightimage"
  mode "0755"
end

bash "install_rightlink" do 
  flags "-ex"
  code <<-EOC
    rm -rf #{guest_root}/opt/rightscale/

    chmod 0770 #{guest_root}/root/.rightscale
    chmod 0440 #{guest_root}/root/.rightscale/*

    case "#{node[:rightimage][:platform]}" in 
      "ubuntu" )
        chroot #{guest_root} update-rc.d rightimage start 96 2 3 4 5 . stop 1 0 1 6 .
        ;; 
      * )
        chroot #{guest_root} chkconfig --add rightimage
        ;;
    esac
  EOC
end
rightscale_marker :end
