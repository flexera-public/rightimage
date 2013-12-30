module RightScale
  module RightImage
    module Helper
      def image_name
        raise "ERROR: you must specify an image_name!" unless node[:rightimage][:image_name] =~ /./
        name = node[:rightimage][:image_name].dup
        name << "_#{generate_persisted_passwd}" if node[:rightimage][:debug] == "true" && node[:rightimage][:cloud] !~ /rackspace/
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
          (if node[:rightimage][:cloud] == "eucalyptus"
            "tar.gz"
          elsif node[:rightimage][:cloud] == "ec2"
            "raw"
          else
            "vhd.bz2"
          end)
        when "kvm"
          case node[:rightimage][:cloud]
          when "google"
            "tar.gz"
          when "openstack"
            "qcow2"
          else
            "qcow2.bz2"
          end
        when "esxi"
          "vmdk.ova"
        when "hyperv"
          "vhd"
        when "virtualbox"
          "box"
        end
      end

      def uncomp_image_ext
        case node[:rightimage][:hypervisor]
        when "xen"
          (if node[:rightimage][:cloud] == "eucalyptus"
            "img"
          elsif node[:rightimage][:cloud] == "ec2"
            "raw"
          else
            "vhd"
          end)
        when "kvm"
          (node[:rightimage][:cloud] == "google" ? "raw":"qcow2")
        when "esxi"
          "vmdk"
        when "hyperv"
          "vhd"
        when "virtualbox"
          "box"
        end
      end

      def ri_lineage
        # build id can't contain any underscores or block device lineage parsing will fail
        ["base_image",guest_platform,guest_platform_version,guest_arch,mirror_freeze_date,build_id].join("_")
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

      def build_id
        if node[:rightimage][:build_id] =~ /./
          node[:rightimage][:build_id].gsub("_","-")
        else
          "0"
        end
      end

      def do_loopback_resize
        node[:rightimage][:root_size_gb].to_i != loopback_size
      end

      def loopback_size
        source_size = `qemu-img info #{loopback_file_base} | grep "virtual size" | cut -d '(' -f2 | cut -d ' ' -f1`.chomp.to_i
        (source_size/1024/1024/1024).to_i
      end

      def guest_root
        node[:rightimage][:guest_root]
      end

      def target_raw_root
        node[:rightimage][:build_dir]
      end

      def loopback_device
        "/dev/nbd"
      end

      def loopback_file
        node[:rightimage][:build_mode] == "base" ? loopback_file_base : loopback_file_backup
      end
	  
      def loopback_file_base
        "#{target_raw_root}/#{loopback_filename}"
      end

      def loopback_rootname
        "#{ri_lineage}_hd00"
      end

      def loopback_filename
        loopback_rootname + ".qcow2"
      end

      def temp_root
        "/mnt/ephemeral/rightimage-temp"
      end

      def image_source_bucket
        bucket = "rightscale-#{image_source_cloud}"
        bucket << "-dev" if node[:rightimage][:debug] == "true"
        bucket
      end

      def loopback_file_compressed
        loopback_file_base + ".bz2"
      end	  
	  
      def loopback_filename_compressed
        loopback_filename + ".bz2"
      end
	  
      def loopback_file_backup
	      "#{target_raw_root}/#{loopback_rootname}-full.qcow2"
      end

      def image_source_cloud
        "us-west-2"
      end

      def mounted?(dir = target_raw_root)
        `mount`.grep(/#{dir}/).any?
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
        when "google"
          return {'GOOGLE_KEY_LOCATION' => google_p12_path,
                  'GOOGLE_PROJECT' => node[:rightimage][:google][:project_id],
                  'GOOGLE_SERVICE_EMAIL' => node[:rightimage][:google][:client_email]}
        when /rackspace/i
          return {'RACKSPACE_ACCOUNT' => node[:rightimage][:rackspace][:account],
                  'RACKSPACE_API_TOKEN' => node[:rightimage][:rackspace][:api_token]}
        else
          raise "Cloud #{cloud_type} passed to cloud_credentials, which it doesn't know how to handle"
        end
      end

      def google_p12_path
        "/tmp/google.p12"
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
        if (node[:rightimage][:cloud] == "ec2" || node[:rightimage][:cloud] == "google") and node[:rightimage][:platform] == "rhel"
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

      def gem_install_source
        "--source http://#{node[:rightimage][:mirror]}/rubygems/archive/#{mirror_freeze_date}/"
      end


      def chroot_install
        if node[:rightimage][:platform] == "ubuntu" 
          "chroot #{guest_root} apt-get -y install"
        else
          "yum -c /tmp/yum.conf --installroot=#{guest_root} -y install"
        end
      end

      def chroot_remove
        if node[:rightimage][:platform] == "ubuntu"
          "chroot #{guest_root} apt-get -y purge"
        else
          "yum -c /tmp/yum.conf --installroot=#{guest_root} -y erase"
        end
      end

      def grub_root
        if partitioned?
          "(hd0,0)"
        else
          "(hd0)"
        end
      end

      def partitioned?
        # Don't partition EC2 images because it's not easy to rebundle them later without manual changes.
        node[:rightimage][:build_mode] == "base" ||  (node[:rightimage][:mode] == "full" && node[:rightimage][:cloud] != "ec2")
      end

      # Mirror freeze date is used to name the snapshots that base images are stored to and restored from
      # For base images, we'll use the specified freezedate or default to the latest date
      # For full images, we'll restored from the specified freezedate, or else poll the API for
      # the latest snapshot and use that.
      def mirror_freeze_date
        return @@mirror_freeze_date if defined?(@@mirror_freeze_date)

        if !node[:rightimage][:mirror_freeze_date].to_s.empty?
          @@mirror_freeze_date = node[:rightimage][:mirror_freeze_date]
        elsif node[:rightimage][:build_mode] == "base"
          # Minus one day, today's mirror may not be ready depending on the time
          # use 0 for hour and minute fields, if we run block_device_create and block_device_backup
          # separately during development we would like the value to remain stable.
          # bit of a hack, maybe store this value to disk somewhere?
          ts = Time.now - (3600*24)
          @@mirror_freeze_date = "%04d%02d%02d" % [ts.year,ts.month,ts.day]
          Chef::Log::info("Using latest available mirror date (#{@@mirror_freeze_date}) as mirror_freeze_date input")
        elsif rebundle?
          Chef::Log::info("Using latest available mirror date for rebundle")
          @@mirror_freeze_date = nil
        elsif node[:rightimage][:build_mode] == "full"
          set_mirror_freeze_date_from_snapshot
          @@mirror_freeze_date = node[:rightimage][:mirror_freeze_date]
        else
          raise "Undefined build_mode #{node[:rightimage][:build_mode]}, must be base or full"
        end
        return @@mirror_freeze_date
      end

      def set_mirror_freeze_date_from_snapshot
        require 'rest_client'
        require 'json'
        require '/var/spool/cloud/user-data'

        os = node[:rightimage][:platform]
        ver = node[:rightimage][:platform_version]
        arch = node[:rightimage][:arch]

        Chef::Log.info("A mirror_freeze_date was not supplied, attempting to restore from the latest snapshot")
        Chef::Log.info("Searching for snapshots with the form base_image_#{os}_#{ver}_#{arch}")

        url = ENV['RS_API_URL']
        body = RestClient.get(url + '/find_ebs_snapshots.js?api_version=1.0')
        snapshots = JSON.load(body)

        filtered_snaps = snapshots.select do |s| 
          s['nickname'] =~ /base_image_#{os}_#{ver}_#{arch}_(\d{8,12})_([^_]+)_(.+)/ &&
          s['aws_status'] == "completed"
        end
        if filtered_snaps.length > 0
          sorted_snaps = filtered_snaps.map do |s|
            # $1=repo freezedate, $2=build_id, $3=aws snapshot timestamp
            s['nickname'] =~ /_(\d{8,12})_([^_]+)_(.+)/
            freezedate = $1
            build_id = $2
            timestamp = $3
            if timestamp =~ /_(\d{8,})$/
              timestamp = $1
            end
            [s,freezedate,build_id,timestamp]
          end
          sorted_snaps.sort! { |a,b| a[1..3] <=> b[1..3] }

          snapshot = sorted_snaps.last[0]
          if snapshot['nickname'] =~ /(base_image_#{os}_#{ver}_#{arch}_(\d{8,12})_([^_]+))_/
            lineage = $1
            Chef::Log.info("Found #{sorted_snaps.length} snapshots, using latest with lineage #{lineage}")
            node[:rightimage][:mirror_freeze_date] = $2[0..7]
            node[:rightimage][:build_id] = $3
          else
            raise "Unable to parse lineage out of snapshot name #{snap["nickname"]}"
          end
        else
          raise "No snapshots found matching lineage base_image_#{os}_#{ver}_#{arch}_*. You have to first run a build with build_mode set to base to generate a base image snapshot"
        end
      end

      def version_compare(str1, str2)
        str1_bits = str1.split(".").map(&:to_i)
        str2_bits = str2.split(".").map(&:to_i)
        # zero pad one string or the other if they are not the same length
        if str1_bits.size > str2_bits.size
          (str1_bits.size - str2_bits.size).times { str2_bits << 0 }
        elsif str2_bits.size > str1_bits.size
          (str2_bits.size - str1_bits.size).times { str1_bits << 0 }
        end
        str1_bits <=> str2_bits
      end

    end
  end
end
