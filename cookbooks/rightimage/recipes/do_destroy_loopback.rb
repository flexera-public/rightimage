rs_utils_marker :begin
rightimage "" do
  not_if { node[:rightimage][:platform] == 'rhel' }
  action :destroy_loopback
end
rs_utils_marker :end
