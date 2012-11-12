module RightScale
  module RightImage
    module Helper
      def image_name
        raise "ERROR: you must specify an image_name!" unless node[:rightimage][:image_name] =~ /./
        name = node[:rightimage][:image_name].dup
        name << "_#{generate_persisted_passwd}" if node[:rightimage][:debug] == "true" && node[:rightimage][:build_mode] != "migrate" && node[:rightimage][:cloud] != "rackspace"
        name.gsub!("_","-") if node[:rightimage][:cloud] == "rackspace"
        name
      end

      def mci_base_name
        if node[:rightimage][:mci_name] =~ /./
          return node[:rightimage][:mci_name]
        else
          raise "ERROR: you must specify a mci_name or an image_name!" unless node[:rightimage][:image_name] =~ /./
          return node[:rightimage][:image_name]
        end
      end

      def generate_persisted_passwd
        length = 14
        pw = nil
        filename = "/tmp/random_passwd"
        if ::File.exists?(filename)
          pw = File.open(filename, 'rb') { |f| f.read }
        else
          pw = Array.new(length/2) { rand(256) }.pack('C*').unpack('H*').first
          File.open(filename, 'w') {|f| f.write(pw) }
        end
        pw
      end

      def image_file_ext
        case node[:rightimage][:virtual_environment]
        when "xen"
          (node[:rightimage][:cloud] == "euca" ? "tar.gz":"vhd.bz2")
        when "kvm"
          "qcow2.bz2"
        when "esxi"
          "vmdk.ova"
        end
      end

      def cloud_id
        cloud_names = { 
          "us-east" => "1", 
          "eu-west" => "2", 
          "us-west" => "3",
          "ap-southeast" => "4",
          "ap-northeast" => "5", 
          "us-west-2" => "6",
          "sa-east" => "7",
          "cloudstack-xen" => "850"
        }
        id = nil
        cloud_names.each do |cloud_name, cloud_id|
          id = cloud_id if node[:rightimage][:region] == (cloud_name)
        end
        id
      end
      
      def config_rest_connection
        restcondir = ::File.join(::File.expand_path("~"), ".rest_connection")
        require 'fileutils'

restcon_config =<<EOF
---
:pass: #{node[:rest_connection][:pass]}
:user: #{node[:rest_connection][:user]}
:api_url: #{node[:rest_connection][:api_url]}
:common_headers: 
  X_API_VERSION: "1.0"
EOF
        ENV['REST_CONNECTION_LOG'] = "/tmp/rest_connection.log"
        FileUtils.mkdir_p(restcondir)
        ::File.open(File.join(restcondir, "rest_api_config.yaml"),"w") {|f| f.write(restcon_config)}
        require 'rubygems'
        require 'rest_connection'
      end

      def ri_lineage
        [guest_platform,release_number,arch,timestamp,build_number].join("_")
      end

      # call this guest_platform, not platform, otherwise can introduce a 
      # weird bug where platform func can overwrite chef default platform func
      def guest_platform
        node[:rightimage][:platform]
      end

      def release_number
        if guest_platform == "ubuntu"
          case release
          when "hardy" 
            "8.04"
          when "intrepid" 
            "8.10"
          when "jaunty" 
            "9.04"
          when "karmic" 
            "9.10"
          when "lucid" 
            "10.04"
          when "maverick" 
            "10.10" 
          else 
            raise "Unknown release"
          end
        else 
          release
        end
      end

      def release
        node[:rightimage][:release]
      end

      def arch
        if node[:rightimage][:arch] == "x64"
          "x86_64"
        else
          node[:rightimage][:arch]
        end
      end

      def timestamp
        node[:rightimage][:timestamp]
      end

      def install_mirror_date
        timestamp[0..7]
      end

      def build_number
        if node[:rightimage][:build_number] =~ /./
          node[:rightimage][:build_number]
        else
          "0"
        end
      end

      def os_string
        guest_platform + "_" + release_number + "_" + arch + "_" + timestamp + "_" + build_number
      end

      def source_image
        node[:rightimage][:mount_dir]
      end

      def build_root
        if node[:rightimage][:cloud] == "raw"
          node[:rightimage][:ebs_mount_dir]
        else
          "/mnt"
        end
      end
      
      def partition_number
        number = 0
        number = 1 if partitioned? && is_ubuntu? && node[:rightimage][:virtual_environment] == "xen"
        number
      end
      
      def is_ubuntu?
        node[:rightimage][:platform] == "ubuntu"
      end

      def partitioned?
        case node[:rightimage][:cloud]
        when "ec2", "euca"
          return FALSE
        when "vmops"
          case node[:rightimage][:virtual_environment]
          when "xen"
            if is_ubuntu?
              return TRUE
            else
              return FALSE
            end
          else
            return TRUE
          end
        else
          return TRUE
        end
      end

      def target_type
        ret = "#{os_string}_hd0"
        ret << "0" if node[:rightimage][:build_mode] == "full" && partitioned?

        ret
      end

      def base_root
        "#{build_root}/#{target_type}"
      end

      def guest_root
        source_image
      end

      def target_raw_root
        "/mnt/storage"
      end

      def target_raw_file
       "#{target_type}.raw"
      end

      def target_raw_path
        "#{target_raw_root}/#{target_raw_file}" 
      end

      def target_raw_zip
        "#{target_type}.gz"
      end

      def target_raw_zip_path
        "#{build_root}/#{target_raw_zip}"
      end

      def target_temp_root
        "#{build_root}/rightimage-temp"
      end

      def target_temp_path
        "#{target_temp_root}/#{target_raw_file}"
      end

      def full_image_path
        target_temp_root+"/"+image_name+"."+image_file_ext
      end

      def s3_path_base
        [guest_platform,release_number,arch,timestamp[0..3]].join("/")
      end

      def s3_path_full
        hypervisor = node[:rightimage][:virtual_environment]
        [hypervisor,guest_platform,release_number].join("/")
      end

      def base_image_upload_bucket
        "rightscale-rightimage-base-dev"
      end

      def full_image_upload_bucket
        case node[:rightimage][:cloud]
        when "vmops"
          "rightscale-cloudstack-dev"
        when "euca"
          "rightscale-eucalyptus-dev"
        when "openstack"
          "rightscale-openstack-dev"
        when "rackspace"
          "rightscale-rackspace-dev"
        when "ec2"
          "rightscale-"+node[:rightimage][:region]
        end
      end

      def image_source_bucket
        bucket = "rightscale-#{image_source_cloud}"
        bucket << "-dev" if node[:rightimage][:debug] == "true"
        bucket
       end

      def image_source_cloud
        "us-west-2"
      end

      def migrate_temp_bundled
        "#{target_temp_root}/bundled"
      end

      def migrate_temp_unbundled
        "#{target_temp_root}/unbundled"
      end

      def loop_name
        "loop0"
      end

      def loop_dev
        "/dev/#{loop_name}"
      end 

      def loop_map
        "/dev/mapper/#{loop_name}p1"
      end

      def calc_mb
        node[:rightimage][:root_size_gb].to_i * 1024 
      end

      def mounted?
        `mount`.grep(/#{target_raw_root}/).any?
      end

      def setup_ec2_tools_env
        bash_snippet = <<-EOF
          . /etc/profile
          export PATH=$PATH:/usr/local/bin:/home/ec2/bin
          export EC2_HOME=/home/ec2
        EOF
        return bash_snippet
      end

      def cloud_credentials(cloud_type = node[:rightimage][:cloud])
        case cloud_type
        when "ec2"
          return {'AWS_CALLING_FORMAT' => 'SUBDOMAIN',
                  'AWS_ACCESS_KEY_ID'  => node[:rightimage][:aws_access_key_id],
                  'AWS_SECRET_ACCESS_KEY'=> node[:rightimage][:aws_secret_access_key]}
        when "rackspace" 
          return {'RACKSPACE_ACCOUNT' => node[:rightimage][:rackspace][:account],
                  'RACKSPACE_API_TOKEN' => node[:rightimage][:rackspace][:api_token]}
        else
          raise "Cloud #{cloud_type} passed to cloud_credentials, which it doesn't know how to handle"
        end
      end

      def calc_md5sum(file)
        require "digest/md5"
        # read incrementally, files are large can cause out of memory exceptions
        md5 = ::File.open(file, 'rb') do |io|
          dig = ::Digest::MD5.new
          buf = ""
          dig.update(buf) while io.read(4096, buf)
          dig
        end
        return md5
      end

      def rebundle?
        if node[:rightimage][:cloud] == "ec2" and node[:rightimage][:platform] == "rhel"
          return true
        elsif node[:rightimage][:cloud] == "rackspace"
          return true
        else
          return false
        end
      end

      def grub_initrd
        ::File.basename(Dir.glob("#{guest_root}/boot/initr*").sort_by { |f| File.mtime(f) }.last)
      end

      def grub_kernel
        ::File.basename(Dir.glob("#{guest_root}/boot/vmlinuz*").sort_by { |f| File.mtime(f) }.last)
      end

      def grub_root
        "(hd0" + (node[:rightimage][:cloud] == "ec2" ? "":",#{partition_number}") + ")"
      end
    end
  end
end
