



kiwi_dir = "/mnt/kiwi" 

node.rightimage.host_packages.each { |p| package p }
   
directory kiwi_dir  do
  recursive true
  action :delete
end


directory "#{kiwi_dir}/root" do 
  recursive true
  action :create
end


directory "#{kiwi_dir}/root/etc/zypp/repos.d" do 
  recursive true
  action :create
end

directory "#{kiwi_dir}/root/etc/zypp/services.d" do 
  recursive true
  action :create
end



absolute_filename=`readlink -e $(readlink -f #{__FILE__})`

puts "absolute_filename = #{absolute_filename}"

cookbook_dir = File.dirname( File.dirname absolute_filename)

puts "cookbook_dir = #{cookbook_dir}"
rpm_dir = File.join( cookbook_dir, 'files', 'default', 'sles' )


%w{root/include root/linuxrc root/preinit config.sh config.xml images.sh root/etc/zypp/repos.d/susecloud:SLE11-SDK-SP1.repo root/etc/zypp/repos.d/susecloud:SLE11-SDK-SP1-Updates.repo root/etc/zypp/repos.d/susecloud:SLE11-WebYaST-SP1.repo root/etc/zypp/repos.d/susecloud:SLE11-WebYaST-SP1-Updates.repo root/etc/zypp/repos.d/susecloud:SLES11-Extras.repo root/etc/zypp/repos.d/susecloud:SLES11-SP1.repo root/etc/zypp/repos.d/susecloud:SLES11-SP1-Updates.repo root/etc/zypp/services.d/susecloud.repo root/etc/zypp/systemCheck root/etc/zypp/zypp.conf  root/etc/zypp/zypper.conf
}.each do |t| 
  template "#{kiwi_dir}/#{t}" do 
    source "sles/#{t}.erb"
    variables({
      :rpm_dir => rpm_dir
    })
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
umount -lf #{node.rightimage.mount_dir}/proc || true 

set -x
kiwi --force-new-root  --prepare #{kiwi_dir} --root #{node.rightimage.mount_dir} --logfile terminal

EOS
end
