helpers do
  def set_tester_inputs
    clouds = ::VirtualMonkey::Toolbox::get_available_clouds
    servers.each do |s|
      cloud_name = clouds.find { |c| c["cloud_id"].to_i == s.cloud_id.to_i }["name"]
      if cloud_name =~ /rackspace|softlayer/i
        ipv6 = "false"
        root_login_disabled = "false"
      else
        ipv6 = "true"
        root_login_disabled = "true"
      end

      if cloud_name =~ /rackspace.open.cloud/i
        root_size = "40"
      elsif cloud_name =~ /softlayer/i
        root_size = "25"
      else
        root_size = "10"
      end

      s.set_inputs({
        "rightimage_tester/test_ssh_security" => "text:#{root_login_disabled}",
        "rightimage_tester/test_ipv6" =>         "text:#{ipv6}",
        "rightimage_tester/root_size" =>         "text:#{root_size}"
      })
    end
  end
end

before do
  stop_all
  # Use launch set instead of relaunch_all, which launches things serially in --one-deploy is set
  set_tester_inputs
  launch_set
end

test_case "default" do
  wait_for_all("operational")
end

after do
  stop_all
end
