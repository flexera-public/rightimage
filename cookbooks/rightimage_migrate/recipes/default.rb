#
# Cookbook Name:: rightimage_migrate
# Recipe:: default
#
# Copyright 2013, RightScale, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

key = "/tmp/AWS_X509_KEY.pem"
cert = "/tmp/AWS_X509_CERT.pem"

# ec2-api-tools are Java based
bash "install openjdk" do
  flags "-ex"
  code <<-EOH
    case "#{node[:platform]}" in
    "ubuntu")
      apt-get install -y openjdk-6-jre-headless
      echo "export JAVA_HOME=/usr/lib/jvm/java-6-openjdk-amd64/jre" > /etc/profile.d/java.sh
      chmod a+x /etc/profile.d/java.sh
      ;;
    "centos"|"rhel")
      yum install -y java-1.6.0-openjdk
      echo "export JAVA_HOME=/etc/alternatives/jre" > /etc/profile.d/java.sh
      chmod a+x /etc/profile.d/java.sh
      ;;
    esac
  EOH
end

bash "install_ec2_tools" do
  not_if ". /etc/profile && which ec2-describe-images"
  flags "-ex"
  code <<-EOH
    mkdir -p /home/ec2
    curl -o /tmp/ec2-api-tools.zip http://s3.amazonaws.com/ec2-downloads/ec2-api-tools-1.6.13.0.zip
    unzip /tmp/ec2-api-tools.zip -d /tmp/
    cp -r /tmp/ec2-api-tools-*/* /home/ec2/.
    rm -r /tmp/ec2-a*
    echo 'export PATH=/home/ec2/bin:${PATH}' >> /etc/profile.d/ec2.sh
    echo 'export EC2_HOME=/home/ec2' >> /etc/profile.d/ec2.sh
  EOH
end

bash "Store creds" do
  code <<-EOH
    echo "#{node[:rightimage_migrate][:aws_509_key]}" > #{key} 
    echo "#{node[:rightimage_migrate][:aws_509_cert]}" > #{cert} 
  EOH
end

ruby_block "Migrate image" do
  block do
    ENV['EC2_HOME'] = '/home/ec2'

    def get_ami_metadata(akid, sak, region, image_id)
      output = `. /etc/profile && ec2-describe-images --aws-access-key "#{akid}" --aws-secret-key "#{sak}" --region "#{region}" --verbose "#{image_id}" 2>&1`
      if $?.success?
        image_name = /<name>(.*)<\/name>/.match(output)[1]
        imageLocation = /<imageLocation>(.*)\/(.*)<\/imageLocation>/.match(output)
        bucket = imageLocation[1]
        manifest = imageLocation[2]
        image_type = /<rootDeviceType>(.*)<\/rootDeviceType>/.match(output)[1]
        kernel_id = /<kernelId>(.*)<\/kernelId>/.match(output)
        status = /<imageState>(.*)<\/imageState>/.match(output)[1]
        status_reason = /<stateReason>(.*)<\/stateReason>/.match(output)
        error_message = /<message>(.*)<\/message>/.match(output)[1] if status_reason

        data = { "image_name" => image_name, "image_type" => image_type, "manifest" => manifest, "bucket" => bucket, "status" => status }
        data["kernel_id"] = kernel_id[1] if kernel_id
        data
      else
        Chef::Log.info("OUTPUT: #{output}")
        nil
      end
    end

    def get_ami_id(akid, sak, region, image_name, all=false)
      output = `. /etc/profile && ec2-describe-images --aws-access-key "#{akid}" --aws-secret-key "#{sak}" --region "#{region}" #{all ? "--all":"--owner self"} --filter "name=#{image_name}" --verbose  2>&1`
      Chef::Log.info("OUTPUT: #{output}") unless $?.success?
      dupe_id = /<imageId>(.*)<\/imageId>/.match(output)
    
      if dupe_id
        dupe_id[1]
      else
        nil
      end
    end

    akid = node[:rightimage_migrate][:aws_access_key_id]
    sak = node[:rightimage_migrate][:aws_secret_access_key]
    source_region = node[:rightimage_migrate][:source_region]
    destination_bucket = node[:rightimage_migrate][:destination_bucket]
    destination_region = node[:rightimage_migrate][:destination_region]
    	
    if node[:rightimage_migrate][:source_image] =~ /^ami-/
      image_id = node[:rightimage_migrate][:source_image]
    else
      image_id = get_ami_id(akid, sak, source_region, node[:rightimage_migrate][:source_image])
      raise "Could not find image #{node[:rightimage_migrate][:source_image]} for region #{source_region}" unless image_id
    end

    Chef::Log.info("Getting image metadata")
    source_image = get_ami_metadata(akid, sak, source_region, image_id)

    raise "Could not find AMI #{image_id} for region #{source_region}" unless source_image
    
    if source_image['image_type'] == "instance-store" 
      raise "Destination bucket must be specified for instance store based images" unless destination_bucket
      raise "AWS x509 Certificate must be supplied for instance store based images" unless node[:rightimage_migrate][:aws_509_cert]
      raise "AWS x509 Key must be supplied for instance store based images" unless node[:rightimage_migrate][:aws_509_key]
    end

    Chef::Log.info("Checking destination region for duplicate image")
    image_check = get_ami_id(akid, sak, destination_region, source_image['image_name'])
    if image_check 
      Chef::Log.warn("Image has already been migrated as #{image_check}, proceeding as normal")
      new_image_id = image_check
    else
      if source_image['kernel_id']
        Chef::Log.info("Checking for matching kernel in #{destination_region}")
        # Get metadata for source image's aki
        source_aki = get_ami_metadata(akid, sak, source_region, source_image['kernel_id'])
        # aki name
        source_aki_name = source_aki['image_name']
        # Search all images in destination region for source aki name
        destination_aki = get_ami_id(akid, sak, destination_region, source_aki_name, true)
        raise "Could not find AKI #{source_aki_name} in #{destination_region}" unless destination_aki
        kernel_flag = "--kernel \"#{destination_aki}\""
      else
        kernel_flag = ""
      end

      Chef::Log.info("Migrating #{image_id} from #{source_region} to #{destination_region}")
      case source_image['image_type']
      when "ebs"
        output = `. /etc/profile && ec2-copy-image --aws-access-key "#{akid}" --aws-secret-key "#{sak}" --source-region "#{source_region}" --source-ami-id "#{image_id}" --region "#{destination_region}"  2>&1`
      when "instance-store"
        output = `. /etc/profile && ec2-migrate-image --private-key "#{key}" --cert "#{cert}" --owner-akid "#{akid}" --owner-sak "#{sak}" --bucket "#{source_image['bucket']}" --destination-bucket "#{destination_bucket}" --manifest "#{source_image['manifest']}" --acl "aws-exec-read" --region "#{destination_region}"  2>&1`
        Chef::Log.info(output)
        raise "ec2-migrate-image failed" unless $?.success?
      
        Chef::Log.info("Registering image")
        output = `. /etc/profile && ec2-register "#{destination_bucket}/#{source_image['manifest']}" --aws-access-key "#{akid}" --aws-secret-key "#{sak}" --name "#{source_image['image_name']}" #{kernel_flag} --region "#{destination_region}"  2>&1`
      else
        raise "Root device type #{source_image['image_type']} not supported"
      end
      Chef::Log.info(output)
      	
      raise "Migration failed" unless $?.success?
  	
      new_image_id = output.split[1]

      if source_image['image_type'] == "ebs"
        Chef::Log.info("Waiting for image #{new_image_id} to appear available")
        # It will take at least 5 minutes for the new image to be ready.
        sleep 300
        
        $i=0
        $retries=60
        $wait=30
        
        status = "unknown"

        until $i > $retries do
          # Check status of new image.
          destination_image = get_ami_metadata(akid, sak, destination_region, new_image_id)
          status = "unknown"
          if destination_image
            status = destination_image['status']
          end

          case status
          when "available"
            Chef::Log.info("Image #{new_image_id} is available")
            break
          when "failed"
            raise "Image status is failed. Reason: #{destination_image['error_message']}"
          else
            $i += 1;
            Chef::Log.info("[#$i/#$retries] Image NOT ready! Status: #{status} Sleeping #$wait seconds...")
            sleep $wait unless $i > $retries
          end
        end
    
        raise "Image still not available! Giving up! Status: #{status}" unless status == "available"
      end
    end

    image_type = source_image['image_type'] == "ebs" ? "EBS" : nil
    id_list = RightImage::IdList.new(Chef::Log)
    id_list.add(new_image_id, image_type)
  end
end
