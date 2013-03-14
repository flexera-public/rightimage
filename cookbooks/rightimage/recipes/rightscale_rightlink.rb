rightscale_marker :begin

class Chef::Recipe
  include RightScale::RightImage::Helper
end

class Chef::Resource
  include RightScale::RightImage::Helper
end

def install_seed_script(legacy = false)
  if legacy
    seed_script = "rightimage"
  else
    seed_script = "rightimage_repo"
  end

  log "Place rightlink seed script into image"
  cookbook_file "#{guest_root}/etc/init.d/rightimage" do
    source seed_script
    backup false
    mode "0755"
  end

  if legacy
    log "Clean old install"
    execute "rm -rf #{guest_root}/opt/rightscale/"
    execute "chmod 0440 #{guest_root}/root/.rightscale/*"
  end

  log "Setup seed script to run on boot"
  bash "install_rightlink" do 
    flags "-ex"
    code <<-EOC
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
end

def install_rightlink_legacy
  rightlink_file="rightscale_#{node[:rightimage][:rightlink_version]}-#{node[:rightimage][:platform]}_#{node[:rightimage][:platform_version]}-" + ((node[:rightimage][:platform] == "ubuntu") && (node[:rightimage][:arch] == "x86_64") ? "amd64" : node[:rightimage][:arch]) + "." + (node[:rightimage][:platform] =~ /centos|rhel/ ? "rpm" : "deb")

  directory "#{guest_root}/etc/rightscale.d" do
    action :create
    recursive true
  end

  execute "echo -n #{node[:rightimage][:cloud]} > #{guest_root}/etc/rightscale.d/cloud" do 
    creates "#{guest_root}/etc/rightscale.d/cloud"
  end

  directory "#{guest_root}/var/spool/cloud" do
    action :create
    recursive true
  end

  log "Add RightLink 5.6 backwards compatibility symlink"
  execute "chroot #{guest_root} ln -s /var/spool/cloud /var/spool/#{node[:rightimage][:cloud]}" do
    creates "#{guest_root}/var/spool/#{node[:rightimage][:cloud]}"
  end

  directory "#{guest_root}/root/.rightscale/" do
    owner "root"
    group "root"
    mode "0770"
    recursive true
  end

  bash "download_rightlink" do
    flags "-x"
    location1 ="#{node[:rightimage][:rightlink_version]}/#{rightlink_file}"
    location2 ="#{node[:rightimage][:rightlink_version]}/#{node[:rightimage][:platform]}/#{rightlink_file}"
    code <<-EOC
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

  install_seed_script(true) 
end

def install_rightlink
  # Setup repos
  if node[:rightimage][:platform] == "centos"
    node[:rightimage][:rightlink_repo_url] = "http://s3.amazonaws.com/rightscale_rightlink_dev/rpm_repo_test"
    node[:rightimage][:rightlink_repo_url] = "http://s3.amazonaws.com/rightscale_rightlink_dev/deb_test_repo_pete"
    template "#{guest_root}/etc/yum.repos.d/rightlink.repo" do
      source "rightlink.repo.erb"
      variables({:enabled => true, :repo_url => node[:rightimage][:rightlink_repo_url]})
      backup false
    end
    execute "chroot #{guest_root} yum -y install rightlink-cloud-#{node[:rightimage][:cloud]}"
    execute "chroot #{guest_root} yum -y install rightlink-#{node[:rightimage][:rightlink_version]}"
    template "#{guest_root}/etc/yum.repos.d/rightlink.repo" do
      source "rightlink.repo.erb"
      variables({:enabled => false, :repo_url => node[:rightimage][:rightlink_repo_url]})
      backup false
    end
  else
    platform_codename = platform_codename(node[:rightimage][:platform_version])
    template "#{guest_root}/etc/apt/sources.list.d/rightlink.list" do
      source "rightlink.list.erb"
      variables({
        :enabled => true,
        :platform_codename => platform_codename,
        :repo_url => node[:rightimage][:rightlink_repo_url]
      })
      backup false
    end
    execute "chroot #{guest_root} apt-get -y update"
    # Force yes forces the package to be installed even if its unsigned. Needed for dev packages. TBD 
    # figure out a better strategy for handling this case
    execute "chroot #{guest_root} apt-get -y --force-yes install rightlink-cloud-#{node[:rightimage][:cloud]}"
    execute "chroot #{guest_root} apt-get -y --force-yes install rightlink=#{node[:rightimage][:rightlink_version]}"
    template "#{guest_root}/etc/apt/sources.list.d/rightlink.list" do
      source "rightlink.list.erb"
      variables({
        :enabled => false,
        :platform_codename => platform_codename,
        :repo_url => node[:rightimage][:rightlink_repo_url]
      })
      backup false
    end
    execute "chroot #{guest_root} apt-get -y update"
  end

  execute "insert_rightlink_version" do 
    command  "echo -n " + node[:rightimage][:rightlink_version] + " > " + guest_root + "/etc/rightscale.d/rightscale-release"
  end

  install_seed_script(false)
end



log "Building image with RightLink package #{node[:rightimage][:rightlink_version]}"
if node[:rightimage][:rightlink_version].to_i < 5
  raise "rightlink versions < 5 not supported"
elsif version_compare(node[:rightimage][:rightlink_version],"5.9") < 0
  log "Using legacy (direct package install) RightLink installation method"
  install_rightlink_legacy
else
  log "Using repo based RightLink installation method"
  install_rightlink
end


rightscale_marker :end
