module VirtualMonkey
  module Runner
    class BaseSnapshots
      extend  VirtualMonkey::RunnerCore::CommandHooks
      include VirtualMonkey::RunnerCore::DeploymentBase
      include VirtualMonkey::Mixin::ServerMetadata

      description "This runner will build a rightimage base snapshot for os type and architecture (ubuntu 10, 12, centos 5, 6)"
      def lineage_date 
        if ENV.has_key?('LINEAGE_DATE') and ENV['LINEAGE_DATE'] =~ /^\d{12}$/
          return ENV['LINEAGE_DATE']
        else
          # Minus 1 day, todays mirrors may not be ready yet
          ts = Time.now - (3600*24)
          return "%04d%02d%02d%02d%02d" % [ts.year,ts.month,ts.day,ts.hour,0]
        end
      end

      def mirror_freeze_date
        if ENV['MIRROR_FREEZE_DATE'] && ENV['MIRROR_FREEZE_DATE'] =~ /^\d{8}$/
          return ENV['MIRROR_FREEZE_DATE']
        else
          return lineage_date[0..7]
        end
      end

      def build_id
        if ENV.has_key?('RIGHTIMAGE_VERSION') && !ENV['RIGHTIMAGE_VERSION'].to_s.empty?
          version = ENV['RIGHTIMAGE_VERSION']
          ::Dir.chdir(::File.dirname(__FILE__)) do
            sha_full  = `git log -1 --pretty="%H"`
            unless $?.success?
              raise "Could not get sha for rightimage_private repo"
            end
            sha = sha_full.chomp[0..7]
            return "#{version}-#{sha}"
          end
        else
          return nil
        end
      end

      def get_os_version(platform,platform_release,platform_arch,mirror_freeze_date)
        if platform == "ubuntu"
          platform_release
        elsif platform == "centos"
          major_version = platform_release.split(".").first
          repo_name = major_version == "5" ? "CentOS" : "Packages"
          release_line = `curl --silent http://mirror.rightscale.com/centos/#{major_version}/os/#{platform_arch}/archive/#{mirror_freeze_date}/#{repo_name}/ | grep centos-release-[1-9] | sort -r | head -1`.strip
          if release_line.empty?
           raise "Could not get release from mirror website"
          end

          release = /centos-release-([0-9-]*)\./.match(release_line)[1].gsub("-",".")
        else
          raise "Invalid platform #{platform} passed to get_os_version"
        end
      end

      # assumes you've ran setup_rightimage_repos script to pull to master
      # tags what the rightimage SHA we used to create the base image
      # was for later reproducibility
      def tag_repository(tag)
        ::Dir.chdir(::File.dirname(__FILE__)) do
          `git tag #{tag}` unless `git tag`.split.include?(tag)
          `git push --tags`
        end
      end

      def base_builder_lookup_scripts
        scripts = [
                   ['block_device_destroy', 'rightimage::block_device_destroy']
                  ]
        st = match_st_by_server(s_one)
        load_script_table(st,scripts)
      end

    end
  end
end
