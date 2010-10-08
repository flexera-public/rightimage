LVM_RESOURCE_NAME = "default" # currently hard coded

service "mysql" do
  action :stop
end

# Sync filesystem
block_device LVM_RESOURCE_NAME do
  action :sync_fs 
end

# Take snapshots
block_device LVM_RESOURCE_NAME do
  action :take_snapshot 
end

# Do the actual backup.
block_device LVM_RESOURCE_NAME do
  lineage "rollback"
  action :backup 
end

service "mysql" do
  action :start
end



