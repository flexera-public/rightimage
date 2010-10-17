
rightimage_image "test_image" do 
  platform 'ubuntu'
  release 'lucid'
  architecture 'x86_64'
  size '512'
  action :create
  directory '/tmp/image4'
  mirror 'http://127.0.0.1:9999/ubuntu'
  
end
