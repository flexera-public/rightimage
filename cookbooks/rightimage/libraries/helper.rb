module RightScale
  module RightImage
    module Helper
  
      # NOTE: this code is basically duplicated code with the right_image_builder project
      # albeit out of date duplicated code.  We should share code someday!
      
      # Construct image name.
      def image_name
        
        override_name = node.rightimage.image_name_override
        return override_name.dup if override_name && override_name != ""
        
        release = node[:rightimage][:rightlink_version]
        suffix = node[:rightimage][:image_postfix]

        image_name = ""
        image_name << node[:rightimage][:image_prefix] + '_' if node[:rightimage][:image_prefix]
        image_name << node[:rightimage][:platform].capitalize + '_'
        image_name << node[:rightimage][:release_number] + '_'
        if node[:rightimage][:arch] == "x86_64"
          image_name << "x64" + '_'
        else
          image_name << node[:rightimage][:arch] + '_'
        end
        image_name << 'v' + release 
        image_name << '_' + suffix if suffix
        image_name
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
      
    end
  end
end

