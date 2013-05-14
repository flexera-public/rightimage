module VirtualMonkey
  module Mixin
    module ServerMetadata
      extend VirtualMonkey::RunnerCore::CommandHooks

      # This grabs data from the server like platform (ubuntu/centos/windows), version, architecture (x84_64/i386)
      # Sort of a dirty hack, copied from grinder monk since this it isn't available yet.  It does it in a very roundabout
      # way, parsing the info from the image name which is stored in tags on the deployment due Rightscale API limitations
      #
      # === Parameters
      # server (RestConnection::Server) :: server to pull the metadata from
      # die_on_failure (Boolean) :: if anything goes wrong, die rather than print a warning message
      #
      # === Returns
      # data (Hash) :: keys
      #   :mci_name - Multicloud image name, parsed for metadata
      #   :mci_id - Multicloud id
      #   :os - rhel || ubuntu || centos || windows
      #   :os_version - i.e. 10.04, 5.6, 2008
      #   :os_arch - i386 || x86_64
      # false if there is already a build or an error occured attempting to get the latest build
      def get_server_metadata(server,die_on_failure = true)
        err_func = die_on_failure ? :raise : :puts
        
       
        if server.cloud_id < 10
          deployment = Deployment.find(server.deployment_href)
        else
          deployment = McDeployment.find(server.deployment_href)
        end

        data = {}
        tags = deployment.get_info_tags["self"]
        tags.each do |key,val|
          if key =~ /mci_id/
            mci = MultiCloudImage.find(val.to_i)

            if mci.nil?
              send(err_func,"Unable to find mci #{val.to_i} for server #{server.rs_id}")
            else
              data[:mci_name] = mci.name
              data[:mci_id] = mci.rs_id
            end

            # Extra Info
            # Nickname, Arch, and RightLink version are optional matches
            if mci.name =~ /CentOS/i
              #        CentOS  Version   Arch    RightLink
              regex = /(CentOS)_([.0-9]*)(?:_(x64|x86_64|i386))?(?:_v([.0-9]+))?/i
            elsif mci.name =~ /RHEL/i
              #        RHEL Version   Arch    RightLink
              regex = /(RHEL)_([.0-9]*)(?:_(x64|x86_64|i386))?(?:_v([.0-9]+))?/i
            elsif mci.name =~ /Ubuntu/i
              #        Ubuntu  Version Nickname    Arch    RightLink
              regex = /(Ubuntu)_([.0-9]*)(?:_[a-zA-Z]{3,})?(?:_(x64|x86_64|i386))?(?:_v([.0-9]+))?/i
            elsif mci.name =~ /Windows/i
              #        Windows  Version   ServicePack  Arch    App    RightLink
              regex = /(Windows)_([0-9A-Za-z]*[_SP0-9]*)_([^_]*)[\w.]*_v([.0-9]*)/i
            else
              send(err_func,"Unable to determine operating system from mci name #{mci.name}")
            end
            if (regex.match(mci.name))
              data[:os] = $1.downcase
              data[:os_version] = $2
              data[:os_arch] = $3
              data[:rightlink_version] = $4
            else
              send(err_func, "Regular expression was unable to parse #{mci.name}")
            end
          end
        end
        return data
      end

      def get_ubuntu_release_name(tag)
        lookup = {
          "8.04"  => "hardy",
          "8.10"  => "intrepid",
          "9.04"  => "jaunty",
          "9.10"  => "karmic",
          "10.04" => "lucid",
          "10.10" => "maverick",
          "11.04" => "natty",
          "11.10" => "oneiric",
          "12.04" => "precise"
          }
        if lookup.has_key?(tag)
          lookup[tag]
        else
          raise "Could not find ubuntu release name for #{tag}"
        end
      end
    end
  end
end
