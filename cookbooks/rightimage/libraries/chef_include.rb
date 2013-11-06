# Tie RightImage classes into chef.

module RightScale
  module RightImage
    module Helper
    end
  end
end

module RightImage
end


class Erubis::Context
  include RightScale::RightImage::Helper
  include RightImage
end

class Chef::Resource
  include RightScale::RightImage::Helper
  include RightImage
end

class Chef::Recipe
  include RightScale::RightImage::Helper
  include RightImage
end

class Chef::ResourceDefinitionList
  include RightScale::RightImage::Helper
  include RightImage
end
