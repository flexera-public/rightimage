# tie RightImage classes into chef
class Chef::Recipe
  require ::File.join(::File.dirname(__FILE__), "common", "lib", "s3_indexer")
  include RightImage
end
