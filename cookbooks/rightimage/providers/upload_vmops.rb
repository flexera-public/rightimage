class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

action :upload do
  CDC_GEM_VER = "0.0.0"
  CDC_GEM = ::File.join(::File.dirname(__FILE__), "..", "files", "default", "right_vmops-#{CDC_GEM_VER}.gem")
  SANDBOX_BIN = "/opt/rightscale/sandbox/bin/gem"

  r = gem_package "nokogiri" do
    gem_binary SANDBOX_BIN
    version "1.4.3.1"
    action :nothing
  end
  r.run_action(:install)

  r = gem_package CDC_GEM do
    gem_binary SANDBOX_BIN
    version CDC_GEM_VER
    action :nothing
  end
  r.run_action(:install)

  Gem.clear_paths

  ruby_block "trigger download to test cloud" do
    block do
      require "rubygems"
      require "right_vmops"
      require "uri"

      name = "#{image_name}_#{node[:rightimage][:virtual_environment].upcase}"
      zoneId = node[:rightimage][:datacenter]

      case node[:rightimage][:platform]
      when "centos"
        if node[:rightimage][:release] == "5.4"
          osTypeId = 14 # CentOS 5.4 (64-bit)
        else
          osTypeId = 112 # CentOS 5.5 (64-bit)
        end
      when "ubuntu"
        osTypeId = 126 # Ubuntu 10.04 (64-bit)
      end
      
      case node[:rightimage][:virtual_environment]
      when "esxi"
        format = "OVA"
        hypervisor = "VMware"
        file_ext = "vmdk.ova"
      when "kvm"
        format = "QCOW2"
        hypervisor = "KVM"
        file_ext = "qcow2.bz2"
      when "xen"
        format = "VHD"
        hypervisor = "XenServer"
        file_ext = "vhd.bz2"
      end

      filename = "#{image_name}.#{image_file_ext}"
      local_file = "#{target_temp_root}/#{filename}"
      md5sum = calc_md5sum(local_file)

      aws_url  = "rightscale-cloudstack-dev.s3.amazonaws.com"
      aws_path = s3_path_full
      image_url = "http://#{aws_url}/#{aws_path}/#{filename}"
      Chef::Log::info("Downloading from: #{image_url}...")
     
      Chef::Log.info("Registering image on cloud...")
      vmops = RightScale::VmopsFactory.right_vmops_class_for_version("2.2").new(node[:rightimage][:cloudstack][:cdc_api_key], node[:rightimage][:cloudstack][:cdc_secret_key], node[:rightimage][:cloudstack][:cdc_url])
      res = vmops.register_template(name, name, image_url, format, osTypeId, zoneId, hypervisor, md5sum, false, true)
      Chef::Log.info("Returned data: #{res.inspect}")

      image_id = res["registertemplateresponse"]["template"][0]["id"]

      $i=0
      $retries=60
      # Don't set less than 30 second polling period - It only updates every 30 seconds anyways.
      $wait=30

      until $i > $retries do
        info = vmops.list_templates(image_id,nil,"self")["listtemplatesresponse"]["template"][0]
        ready = info["isready"]
        status = info["status"]

        if ready == "true"
          Chef::Log.info("Image ready")
          break
        else
          $i += 1;
          if status =~ /expected/
            raise "Server returned error: #{status}"
          else
            Chef::Log.info("[#$i/#$retries] Image NOT ready! Status: #{status} Sleeping #$wait seconds...")
            sleep $wait unless $i > $retries
          end
        end
      end

      raise "Upload failed! Status: #{status}" unless ready == "true"

      # add to global id store for use by other recipes
      id_list = RightImage::IdList.new(Chef::Log)
      id_list.add(image_id)
    end
  end
end
