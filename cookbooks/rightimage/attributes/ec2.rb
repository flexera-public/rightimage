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
      set[:rightimage][:aki_id] = "aki-b6aa75df"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-88aa75e1"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "us-west"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-f57e26b0"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-f77e26b2"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "eu-west" 
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-75665e01"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-71665e05"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "ap-southeast"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-f81354aa"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-fe1354ac"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "ap-northeast"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-42992843"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-44992845"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "us-west-2"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-fa37baca"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-fc37bacc"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "sa-east"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-ca8f51d7"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-c48f51d9"
      set[:rightimage][:ramdisk_id] = nil
    end
  end
  when "ap-southeast-2"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-33990e09"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-31990e0b"
      set[:rightimage][:ramdisk_id] = nil
    end
end # case rightimage[:cloud]
