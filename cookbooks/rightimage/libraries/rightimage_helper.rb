module RightScale
  module RightImage
    module Helper
      
      # Construct image name.
      def image_name
        
        override_name = node.rightimage.image_name_override
        return override_name if override_name && override_name != ""
        
        release = node[:rightimage][:rightscale_release]
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
      
    end
  end
end
