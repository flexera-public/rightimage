class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

build_root = "/mnt"

target_mnt = "#{build_root}/euca"
tmp_creds_dir = "#{build_root}/euca_upload_creds"

package_root = "#{build_root}/pkg"
package_dir = "#{package_root}/euca"


## copy the generic image 
bash "copy_image" do 
  code <<-EOC
#!/bin/bash  -ex
  set -x
  set -e
  image_name=#{image_name}
  target_mnt=#{target_mnt}
  tmp_creds_dir=#{tmp_creds_dir}
  
  
  # 
  # Get paths to deliverables
  #
  package_dir=#{package_dir}

  image_path=$package_dir/$image_name/$image_name.img
  if [ -a $image_path ]; then 
    echo "Image to upload found: "$image_path
  else
    echo "ERROR: no image found at "$image_path 
    exit 1
  fi
  
  kernel_name=$(ls $package_dir/$image_name/xen-kernel/ | grep vmlinuz | tail -n 1)
  kernel_path=$package_dir/$image_name/xen-kernel/$kernel_name
  if [ -a $kernel_path ]; then 
    echo "Kernel to upload found: "$kernel_path
  else
    echo "ERROR: no kernel found at "$kernel_path 
    exit 1
  fi
  
  ramdisk_name=$(ls $package_dir/$image_name/xen-kernel/ | grep initrd | tail -n 1) 
  ramdisk_path=$package_dir/$image_name/xen-kernel/$ramdisk_name
  if [ -a $ramdisk_path ]; then 
    echo "Ramdisk to upload found: "$ramdisk_path
  else
    echo "ERROR: no ramdisk found at "$ramdisk_path 
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
  mkdir $tmp_creds_dir
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
  # Bundle kernel and ramdisk. Need to do this as the admin user
  #
  kernel_bucket=$image_name
  
  # upload kernel
  echo `euca-bundle-image -i $kernel_path --kernel true`
  echo `euca-upload-bundle -b $kernel_bucket -m /tmp/$kernel_name.manifest.xml`  
  kernel_output=`euca-register $kernel_bucket/$kernel_name.manifest.xml`
  echo $kernel_output
  
  # upload ramdisk
  echo `euca-bundle-image -i $ramdisk_path --ramdisk true`
  echo `euca-upload-bundle -b $kernel_bucket -m /tmp/$ramdisk_name.manifest.xml`  
  ramdisk_output=`euca-register $kernel_bucket/$ramdisk_name.manifest.xml`
  echo $ramdisk_output
    
  ## collect kernel and ramdisk id's
  EKI=`echo -n $kernel_output | awk '{ print $2 }'`
  ERI=`echo -n $ramdisk_output | awk '{ print $2 }'`


  # 
  # Upload image. 
  #
  image_bucket=$image_name

  echo `euca-bundle-image -i $image_path --kernel $EKI --ramdisk $ERI`
  echo `euca-upload-bundle -b $image_bucket -m /tmp/$image_name.img.manifest.xml`
  image_out=`euca-register $image_bucket/$image_name.img.manifest.xml`
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
