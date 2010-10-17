      
require 'popen4'
  


def vmbuilder_command( platform, release, architecture, directory, size, mirror)
  arch = ( architecture == 'x86_64' && 'amd64') || 'i386'

  vmbuilder_command = "sudo vmbuilder xen #{platform} "
  vmbuilder_command << " --arch #{arch} "
  vmbuilder_command << " --overwrite "
  vmbuilder_command << " --suite #{release} "
  vmbuilder_command << " --destdir=#{directory} "
  vmbuilder_command << " --rootsize=#{size} "
  vmbuilder_command << " --mirror=#{mirror} "

end

def debootstrap_command( release, architecture, directory, mirror)
  arch = ( architecture == 'x86_64' && 'amd64') || 'i386'

  debootstrap_command = "time sudo /usr/sbin/debootstrap "
  debootstrap_command << " --arch #{arch} "
  debootstrap_command << release + ' '
  debootstrap_command << directory + ' '
  debootstrap_command << mirror

end


action :create do

  install_command = debootstrap_command new_resource.release , new_resource.architecture , new_resource.directory, new_resource.mirror

  text =  <<-EOF
set -ex

    sudo umount -lf #{new_resource.directory} || true 
    sudo rm -rf #{new_resource.directory}
    sudo mkdir #{new_resource.directory}
    sudo  mount -t ramfs -o size=200m image-provider-fs #{new_resource.directory}

    #{install_command}

EOF
  STDERR.puts "script = #{text}"

          
  status = POpen4::popen4(text) do  |stdout, stderr, stdin, pid|

    stdout.each do |line|
      STDERR.puts line 
    end

  end
   
end
 
action :delete do
  execute "delete database" do
    only_if "mysql -e 'show databases;' | grep #{new_resource.name}"
    command "mysqladmin drop #{new_resource.name}"
  end
end
