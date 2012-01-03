module RightScale
  module RightImage
    module Helper
  
      # NOTE: this code is basically duplicated code with the right_image_builder project
      # albeit out of date duplicated code.  We should share code someday!
      def image_name
      	raise "ERROR: you must specify an image_name!" unless node[:rightimage][:image_name]
      	name = node[:rightimage][:image_name].dup
      	name << "_#{generate_persisted_passwd}" if node[:rightimage][:debug] == "true"
      	name
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
        [platform,release_number,arch,timestamp,build_number].join("_")

      end

      def platform
        node[:rightimage][:platform]
      end

      def release_number
        if platform == "ubuntu"
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
        platform + "_" + release_number + "_" + arch + "_" + timestamp + "_" + build_number
      end

      def source_image
        node[:rightimage][:mount_dir]
      end

      def build_root
        "/mnt"
      end

      def partitioned?
        case node[:rightimage][:cloud]
        when "ec2", "euca"
          return FALSE
        when "vmops"
          case node[:rightimage][:virtual_environment]
          when "xen"
            return FALSE
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

      def s3_path_base
        platform + "/" + release_number + "/" + arch + "/" + timestamp[0..3]
      end

      def base_image_upload_bucket
        "rightscale-rightimage-base-dev"
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
    end
  end
end
