
action :sanitize do
  
  ruby_block "sanitize" do
    block do
      util = RightImage::Util.new(new_resource.name, Chef::Log)
      util.sanitize()
    end
  end
  
end