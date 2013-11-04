# Tie RightImage classes into chef.

module RightScale
  module RightImage
    module Helper
    end
    module Grub
    end
  end
end

module RightImage
end


class Erubis::Context
  include RightScale::RightImage::Grub
  include RightScale::RightImage::Helper
  include RightImage
end

class Chef::Resource
  include RightScale::RightImage::Grub
  include RightScale::RightImage::Helper
  include RightImage
end

class Chef::Recipe
  include RightScale::RightImage::Grub
  include RightScale::RightImage::Helper
  include RightImage
end

class Chef::ResourceDefinitionList
  include RightScale::RightImage::Grub
  include RightScale::RightImage::Helper
  include RightImage
end
