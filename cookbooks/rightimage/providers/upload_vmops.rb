class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

action :upload do
  r = gem_package "nokogiri" do
    gem_binary "/opt/rightscale/sandbox/bin/gem"
    version "1.4.3.1"
    action :nothing
  end
  r.run_action(:install)
  Gem.clear_paths
  
  ruby_block "trigger download to test cloud" do
    block do
      require "rubygems"
      require "uri"
      require "nokogiri"
      
      # The public API URL allows access for developers and users to manage their 
      # virtual machines or to create their own user interfaces.  Accesses to this URL must be secured.
      # http://173.227.0.170:8080/client/api
      # The private API URL allows full, unsecured access to the entire API.  This URL is intended to be 
      # secured behind a firewall.
      # http://173.227.0.170:8096/
      api_url = new_resource.api_url
      
      #image_name = "RightImage_CentOS_5.4_x64_v5.6.11_Dev1"
      #local_ip = "50.18.23.10"
      filename = "#{image_name}.#{new_resource.file_ext}"
      local_file = "#{target_raw_root}/#{filename}"
      md5sum = Digest::MD5.hexdigest(::File.read(local_file))
 
      local_ip = node[:cloud][:public_ips][0]
      image_url = "http://#{local_ip}/#{filename}"
      encoded_image_url = URI.escape(image_url, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))  
     
      name = image_name.gsub(/RightImage/,"RI")
      # remove random passwd from name
      if name =~ /Dev/i
        n = name.split("_")
        n.pop
        name = n.join("_")
      end
   
      cmd = "/?command=registerTemplate"
      cmd << "&name=#{name}&displayText=#{image_name}_#{node[:rightimage][:virtual_environment].upcase}"
      cmd << "&url=#{encoded_image_url}"

      case new_resource.file_ext
      when "vmdk"
        format = "OVA"
      when "qcow2.bz2"
        format = "QCOW"
      when "vhd"
        format = "VHD"
      end

      cmd << "&format=#{format}"
  
  #    case node[:rightimage][:platform]
  #    when "centos"
  #      case node[:rightimage][:release]
  #      when "5.4"
          cmd << "&osTypeId=14" # CentOS 5.4 x86
  #      else
  #        cmd << "&osTypeId=76"
  #      end
  #    end
  
      cmd << "&zoneId=1"
      cmd << "&isPublic=true"
      cmd << "&isFeatured=true"
      cmd << "&checksum=#{md5sum}" 

      Chef::Log.info("============")
      Chef::Log.info("#{api_url}#{cmd}")
      Chef::Log.info("============")
      result = `curl -S -s -o - -f '#{api_url}#{cmd}'`
  
      if result =~ /created/ 
        Chef::Log.info("Successfully started download of image to test cloud.")
        
        # Parse out image id from the registration call
        doc = Nokogiri::XML(result)
        image_id = doc.xpath('//template/id').first.text
        
        # add to global id store for use by other recipes
        id_list = RightImage::IdList.new(Chef::Log)
        id_list.add(image_id)
      else
        raise "ERROR: could not upload image to cloud at #{api_url} due to #{result.inspect}"
      end
    end
  end
end
