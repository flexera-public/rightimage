define :gem_package_fog do
  gem_package "fog" do
    gem_binary "/usr/bin/gem"
    version "1.5.0"
    action :install
  end
end
