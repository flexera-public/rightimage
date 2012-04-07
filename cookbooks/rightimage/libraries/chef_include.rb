# tie RightImage classes into chef
module RightImage
end

class Chef::Recipe
  include RightImage
end
