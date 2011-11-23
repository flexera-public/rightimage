 class Chef::Provider
   include RightScale::RightImage::Helper
 end

action :destroy_loopback do

  bash "destroy_loopback" do
    flags "-ex"
    code <<-EOH
      loop_dev="#{loop_dev}"
      loop_map="#{loop_map}"
      source_image="#{source_image}"

      umount -lf $source_image/dev || true
      umount -lf $source_image/proc || true
      umount -lf $source_image/sys || true
      umount -lf $source_image || true      

      [ -e "$loop_map" ] && kpartx -d $loop_dev
      set +e
      losetup -a | grep $loop_dev
      if [ "$?" == "0" ]; then
        set -e
        losetup -d $loop_dev
      fi
      set -e
    EOH
  end

end
 
action :sanitize do
 
  ruby_block "sanitize" do
    block do
      util = RightImage::Util.new(new_resource.name, Chef::Log)
      util.sanitize()
    end
  end
  
end
