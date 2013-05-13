set :runner, VirtualMonkey::Runner::Simple

hard_reset do
end

before do
  s_one.set_input("SKIP_ON_BOOT", "text:true")
  s_one.launch
  wait_for_server_state(s_one, "operational")
  load_script("container_backup", 392014)
  ::VirtualMonkey::config[:completed_timeout] = 7200
end

test "default" do
  @runner.tag_all_servers("rs_agent_dev:download_cookbooks_once=true")
  @dsts = [
    {:country => "text:US",
     :user => "cred:RACKSPACE_USERNAME_TEST",
     :pass=> "cred:RACKSPACE_AUTH_KEY_TEST"},
    {:country => "text:UK",
     :user => "cred:RACKSPACE_USERNAME_UK_TEST",
     :pass=> "cred:RACKSPACE_AUTH_KEY_UK_TEST"}
  ]
  @srcs = [ 
    {:country => "text:US",
     :user => "cred:RACKSPACE_USERNAME",
     :pass => "cred:RACKSPACE_AUTH_KEY",
     :src_bucket =>"text:cloudservers", 
     :dest_bucket => "text:cloudservers_publish_backup",
     :dest => @dsts[0]},
    {:country => "text:US",
     :user => "cred:RACKSPACE_MANAGED_USERNAME_US",
     :pass => "cred:RACKSPACE_MANAGED_AUTH_KEY_US",
     :src_bucket =>"text:cloudservers", 
     :dest_bucket => "text:cloudservers_publish_backup_managed",
     :dest => @dsts[0]},
    {:country => "text:UK",
     :user => "cred:RACKSPACE_USERNAME_UK",
     :pass => "cred:RACKSPACE_AUTH_KEY_UK",
     :src_bucket =>"text:cloudservers", 
     :dest_bucket => "text:cloudservers_publish_backup",
     :dest => @dsts[1]}
  ]


  @srcs.each_with_index do |src, i|
    dst = src[:dest]

    puts "Backing up from #{src[:country]} to #{dst[:country]}"
    s_one.set_input("SRC_COUNTRY", src[:country])
    s_one.set_input("STORAGE_ACCOUNT_ID_SRC", src[:user])
    s_one.set_input("STORAGE_ACCOUNT_SECRET_SRC", src[:pass])
    s_one.set_input("CONTAINER_SRC", src[:src_bucket])

    s_one.set_input("DEST_COUNTRY", dst[:country])
    s_one.set_input("STORAGE_ACCOUNT_ID_DEST", dst[:user])
    s_one.set_input("STORAGE_ACCOUNT_SECRET_DEST", dst[:pass])
    s_one.set_input("CONTAINER_DEST", src[:dest_bucket])

    s_one.set_input("SKIP_ON_BOOT", "text:false")
    run_script("container_backup", s_one)
  end

  s_one.stop
end
