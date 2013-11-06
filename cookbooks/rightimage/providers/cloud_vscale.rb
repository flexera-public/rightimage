class Chef::Resource
  include RightScale::RightImage::Helper
end



action :configure do
  rightimage_cloud "cloudstack" do
    image_name  helper_image_name
  
    hypervisor        node[:rightimage][:hypervisor]
    arch              node[:rightimage][:arch]
    platform          node[:rightimage][:platform]
    platform_version  node[:rightimage][:platform_version].to_f
  
    action :configure
  end

  # Create metadata mount directory. 
  directory "#{guest_root}/mnt/metadata" do
    owner "root"
    group "root"
    mode "0750"
    action :create
    recursive true
  end 

  # Patch for RightLink support on VScale.
  cookbook_file "#{guest_root}/root/.rightscale/vscale.patch" do
    source "vscale.patch"
    backup false
  end

  # Patch for retreiving SSH keys from metadata.
  cookbook_file "#{guest_root}/root/.rightscale/vscale-ssh.patch" do
    source "vscale-ssh.patch"
    backup false
  end

  # HACK: Preinstall RightLink so we can apply a patch to add support.
  # Remove when proper RightLink support is added in to the package.
  bash "install rightlink for vscale" do
    cwd "#{guest_root}/root/.rightscale"
    flags "-ex"
    code <<-EOH
      guest_root="#{guest_root}"

      # No need for seed script since the package is being preinstalled.
      rm -f $guest_root/etc/init.d/rightimage

      case "#{new_resource.platform}" in
      "ubuntu")
        dpkg --root $guest_root -i $guest_root/root/.rightscale/rightscale*.deb
        chroot $guest_root update-rc.d rightimage remove
        ;;
      "centos"|"rhel")
        rpm --root $guest_root -Uvh $guest_root/root/.rightscale/rightscale*.rpm
        chroot $guest_root chkconfig --del rightimage
        ;;
      esac

      chroot $guest_root patch --directory=/opt/rightscale/right_link --forward -p1 --input=/root/.rightscale/vscale.patch
      chroot $guest_root patch --directory=/opt/rightscale/right_link --forward -p1 --input=/root/.rightscale/vscale-ssh.patch
    EOH
  end

end

action :package do
  rightimage_image node[:rightimage][:image_type] do
    action :package
  end
end

action :upload do

  raise "Upload not yet implemented."

  # add to global id store for use by other recipes
  ruby_block "store id" do
    block do
    
      id_list = RightImage::IdList.new(Chef::Log)
      id_list.add(image_id)
    end
  end
end
