#!/usr/bin/env ruby

require "rubygems"
require "rest_connection"
require "net/ssh"
require "json"
#require "/var/spool/ec2/meta-data-cache.rb"
require 'erb'
require 'date'
require 'right_aws'
require 'fileutils'
require 'dns'


raise "please pass in a json file to load" unless ARGV[0]

def get_log_name(deployment_name)
  return "cuke_log_#{deployment_name}.log.html"  
end

def get_log_path(deployment_name)
  return "./log/#{get_log_name(deployment_name)}"  
end

def add_server(nickname,deployment,template,image,public_ssh_key_href,security_group,cloud_id,instance_type)
  server = Server.create(:nickname => nickname, \
                         :deployment_href => deployment , \
                         :server_template_href => template , \
                         :ec2_image_href => image , \
                         :ec2_ssh_key_href => public_ssh_key_href , \
                         :cloud_id => cloud_id , \
                         :instance_type => instance_type, \
                         :ec2_security_groups_href => security_group )
  return server
end

def pick_instance_type(instance_types)
  instance_types.each do |type|
    next if @instances_launched.include?(type)
    @instances_launched << type
    return type
  end
  @instances_launched = Array.new
  @instances_launched << instance_types[0]
  return instance_types[0]
end


## parse out static variables
@test_params = JSON.parse File.read(File.join(File.dirname(__FILE__),ARGV[0]))
@deployment_inputs = @test_params["inputs"]
#@deployment_inputs["MASTER_DB_DNSNAME"] = "text:#{ENV['EC2_PUBLIC_HOSTNAME']}"
@servers = @test_params["servers"]
@connect_script = @test_params["connect_script"]
@cuke_tags = @test_params["cuke_tags"]
@instance_types =  @test_params["clouds"]["ec2"]["instance_types"]
@children = Array.new
@instances_launched = Array.new
@tests = Hash.new
@failed_tests = Array.new
@successful_tests = Array.new
@dns_helper = DnsHelper.new if @test_params["dns"] == "true"


## iterate over ec2 regions
@test_params["clouds"]["ec2"]["regions"].each do |region,params|

  ## parse out variables
  public_ssh_key_href = params["ssh_key"]
  security_group = params["security_group"]
  cloud_id = params["cloud_id"]
  server_inputs = @deployment_inputs
  server_inputs = @deployment_inputs.merge(params["inputs"]) if params["inputs"]
  private_ssh_key_path = params["private_key_path"]

  ## iterate over images
  params["images"].each do |image|
    image_href = image["href"]
    arch = image["arch"]
    instance_types = @instance_types[arch]
    deployment_name = "virtual_monkey-#{region}-#{image["name"]}-#{rand(999999999) + 1000000000 }"
    dns_hash = @dns_helper.pop unless @dns_helper.nil?

    child = Process.fork {

      ## create deployment
      deployment = Deployment.create(:nickname => deployment_name)


      ## add servers to deployment
      @servers.each do |server_name,template_href|
        add_server(server_name,deployment.href,template_href,image_href,public_ssh_key_href,security_group,cloud_id,pick_instance_type(instance_types))
      end


      ## if we need to setup dns, merge the values into the inputs
      server_inputs = server_inputs.merge(dns_hash) unless dns_hash.nil?


      ## set deployment inputs
      server_inputs.each do |key,val|
        deployment.set_input(key,val)
      end


      ## run cucumber tests 
      ENV['SSH_KEY_PATH'] = private_ssh_key_path
      ENV['DEPLOYMENT'] = deployment_name
      cmd = "cucumber --format html --guess --tags #{@cuke_tags} ../suite_tests --out #{get_log_path(deployment_name)}"
      p cmd
      result = `#{cmd}`


      if $?.success?
        ## clean up 
        deployment.servers.each { |s| s.reload; s.stop}
        deployment.destroy
      else
        ## for now...
        #deployment.servers.each { |s| s.reload; s.stop}
        #deployment.destroy

        ## leave stranded servers for debugging
        exit 1
      end
    } 
    @children << child
    @tests[child] = deployment_name 
  end
end

puts "waiting for children"

Signal.trap("SIGINT") do
  puts "Caught CTRL-C, killing children.."
  @children.each {|c| Process.kill("INT", c)}
  sleep 1
  @children.each {|c| Process.kill("INT", c)}
end

@children.each do |c| 
  Process.wait(c)
  if $?.success?
    @successful_tests << c
  else
    @failed_tests << c
  end
end

puts "\n\nran #{@children.size.to_i} tests"
puts "#{@failed_tests.size.to_i} failed"
puts "#{@successful_tests.size.to_i} passed"

puts "\n\nthese deployments failed:\n\n"
@failed_tests.each do |t|
  puts "               #{@tests[t]}"
end

puts "\n\nthese deployments passed:\n\n"
@successful_tests.each do |t|
  puts "               #{@tests[t]}"
end
puts "\n"


index = ERB.new  File.read("index.html.erb")

time = Time.now
date = time.strftime("%Y-%m-%d-%H-%M-%S")

num_tests = @children.size.to_i
failed_tests = @failed_tests.size.to_i
successful_tests = @successful_tests.size.to_i


#puts index.result(binding)


File.open("/var/www/index.html", 'w') {|f| f.write(index.result(binding)) }

## upload to s3
bucket_name = "virtual_monkey"
dir = date
s3 = RightAws::S3.new("1EPVFPZVAGMQQ3YDA5G2", "nuSHnVayKx98A6A0z9HLS1Wly9K09F4CHgUaz2Y6")
bucket = s3.bucket(bucket_name)
s3_object = RightAws::S3::Key.create(bucket,"#{dir}/index.html")
#s3_object.data = File.read("/var/www/index.html")
s3_object.put(File.read("/var/www/index.html"),"public-read")

@tests.each do |test,deployment_name|
  FileUtils.cp(get_log_path(deployment_name),"/var/www/#{get_log_name(deployment_name)}")
  s3_object = RightAws::S3::Key.create(bucket,"#{dir}/#{get_log_name(deployment_name)}")
  #s3_object.data = File.read(get_log_path(deployment_name))
  s3_object.put(File.read(get_log_path(deployment_name)),"public-read")
end


puts "\n\nresults avilable at http://s3.amazonaws.com/#{bucket}/#{date}/index.html\n\n"




