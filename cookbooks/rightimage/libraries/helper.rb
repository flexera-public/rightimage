module RightScale
  module RightImage
    module Helper
      def image_name
        raise "ERROR: you must specify an image_name!" unless node[:rightimage][:image_name] =~ /./
        name = node[:rightimage][:image_name].dup
        name << "_#{generate_persisted_passwd}" if node[:rightimage][:debug] == "true" && node[:rightimage][:build_mode] != "migrate" && node[:rightimage][:cloud] !~ /rackspace/
        name << "_EBS" if node[:rightimage][:ec2][:image_type] =~ /ebs/i and name !~ /_EBS/
        name.gsub!("_","-") if node[:rightimage][:cloud] =~ /rackspace|google/
        name.gsub!(".","-") if node[:rightimage][:cloud] =~ /google/
        name.downcase! if node[:rightimage][:cloud] =~ /google/
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
        case node[:rightimage][:hypervisor]
        when "xen", "hyperv"
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

      def ri_lineage
        [guest_platform,platform_version,arch,timestamp,build_number].join("_")
      end

      # call this guest_platform, not platform, otherwise can introduce a 
      # weird bug where platform func can overwrite chef default platform func
      def guest_platform
        node[:rightimage][:platform]
      end

      def platform_codename(platform_version = node[:rightimage][:platform_version])
        case platform_version.to_f
        when 8.04  then "hardy"
        when 8.10  then "intrepid"
        when 9.04  then "jaunty"
        when 9.10  then "karmic"
        when 10.04 then "lucid"
        when 10.10 then "maverick"
        when 12.04 then "precise"
        else raise "Unknown Ubuntu version #{platform_version}"
        end
      end

      def platform_version
        node[:rightimage][:platform_version]
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

      def build_number
        if node[:rightimage][:build_number] =~ /./
          node[:rightimage][:build_number]
        else
          "0"
        end
      end

      def partition_number
        number = 0
        number = 1 if partitioned? && ubuntu? && node[:rightimage][:hypervisor] == "xen"
        number
      end

      def partitioned?
        case node[:rightimage][:cloud]
        when "ec2", "eucalyptus"
          return FALSE
        when "cloudstack"
          case node[:rightimage][:hypervisor]
          when "xen"
            if ubuntu?
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

      def guest_root
        node[:rightimage][:guest_root]
      end

      def target_raw_root
        "/mnt/storage"
      end

      def loopback_file(partitioned = true)
        "#{target_raw_root}/#{loopback_filename(partitioned)}"
      end

      def loopback_filename(partitioned = true)
        nibble = partitioned ? "0" : ""
        "#{ri_lineage}_hd0#{nibble}.raw"
      end

      def temp_root
        "/mnt/rightimage-temp"
      end

      def image_source_bucket
        bucket = "rightscale-#{image_source_cloud}"
        bucket << "-dev" if node[:rightimage][:debug] == "true"
        bucket
       end

      def image_source_cloud
        "us-west-2"
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
        when /rackspace/i
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
        elsif node[:rightimage][:cloud] =~ /rackspace/i
          return true
        else
          return false
        end
      end

      def ubuntu?
        node[:rightimage][:platform] == "ubuntu"
      end

      def centos?
        node[:rightimage][:platform] == "centos"
      end

      def rhel?
        node[:rightimage][:platform] == "rhel"
      end

      def el?
        centos? || rhel?
      end

      def el6?
        (centos? || rhel?) and node[:platform_version].to_f >= 6.0
      end

      def epel_key_name
        if node[:rightimage][:platform_version].to_i >= 6.0
          "-#{node[:rightimage][:platform_version][0].chr}"
        else
          ""
        end
      end
    end
  end
end
