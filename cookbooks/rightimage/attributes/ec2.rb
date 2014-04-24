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
  when "us-east" #US-East
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = ""
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-919dcaf8"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "us-west" #US-West
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = ""
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-880531cd"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "eu-west" #EU
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = ""
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-52a34525"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "ap-southeast" #AP-Singapore
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = ""
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-503e7402"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "ap-northeast" #AP-Tokyo
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = ""
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-176bf516"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "us-west-2"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = ""
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-fc8f11cc"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "sa-east" #SA-Sao Paulo
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = ""
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-5553f448"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "ap-southeast-2" #AP-Sydney
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = ""
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-c362fff9"
      set[:rightimage][:ramdisk_id] = nil
    end
  end
end # case rightimage[:cloud]
