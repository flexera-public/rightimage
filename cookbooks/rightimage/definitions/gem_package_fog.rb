define :gem_package_fog do
  # This is a fog dependency.  The gem dependency code has a bug and causes fog install to fail unless we install this explicitly before
  r = gem_package "net-ssh" do
    gem_binary "/opt/rightscale/sandbox/bin/gem"
    version "2.1.4"
    action :nothing
  end
  r.run_action(:install)

  # This is a fog dependency for version 1.3.1.  0.13.3 causes ssl connection errors, 0.13.2 seems ok. pin until its fixed
  # Use rubygems to get around mirror freeze date, for now
  r = gem_package "excon" do
    gem_binary "/opt/rightscale/sandbox/bin/gem"
    version "0.13.2"
    source "http://rubygems.org"
    action :nothing
  end
  r.run_action(:install)
  Gem.clear_paths

  %w(formatador multi_json net-scp ruby-hmac).each do |package|
    r = gem_package package do
      gem_binary "/opt/rightscale/sandbox/bin/gem"
      action :nothing
    end
    r.run_action(:install)
    Gem.clear_paths
  end

  r = gem_package "fog" do
    gem_binary "/opt/rightscale/sandbox/bin/gem"
    version "1.3.1"
    source "http://rubygems.org"
    action :nothing
  end
  r.run_action(:install)
  Gem.clear_paths
end
