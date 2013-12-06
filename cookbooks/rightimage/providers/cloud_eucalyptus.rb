
action :configure do
  euca_tools_version = "1.3.1"

  ruby_block "check hypervisor" do
    block do
      raise "ERROR: you must set your hypervisor to xen!" unless new_resource.hypervisor == "xen"
    end
  end

  execute "install iscsi tools" do 
    only_if { node[:rightimage][:platform] =~ /redhat|rhel|centos/ }
    command "chroot #{guest_root} yum -y install iscsi-initiator-utils"
  end
  

  bash "install euca tools for ubuntu" do
    only_if { node[:rightimage][:platform] == "ubuntu" }
    flags "-ex"
    code <<-EOH
      # install on host
      apt-get -y install euca2ools

      #install on guest_root image
      chroot #{guest_root} apt-get install -y euca2ools
    EOH
  end

  bash "clean yum" do
    only_if { node[:platform] == "centos" }
    flags "-x"
    code <<-EOH
      yum clean all
    EOH
  end

  cookbook_file "/tmp/euca2ools-#{euca_tools_version}-centos-i386.tar.gz" do 
    source "euca2ools-#{euca_tools_version}-centos-i386.tar.gz"
    backup false
  end

  cookbook_file "/tmp/euca2ools-#{euca_tools_version}-centos-x86_64.tar.gz" do 
    source "euca2ools-#{euca_tools_version}-centos-x86_64.tar.gz"
    backup false
  end

  bash "install euca tools for centos" do 
    only_if { node[:rightimage][:platform] == "centos" }
    flags "-ex"
    code <<-EOH
      VERSION=#{euca_tools_version}  
      guest_root=#{guest_root}
        
      # install on host
      cd /tmp
      export ARCH=#{node[:kernel][:machine]}
      tar -xzvf euca2ools-$VERSION-centos-$ARCH.tar.gz 
      cd  euca2ools-$VERSION-centos-$ARCH
      rpm -i --force * 

      # install on guest_root image
      cd $guest_root/tmp/.
      export ARCH=#{node[:rightimage][:arch]}
      cp /tmp/euca2ools-$VERSION-centos-$ARCH.tar.gz $guest_root/tmp/.
      tar -xzvf euca2ools-$VERSION-centos-$ARCH.tar.gz
      chroot $guest_root rpm -i --force /tmp/euca2ools-$VERSION-centos-$ARCH/*
      
    EOH
  end

  # Need to cleanup for ubuntu?
  bash "clean up yum cache" do
    flags "-ex"
    only_if { node[:rightimage][:platform] == "centos" }
    code <<-EOH
      guest_root=#{guest_root}

      # clean out packages
      chroot $guest_root yum -y clean all
      
      rm ${guest_root}/var/lib/rpm/__*
      chroot $guest_root rpm --rebuilddb

    EOH
  end
end

action :package do
  # Euca needs loopback to be mounted still.
  loopback_fs loopback_file do
    mount_point guest_root
    action :mount
  end

  bash "package guest image for eucalyptus" do 
    cwd "/mnt"
    flags "-ex"
    code <<-EOH
      guest_root=#{guest_root}
      image_name=#{image_name}
      cloud_package_root=#{target_raw_root}
      package_dir=$cloud_package_root/$image_name
      KERNEL_VERSION=$(ls -t $guest_root/lib/modules|awk '{ printf "%s ", $0 }'|cut -d ' ' -f1-1)
      INITRD=#{new_resource.platform == "ubuntu" ? "initrd.img" : "initrd"}

      rm -rf $package_dir $cloud_package_root/$image_name.tar.gz
      mkdir -p $package_dir
      cd $cloud_package_root
      cp #{loopback_file} $package_dir/$image_name.img
      tar czvf $image_name.tar.gz $image_name 
    EOH
  end

  # Make sure to unmount the loopback here because it should not normally be mounted during package action.
  loopback_fs loopback_file do
    mount_point guest_root
    action :unmount
  end
end

action :upload do
  tmp_creds_dir = "#{target_raw_root}/temp/euca_upload_creds"

  ## copy the generic image 
  bash "copy_image" do
    flags "-ex"
    code <<-EOC
    image_name=#{image_name}
    tmp_creds_dir=#{tmp_creds_dir}
    
    
    # 
    # Get paths to deliverables
    #
    package_dir=#{target_raw_root}

    image_path=$package_dir/$image_name/$image_name.img
    if [ -a $image_path ]; then 
      echo "Image to upload found: "$image_path
    else
      echo "ERROR: no image found at "$image_path 
      exit 1
    fi


    # 
    # Setup paths
    #
    export S3_URL=#{node[:rightimage][:euca][:euca_url]}:8773/services/Walrus
    export EC2_URL=#{node[:rightimage][:euca][:euca_url]}:8773/services/Eucalyptus

    
    #
    # Setup creds for upload
    #
    rm -rf $tmp_creds_dir
    mkdir -p $tmp_creds_dir
    cd $tmp_creds_dir

    # Global Cloud Cert
    export EC2_JVM_ARGS=-Djavax.net.ssl.trustStore=$tmp_creds_dir/jssecacerts
    echo -n "#{node[:rightimage][:euca][:euca_cert]}" > $tmp_creds_dir/euca_cert
    export EUCALYPTUS_CERT=$tmp_creds_dir/euca_cert

    # Load Admin Certs and Creds (loosely based on eucarc file)
    echo -n "#{node[:rightimage][:euca][:x509_key]}" > $tmp_creds_dir/euca_x509_key
    export EC2_PRIVATE_KEY=$tmp_creds_dir/euca_x509_key
    echo -n "#{node[:rightimage][:euca][:x509_cert]}" > $tmp_creds_dir/euca_x509_cert
    export EC2_CERT=$tmp_creds_dir/euca_x509_cert
    export EC2_ACCESS_KEY='#{node[:rightimage][:euca][:access_key_id]}'
    export EC2_SECRET_KEY='#{node[:rightimage][:euca][:secret_access_key]}'
    # This is a bogus value; Eucalyptus does not need this but client tools do.
    export EC2_USER_ID='#{node[:rightimage][:euca][:user_id]}'
    alias ec2-bundle-image="ec2-bundle-image --cert ${EC2_CERT} --privatekey ${EC2_PRIVATE_KEY} --user ${EC2_USER_ID} --ec2cert ${EUCALYPTUS_CERT}"
    alias ec2-upload-bundle="ec2-upload-bundle -a ${EC2_ACCESS_KEY} -s ${EC2_SECRET_KEY} --url ${S3_URL} --ec2cert ${EUCALYPTUS_CERT}"


    # 
    # Upload image. 
    #
    # Force-set bucket name for now since we are limited to the number of buckets created on the cloud.
#    image_bucket=$image_name
    image_bucket="rightscale-rightimages"
    image_name="`md5sum $image_path | awk '{ print $1 }'`-$image_name"

    # Use kernel windows for partitioned images (w-5126)
    echo `euca-bundle-image -i $image_path -p $image_name --kernel windows`
    echo `euca-upload-bundle -b $image_bucket -m /tmp/$image_name.manifest.xml`
    image_out=`euca-register $image_bucket/$image_name.manifest.xml`
    echo $image_out

    # parse out image id to tmp file
    image_id=`echo -n $image_out | awk '{ print $2 }'`
    echo new image id = $image_id
    echo $image_id > /var/tmp/image_id
    
    
    #
    # Remove creds from instance
    #
    rm -rf $tmp_creds_dir

    EOC
  end

  ruby_block "store image id" do
    block do
      image_id = nil
      
      # read id which was written in previous stanza
      ::File.open("/var/tmp/image_id", "r") { |f| image_id = f.read() }
      
      # add to global id store for use by other recipes
      id_list = RightImage::IdList.new(Chef::Log)
      id_list.add(image_id)
    end
  end
end
