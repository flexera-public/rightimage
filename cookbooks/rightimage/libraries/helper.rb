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
          "cloudstack-xen" => "850"
        }
        id = nil
        cloud_names.each do |cloud_name, cloud_id|
          id = cloud_id if node[:rightimage][:region].include?(cloud_name)
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

      def lineage_name
        filename = "/tmp/rightimage_lineage"
        if ::File.exists?(filename)
          lineage = File.open(filename, 'rb') { |f| f.read }
        else
          time = Time.new
          lineage = "#{node[:rightimage][:platform]}_#{node[:rightimage][:release]}_#{time.strftime("%Y%m%d%H%M")}"
          File.open(filename, 'w') {|f| f.write(lineage) }
        end
        lineage
      end
    end
  end
end

