module RightScale
  module RightImage
    module Helper
      def image_name
        raise "ERROR: you must specify an image_name!" unless node[:rightimage][:image_name] =~ /./
        name = node[:rightimage][:image_name].dup
        name << "_#{generate_persisted_passwd}" if node[:rightimage][:debug] == "true" && node[:rightimage][:build_mode] != "migrate" && node[:rightimage][:cloud] !~ /rackspace/
        name << "_HVM" if hvm? and name !~ /_HVM/
        name << "_EBS" if node[:rightimage][:ec2][:image_type] =~ /ebs/i and name !~ /_EBS/
        name.gsub!("_","-") if node[:rightimage][:cloud] =~ /rackspace|google|azure/
        name.gsub!(".","-") if node[:rightimage][:cloud] =~ /google/
        name.downcase! if node[:rightimage][:cloud] =~ /google/
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

      def image_file_ext
        case node[:rightimage][:hypervisor]
        when "xen"
          (node[:rightimage][:cloud] == "eucalyptus" ? "tar.gz":"vhd.bz2")
        when "kvm"
          "qcow2.bz2"
        when "esxi"
          "vmdk.ova"
        when "hyperv"
          "vhd"
        end
      end

      def ri_lineage
        ["base_image",guest_platform,guest_platform_version,guest_arch,timestamp,build_number].join("_")
      end

      # call this guest_platform, not platform, otherwise can introduce a 
      # weird bug where platform func can overwrite chef default platform func
      def guest_platform
        node[:rightimage][:platform] || node[:platform]
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

      def guest_platform_version
        node[:rightimage][:platform_version] || node[:platform_version]
      end

      def guest_arch
        if node[:rightimage][:arch] == "x64"
          "x86_64"
        else
          node[:rightimage][:arch] || node[:kernel][:machine]
        end
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

      def do_loopback_resize
        source_size_gb = (::File.size(loopback_file(partitioned?))/1024/1024/1024).to_f.round
        node[:rightimage][:root_size_gb].to_i != source_size_gb
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

      def el_repo_file
        repo_file = case node[:rightimage][:platform]
                    when "centos" then "CentOS-Base"
                    when "rhel" then "Epel"
                    end
        "#{repo_file}.repo"
      end

      def epel_key_name
        if node[:rightimage][:platform_version].to_i >= 6.0
          "-#{node[:rightimage][:platform_version][0].chr}"
        else
          ""
        end
      end

      def hvm?
        node[:rightimage][:virtualization] == "hvm"
      end

      def gem_install_source
        "--source http://#{node[:rightimage][:mirror]}/rubygems/archive/#{timestamp[0..7]}/"
      end

      def grub_initrd
        ::File.basename(Dir.glob("#{guest_root}/boot/initr*").sort_by { |f| File.mtime(f) }.last)
      end

      def grub_kernel
        ::File.basename(Dir.glob("#{guest_root}/boot/vmlinuz*").sort_by { |f| File.mtime(f) }.last)
      end

      def grub_root
        "(hd0" + ((partitioned? || hvm?) ? ",#{partition_number}":"") + ")"
      end

      # Timestamp is used to name the snapshots that base images are stored to and restored from
      # For base images, we'll use the specified timestamp or default to the latest date
      # For full images, we'll restored from the specified timestamp, or else poll the API for
      # the latest snapshot and use that.
      def timestamp
        return @@timestamp if defined?(@@timestamp)

        if !node[:rightimage][:timestamp].to_s.empty?
          @@timestamp = node[:rightimage][:timestamp]
        elsif node[:rightimage][:build_mode] == "base"
          # Minus one day, today's mirror may not be ready depending on the time
          # use 0 for hour and minute fields, if we run block_device_create and block_device_backup
          # separately during development we would like the value to remain stable.
          # bit of a hack, maybe store this value to disk somewhere?
          ts = Time.now - (3600*24)
          @@timestamp = "%04d%02d%02d%02d%02d" % [ts.year,ts.month,ts.day,0,0]
          Chef::Log::info("Using latest available mirror date (#{@@timestamp}) as timestamp input")
        elsif node[:rightimage][:build_mode] == "migrate"
          @@timestamp = nil
        elsif rebundle?
          Chef::Log::info("Using latest available mirror date for rebundle")
          @@timestamp = nil
        elsif node[:rightimage][:build_mode] == "full"
          set_timestamp_from_snapshot
          @@timestamp = node[:rightimage][:timestamp]
        else
          raise "Undefined build_mode #{node[:rightimage][:build_mode]}, must be base, migrate, or full"
        end
        return @@timestamp
      end

      def set_timestamp_from_snapshot
        require 'rest_client'
        require 'json'
        require '/var/spool/cloud/user-data'

        os = node[:rightimage][:platform]
        ver = node[:rightimage][:platform_version]
        arch = node[:rightimage][:arch]

        Chef::Log.info("A timestamp was not supplied, attempting to restore from the latest snapshot")
        Chef::Log.info("Searching for snapshots with the form base_image_#{os}_#{ver}_#{arch}")

        url = ENV['RS_API_URL']
        body = RestClient.get(url + '/find_ebs_snapshots.js?api_version=1.0')
        snapshots = JSON.load(body)

        filtered_snaps = snapshots.select do |s| 
          s['nickname'] =~ /base_image_#{os}_#{ver}_#{arch}_(\d{8,})_(\d+)_(\d+)/ &&
          s['aws_status'] == "completed"
        end
        if filtered_snaps.length > 0
          sorted_snaps = filtered_snaps.map do |s|
            # $1=repo freezedate, $2=build_number, $3=aws snapshot timestamp
            s['nickname'] =~ /_(\d{8,})_(\d+)_(\d+)/
            [s,$1,$2.to_i,$3]
          end
          sorted_snaps.sort! { |a,b| a[1..3] <=> b[1..3] }

          snapshot = sorted_snaps.last[0]
          if snapshot['nickname'] =~ /(base_image_#{os}_#{ver}_#{arch}_(\d{8,})_(\d+))_/
            lineage = $1
            Chef::Log.info("Found #{sorted_snaps.length} snapshots, using latest with lineage #{lineage}")
            node[:rightimage][:timestamp] = $2
            node[:rightimage][:build_number] = $3
          else
            raise "Unable to parse lineage out of snapshot name #{snap["nickname"]}"
          end
        else
          raise "No snapshots found matching lineage base_image_#{os}_#{ver}_#{arch}_*. You have to first run a build with build_mode set to base to generate a base image snapshot"
        end
      end
    end
  end
end
