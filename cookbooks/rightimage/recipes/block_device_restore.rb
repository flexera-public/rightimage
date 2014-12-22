rightscale_marker :begin
class Chef::Recipe
  include RightScale::RightImage::Helper
end
class Chef::Resource
  include RightScale::RightImage::Helper
end


def ebs_snapshot_exists?
  begin
    @api = RightScale::Tools::API.factory('1.0', {:cloud=>'ec2',:hypervisor=>'xen'})
    Chef::Log::info("Attempting to restore from EBS snapshot lineage #{ri_lineage}")
    snaps = @api.find_latest_ebs_backup(ri_lineage, false)
    # If we can't find a snapshot, an exception will be raised and we'll continue in
    # in the rescue block below
    Chef::Log::info("Found EBS snapshot for #{ri_lineage} #{snaps.inspect}")
    return true
  rescue Exception => e
    if e.message =~ /execution expired/
      return false
    else
      # Exception other than "Execution expired", reraise
      raise e
    end
  end
end

# Unzips file downloaded by "download_image_from_s3".  This schedules an
# execute during the converge phase, so it happens inbetween the block_device
# recipe calls
def unzip_image
  ruby_block "Unzip compressed image #{loopback_file_gz}" do
    require 'zlib'
    block do
      fin = Zlib::GzipReader.new(::File.open(loopback_file_gz))
      ::File.open(loopback_file,"w") do |fout|
        until fin.eof?
          fout.write(fin.read(1024*1024))
        end
      end
    end
  end
end

# This function will pull down a "base image" from a standard rightscale bucket
# location. A base image is a standard centos or ubuntu image with most righscale
# specific software customizations but without any cloud specific customizations
# This has to happen during the "compile" phase or else its hard to schedule 
# the order in which blocks execute correctly
def download_image_from_s3
  Chef::Log::info("Attempting to restore from S3 lineage #{ri_lineage}")
  platform = node[:rightimage][:platform]
  platform_version = node[:rightimage][:platform_version]
  arch = node[:rightimage][:arch]
  year = mirror_freeze_date[0..3]
  image_upload_bucket = node[:rightimage][:base_image_bucket]
  base_image_endpoint = "https://#{image_upload_bucket}.s3.amazonaws.com"
  image_s3_path = platform+"/"+platform_version+"/"+arch+"/"+year+"/"

  FileUtils.mkdir_p(target_raw_root)
  FileUtils.mkdir_p(temp_root)
  url = "#{base_image_endpoint}/#{image_s3_path}#{loopback_filename}.gz"
  Chef::Log.info("Restoring from URL: #{url}")
  res = `curl -o #{loopback_file_gz} --retry 7 --connect-timeout 10 --fail --silent --write-out %{http_code} #{url}`
  return !!(res =~ /^2../)
end

def restore_ebs_snapshot
  # Times 2.3 since we need to store 2 raw loopback files, and need a 
  # little extra space to gzip them, take snapshots, etc
  new_volume_size = (node[:rightimage][:root_size_gb].to_f*2.3).ceil
  # This is a hack since our base snapshot size is 12, if we specify less
  # than that it'll error out with an exception.
  new_volume_size = 12 if new_volume_size < 12
  block_device ri_lineage do
    primary_cloud "ec2"
    hypervisor "xen"
    lineage ri_lineage
    mount_point target_raw_root
    vg_data_percentage "95"
    volume_size new_volume_size.to_s
    stripe_count "1"
    persist true
    action :primary_restore
  end
end

# Begin main execution block

# Our preferred way to restore base snapshots is from an EBS snapshot, however when
# one isn't available (i.e. running cookbook from an alternate RightScale account)
# we'll try to restore one of the standard RightScale base images
#
if mounted?
  # the mounted? check can't be in a not_if, it errors out Marshal.dump->node 
  # when the persist flag is set because its can't serialize the Proc
  Chef::Log::info("Block device already mounted")
elsif ::File.exists?(loopback_file)
  Chef::Log::info("Already restored raw image from S3")
else
  if ebs_snapshot_exists?
    restore_ebs_snapshot
  else
    if download_image_from_s3
      include_recipe "rightimage::block_device_create"
      unzip_image
      include_recipe "rightimage::block_device_backup"
    else
      Chef::Log.error("Could not restore lineage #{ri_lineage} from either EBS or S3, image snapshot not found")
      raise "Base image snapshot for #{ri_lineage} not found"
    end
  end
end

rightscale_marker :end
