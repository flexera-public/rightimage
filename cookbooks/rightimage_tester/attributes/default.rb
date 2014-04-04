
# Most rightimage tests occur after the image has booted in the cloud
# Static tests are tests that can't very easily be at this time since
# they'll check for files that may be created after instance creation
# So run them before when image is mounted as loopback file
# When set to true tests will error out of problems.  When set to false
# tests will still run but issues will be downgraded to warnings
default[:rightimage_tester][:run_static_tests] = false
default[:rightimage_tester][:root] = ""
