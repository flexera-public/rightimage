set :runner, VirtualMonkey::Runner::BaseSnapshots

hard_reset do
  @runner.stop_all
end

before do
  @runner.stop_all
end

test "default" do

  # "variables" from the aether
  #
  # mirror_freeze_date - see runner - imported from env var MIRROR_FREEZE_DATE
  # build_id - see runner, is <rightimage_version>_<rightimage_creator_sha> generated from RIGHTIMAGE_VERSION environment variable
  
  VirtualMonkey::config[:operational_timeout] = 7200

  # Run the base snapshots builder, tag it in case anything goes wrong
  @runner.tag_all_servers("rs_agent_dev:download_cookbooks_once=true")

  metadata = get_server_metadata(s_one)
  os = metadata[:os]
  os_base_version = metadata[:os_version]
  long_arch  = metadata[:os_arch] =~ /386|586|686/ ? 'i386' : 'x86_64'
  short_arch = metadata[:os_arch] =~ /386|586|686/ ? 'i386' : 'x64'
  os_version = get_os_version(os,os_base_version,long_arch,mirror_freeze_date)


  # deprecated variables (needed for 12H1), delete later
  os_release = os == "ubuntu" ? get_ubuntu_release_name(os_version) : os_version
  s_one.set_input('rightimage/virtual_environment', "text:xen")
  s_one.set_input('rightimage/release', "text:#{os_release}")

  # example image_name: RightImage_Ubuntu_10.04_i386_v5.7.14_Dev1
  image_name = "RightImage_Base_#{os.capitalize}_#{os_version}_#{short_arch}"
  puts "Building #{os}_#{os_version}_#{short_arch}, freeze_date #{mirror_freeze_date}, build_id #{build_id}"

  s_one.set_input('rightimage/image_name',"text:#{image_name}")
  s_one.set_input('rightimage/mirror_freeze_date', "text:#{mirror_freeze_date}")
  s_one.set_input('rightimage/arch', "text:#{long_arch}")
  s_one.set_input('rightimage/platform', "text:#{os}")
  s_one.set_input('rightimage/platform_version', "text:#{os_version}")
  s_one.set_input('rightimage/build_id', "text:#{build_id}")
  s_one.set_input('rightimage/cloud', "text:ec2")
  s_one.set_input('rightimage/hypervisor', "text:xen")


  s_one.launch
  wait_for_server_state(s_one, "operational")
  run_script_on_all('block_device_destroy')
  s_one.stop

  # tag repository for later reproducibilty, but not for one offs and hand builds
  if ENV['PRODUCTION']
    tag_repository("base_#{mirror_freeze_date}_#{build_id}")
  end
end

