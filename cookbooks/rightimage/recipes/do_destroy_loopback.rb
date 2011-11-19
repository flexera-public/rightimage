class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

bash "unmount loopback fs" do 
  flags "-ex"
  code <<-EOH
    loop_dev="#{loop_dev}"
    loop_map="#{loop_map}"
    source_image="#{source_image}" 

    umount -lf $source_image/dev || true
    umount -lf $source_image/proc || true
    umount -lf $source_image/sys || true
    umount -lf $source_image || true

    set +e
    [ -e "$loop_map" ] && kpartx -d $loop_dev
    losetup -a | grep $loop_dev
    [ "$?" == "0" ] && losetup -d $loop_dev
    set -e
  EOH
end
