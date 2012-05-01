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
      set[:rightimage][:aki_id] = "aki-805ea7e9"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-825ea7eb"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "us-west"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-83396bc6"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-8d396bc8"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "eu-west" 
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-64695810"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-62695816"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "ap-southeast"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-a4225af6"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-aa225af8"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "ap-northeast"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-ec5df7ed"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-ee5df7ef"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "us-west-2"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-c2e26ff2"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-98e26fa8"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "sa-east"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-bc3ce3a1"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-cc3ce3d1"
      set[:rightimage][:ramdisk_id] = nil
    end
  end
end # case rightimage[:cloud]
