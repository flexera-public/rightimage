module RightScale
  module RightImage
    module Helper
      
      # Construct image name.
      def image_name
        
        override_name = node.right_image_creator.image_name_override
        return override_name if override_name && override_name != ""
        
        release = node[:right_image_creator][:rightscale_release]
        suffix = node[:right_image_creator][:image_postfix]

        image_name = ""
        image_name << node[:right_image_creator][:image_prefix] + '_' if node[:right_image_creator][:image_prefix]
        image_name << node[:right_image_creator][:platform].capitalize + '_'
        image_name << node[:right_image_creator][:release_number] + '_'
        if node[:right_image_creator][:arch] == "x86_64"
          image_name << "x64" + '_'
        else
          image_name << node[:right_image_creator][:arch] + '_'
        end
        image_name << 'v' + release 
        image_name << '_' + suffix if suffix
        image_name
      end   
      
    end
  end
end
