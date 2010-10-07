
kiwi_dir = "/mnt/kiwi" 

node.right_image_creator.host_packages.each { |p| package p }
   
directory kiwi_dir  do
  recursive true
  action :delete
end

directory "#{kiwi_dir}/root" do 
  recursive true
  action :create
end

%w{root/include root/linuxrc root/preinit config.sh config.xml images.sh}.each do |t| 
  template "#{kiwi_dir}/#{t}" do 
    source "sles/#{t}.erb"
  end
end

bash "config md5s and run" do 
  cwd kiwi_dir
  code <<-EOS
set -e

cat << EOF > .checksum.md5
\`md5sum #{kiwi_dir}/root/linuxrc | awk '{print \$1}'\`  ./root/linuxrc
\`md5sum #{kiwi_dir}/root/preinit | awk '{print \$1}'\`  ./root/preinit
\`md5sum #{kiwi_dir}/config.sh | awk '{print \$1}'\`  ./config.sh
\`md5sum #{kiwi_dir}/config.xml | awk '{print \$1}'\`  ./config.xml
\`md5sum #{kiwi_dir}/images.sh | awk '{print \$1}'\`  ./images.sh
EOF

## make sure that proc is not mounted
umount -lf #{node.right_image_creator.mount_dir}/proc || true 

set -x
kiwi --force-new-root  --prepare #{kiwi_dir} --root #{node.right_image_creator.mount_dir} --logfile terminal

EOS
end
