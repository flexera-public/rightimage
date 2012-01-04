rs_utils_marker :begin




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


## download the suse dev rpm's
rpm_dir = "/root/sles_rpms"
rpm_handle = 'http://devs-us-west.s3.amazonaws.com/martin/sles_rpms.tgz'
rpm_package = 'sles_rpms.tgz'

remote_file "/root/#{rpm_package}"  do
  source rom_handle
  mode "0644"
  checksum "abfd99cb841553b7b40f7b70f69fc6f57cca2797" # A SHA256 (or portion thereof) of the file.
end

bash 'setup_rpm_dir' do 
  code <<-EOS
set -ex
rm -rf #{rpm_dir}
mkdir -p #{rpm_dir}
tar -xzf /root/#{rpm_package} -C #{rpm_dir}

EOS
end


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
rs_utils_marker :end
