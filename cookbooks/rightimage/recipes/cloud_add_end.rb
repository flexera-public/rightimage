
bash "unmount proc & dev" do
  flags "-ex"
  code <<-EOH
    guest_root=#{guest_root}
    umount -lf $guest_root/proc || true
    umount -lf $guest_root/dev || true
    umount -lf $guest_root/sys || true
  EOH
end

# Clean up guest image
rightimage guest_root do
  action :sanitize
end

bash "sync fs" do
  flags "-ex"
  code "sync"
end

