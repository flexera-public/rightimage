LVM_RESOURCE_NAME = "default" # currently hard coded
LVM_TEST_RESTORE_DIR = "/mnt"

service "mysql" do
  action :stop
end

# Remove any restore directory from previous runs.
directory LVM_TEST_RESTORE_DIR do
  action :delete
  recursive true
end

# Create a palce to put our restore
directory LVM_TEST_RESTORE_DIR do
  action :create
end

# Do the restore.
block_device LVM_RESOURCE_NAME do
  lineage "rollback"
  restore_root LVM_TEST_RESTORE_DIR
  action :restore 
end

service "mysql" do
  action :start
end