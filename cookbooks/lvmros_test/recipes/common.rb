include_recipe "bd_lvmros::install"

LVM_RESOURCE_NAME = "default" # currently hard coded
LVM_TEST_MOUNT_POINT = "/mnt"
LVM_TEST_RESTORE_DIR = "/tmp/restore_test"

node[:remote_storage][:default][:account][:id] = node[:test][:username]
node[:remote_storage][:default][:account][:credentials] = node[:test][:password]
node[:remote_storage][:default][:provider] = node[:test][:provider]
node[:remote_storage][:default][:container] = node[:test][:container]

include_recipe "bd_lvmros::setup_remote_storage"
include_recipe "bd_lvmros::setup_lvm"

# Remove any restore directory from previous runs.
directory LVM_TEST_RESTORE_DIR do
  action :delete
  recursive true
end

# Populate with some files
directory "/mnt/backup_test" 
file "/mnt/backup_test/a.txt"
file "/mnt/backup_test/b.txt"
directory "/mnt/backup_test/c" 
file "/mnt/backup_test/c/c.txt"

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
  lineage node[:rightscale][:instance_uuid]
  action :backup 
end

# Create a palce to put our restore
directory LVM_TEST_RESTORE_DIR do
  action :create
end

# Do the restore.
block_device LVM_RESOURCE_NAME do
  restore_root LVM_TEST_RESTORE_DIR
  action :restore 
end

# Compare directories.
# Raise an exception if they are different.
ruby "test for identical dirs" do
  code <<-EOH
    `diff -r "#{LVM_TEST_MOUNT_POINT}" "#{LVM_TEST_RESTORE_DIR}"`
    raise "ERROR: directories do not match!!" if $? != 0
  EOH
end

# Remove LVM
block_device LVM_RESOURCE_NAME do
  action :remove 
end