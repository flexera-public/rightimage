rightscale_marker :begin
class Chef::Recipe
  include RightScale::RightImage::Helper
end
class Chef::Resource
  include RightScale::RightImage::Helper
end

def restore_snapshot_from_s3
  ruby_block "restore base image snapshot from s3" do
    lineage = ri_lineage
    platform = node[:rightimage][:platform]
    platform_version = node[:rightimage][:platform_version]
    arch = node[:rightimage][:arch]
    year = node[:rightimage][:timestamp][0..3]
    lineage = ri_lineage
    image_upload_bucket = node[:rightimage][:base_image_bucket]
    base_image_endpoint = "https://#{image_upload_bucket}.s3.amazonaws.com"
    partition_number = (partitioned?) ? "0" : ""

    image_s3_path = guest_platform+"/"+platform_version+"/"+arch+"/"+timestamp[0..3]+"/"
    block do 
      require 'zlib'
      FileUtils.mkdir_p(target_raw_root)
      FileUtils.mkdir_p(temp_root)
      url = "#{base_image_endpoint}/#{image_s3_path}#{loopback_filename(partitioned?)}.gz"
      Chef::Log.info("Restoring from URL: #{url}")
      raw_gz_file = "#{temp_root}/#{loopback_filename(partitioned?)}.gz"
      res = `curl -o #{raw_gz_file} --retry 7 --connect-timeout 10 --fail --silent --write-out %{http_code} #{url}`
      if res =~ /^2../
        Chef::Log.info("Downloaded file to #{raw_gz_file}, unzipping")
        fin = Zlib::GzipReader.new(::File.open(raw_gz_file))
        ::File.open("#{target_raw_root}/#{loopback_filename(partitioned?)}","w") do |fout|
          until fin.eof?
            fout.write(fin.read(1024*1024))
          end
        end
      else
        Chef::Log.error("Could not restore lineage #{ri_lineage} from either EBS or S3, snapshot not found")
        raise "Base image snapshot for #{ri_lineage} not found"
      end
      Chef::Log.info("got result #{res} from curl call")
    end
  end
end

# the mounted? check can't be in a not_if, it errors out Marshal.dump->node 
# when the persist flag is set because its can't serialize the Proc
if mounted? 
  Chef::Log::info("Block device already mounted")
elsif ::File.exists?(loopback_file(partitioned?))
  Chef::Log::info("Already restored raw image from S3")
else
  begin
    @api = RightScale::Tools::API.factory('1.0', {'cloud'=>'ec2'})
    Chef::Log::info("Attempting to restore from EBS snapshot lineage #{ri_lineage}")
    @api.find_latest_ebs_backup(ri_lineage,false,'')
    Chef::Log::info("Found EBS snapshot for #{ri_lineage}")

    block_device ri_lineage do
      cloud "ec2"
      lineage ri_lineage
      mount_point target_raw_root
      vg_data_percentage "95"
      volume_size "23"
      stripe_count "1"
      persist true

      action :primary_restore
    end
  rescue Exception => e
    if e.message =~ /execution expired/
      Chef::Log::info("Attempting to restore from S3 lineage #{ri_lineage}")
      restore_snapshot_from_s3
    else
      raise e
    end
  end
end


# Delete unneeded loopback file to save disk space.
file loopback_file(!partitioned?) do
  backup false
  action :delete
end

rightscale_marker :end
