# In case it doesn't get set
set_unless[:rightimage][:ec2][:image_type] = "InstanceStore"
set_unless[:rightimage][:aws_access_key_id] = nil
set_unless[:rightimage][:aws_secret_access_key] = nil

# set default EC2 endpoint
case rightimage[:region]
  when "us-east"
    set[:rightimage][:ec2_endpoint] = "https://ec2.us-east-1.amazonaws.com"
  when "us-west"
    set[:rightimage][:ec2_endpoint] = "https://ec2.us-west-1.amazonaws.com"
  when "us-west-2"
    set[:rightimage][:ec2_endpoint] = "https://ec2.us-west-2.amazonaws.com"
  when "eu-west"
    set[:rightimage][:ec2_endpoint] = "https://ec2.eu-west-1.amazonaws.com"
  when "ap-southeast"
    set[:rightimage][:ec2_endpoint] = "https://ec2.ap-southeast-1.amazonaws.com"
  when "ap-southeast-2"
    set[:rightimage][:ec2_endpoint] = "https://ec2.ap-southeast-2.amazonaws.com"
  when "ap-northeast"
    set[:rightimage][:ec2_endpoint] = "https://ec2.ap-northeast-1.amazonaws.com"
  when "sa-east"
    set[:rightimage][:ec2_endpoint] = "https://ec2.sa-east-1.amazonaws.com"
  else
    set[:rightimage][:ec2_endpoint] = "https://ec2.us-east-1.amazonaws.com"
end #if rightimage[:cloud] == "ec2" 

case rightimage[:cloud]
when "ec2"
  # Using pvgrub kernels
  case rightimage[:region]
  when "us-east"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-b2aa75db"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-b4aa75dd"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "us-west"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-e97e26ac"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-eb7e26ae"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "eu-west" 
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-89655dfd"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-8b655dff"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "ap-southeast"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-f41354a6"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-fa1354a8"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "ap-northeast"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-3e99283f"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-40992841"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "us-west-2"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-f637bac6"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-f837bac8"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "sa-east"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-ce8f51d3"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-c88f51d5"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "ap-southeast-2"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-3f990e05"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-3d990e07"
      set[:rightimage][:ramdisk_id] = nil
    end
  end
end # case rightimage[:cloud]
