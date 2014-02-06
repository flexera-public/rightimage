rightscale_marker :begin

class Chef::Recipe
  include RightScale::RightImage::Helper
end

class Chef::Resource
  include RightScale::RightImage::Helper
end


def repo_url_generator
  repo_url_base = node[:rightimage][:rightlink_repo]
  if repo_url_base =~ /^rightlink-(staging|production|nightly)$/
    repo_type = $1
    if repo_type == "nightly"
      url = "http://rightlink-integration.s3.amazonaws.com/nightly/"
    else
      url = "http://rightlink-#{repo_type}.s3.amazonaws.com/"
    end
  elsif repo_url_base =~ /^adhoc-(.+)$/
    repo_name = $1
    url = "http://rightlink-integration.s3.amazonaws.com/adhoc/#{repo_name}/"
  else 
    raise "Unknown rightlink_repo passed in (#{repo_url_base})."
  end
  if node[:rightimage][:platform] =~ /ubuntu/     
   url << "apt/"
  else
    platform = node[:rightimage][:platform_version].to_i
    arch = node[:rightimage][:arch]
    url << "yum/1/el/#{platform}/#{arch}/"
  end
  return url
end

def gpg_check_generator
  node[:rightimage][:rightlink_repo] =~ /staging|production/
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

  log "Place rightlink seed script into image"
  cookbook_file "#{guest_root}/etc/init.d/rightimage" do
    source "rightimage"
    backup false
    mode "0755"
  end

  log "Clean old install"
  execute "rm -rf #{guest_root}/opt/rightscale/"
  execute "chmod 0440 #{guest_root}/root/.rightscale/*"

  log "Setup seed script to run on boot"
  bash "install seed script" do 
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

def install_rightlink()
  # Setup repos
  repo_url = repo_url_generator
  gpg_check = gpg_check_generator
  rightlink_cloud = 
    case node[:rightimage][:cloud]
    when "google"
      "gce"
    when "vagrant"
      "none"
    else
      node[:rightimage][:cloud]
    end

  # Since dependencies can be installed from the repo, need to freeze them here.
  rightimage_os node[:rightimage][:platform] do
    action :repo_freeze
  end

  if node[:rightimage][:platform] == "centos"
    template "#{guest_root}/etc/yum.repos.d/rightlink.repo" do
      source "rightlink.repo.erb"
      variables({:enabled => true, :gpg_check => gpg_check, :repo_url => repo_url})
      backup false
    end
    execute "chroot #{guest_root} yum -y install rightlink-cloud-#{rightlink_cloud}"
    template "#{guest_root}/etc/yum.repos.d/rightlink.repo" do
      source "rightlink.repo.erb"
      variables({:enabled => false, :gpg_check => gpg_check, :repo_url => repo_url})
      backup false
    end
  else
    platform_codename = platform_codename(node[:rightimage][:platform_version])
    if node[:rightimage][:arch] =~ /x86_64/
      platform_arch = "amd64"
    else
      platform_arch = "i386"
    end
    template "#{guest_root}/etc/apt/sources.list.d/rightlink.list" do
      source "rightlink.list.erb"
      variables({
        :enabled => true,
        :arch => platform_arch, 
        :platform_codename => platform_codename,
        :repo_url => repo_url
      })
      backup false
    end
    # Selectively update the repo only, quicker
    update_repo_cmd = 'apt-get update -y' 
    update_repo_cmd << ' -o Dir::Etc::sourcelist="/etc/apt/sources.list.d/rightlink.list"'
    update_repo_cmd << ' -o Dir::Etc::sourceparts="-"'
    update_repo_cmd << ' -o APT::Get::List-Cleanup="0"'
       
    execute "chroot #{guest_root} #{update_repo_cmd}"

    # Force yes forces the package to be installed even if its unsigned.
    force_yes = gpg_check ? "" : "--force-yes"
    execute "chroot #{guest_root} apt-get -y #{force_yes} install rightlink-cloud-#{rightlink_cloud}"
    template "#{guest_root}/etc/apt/sources.list.d/rightlink.list" do
      source "rightlink.list.erb"
      variables({
        :enabled => false,
        :platform_codename => platform_codename,
        :repo_url => repo_url
      })
      backup false
    end
    execute "chroot #{guest_root} #{update_repo_cmd}"

    rightimage_os node[:rightimage][:platform] do
      action :repo_unfreeze
    end
  end

end



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
