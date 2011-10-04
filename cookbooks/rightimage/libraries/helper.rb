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

      def cloud_ids
        cloud_names = { 
          "us-east" => { "id" => "1", "amazon" => true }, 
          "eu-west" => { "id" => "2", "amazon" => true, "alias" => "eu" },
          "us-west" => { "id" => "3", "amazon" => true },
          "ap-southeast" => { "id" => "4", "amazon" => true },
          "ap-northeast" => { "id" => "5", "amazon" => true },
          "cloudstack-xen" => { "id" => "850" }
        }
        cloud_names
      end

      def cloud_ids_ec2
        if node[:rightimage][:region] == "all"
          ids = {}
          cloud_ids.each do |key, value|
            ids[key] = value["id"] if value["amazon"] == true
          end
          ids
        else
          cloud_id
        end
      end

      def cloud_ids_ec2_bash
        cloud_names = ""
        cloud_ids_ec2.each_key do | key |
          cloud_names << key + " "
        end
        cloud_names
      end

      def cloud_alias(cloud)
        if cloud_names[cloud].has_value("alias")
          cloud_names[cloud]["alias"]
        else
          cloud
        end
      end

      def cloud_id
        cloud_ids[node[:rightimage][:region]]["id"]
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

      def source_image
        node[:rightimage][:mount_dir]
      end

      def build_root
        "/mnt"
      end

      def target_type
        type = "#{node[:rightimage][:cloud]}_#{node[:rightimage][:virtual_environment]}"
        type << "_dev" if node[:rightimage][:debug] == "true"
        type
      end

      def base_root
        "#{build_root}/#{target_type}"
      end

      def guest_root
        "#{base_root}/build"
      end

      def target_raw_root
        "#{base_root}/image"
      end

      def target_raw_path
        "#{target_raw_root}/#{target_type}.raw" 
      end

      def image_upload_bucket
        region = node[:rightimage][:region]
        region = "eu" if region == "eu-west"

        # TODO: Rename input
        bucket = node[:rightimage][:image_upload_bucket] + "-#{region}"
        bucket << "-dev" if node[:rightimage][:debug]
      end 
    end
  end
end
