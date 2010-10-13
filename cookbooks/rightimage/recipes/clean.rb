execute "umount -lf  #{node[:rightimage][:build_dir]}/proc || true"
execute "umount -lf  #{node[:rightimage][:mount_dir]}/proc || true"

directory node[:rightimage][:build_dir] do 
  action :delete
  recursive true
end


directory node[:rightimage][:mount_dir] do 
  action :delete
  recursive true
end
