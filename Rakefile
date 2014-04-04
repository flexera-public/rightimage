require 'rubygems'
require 'time'
require 'json'


# The top of the repository checkout
TOP_DIR    = File.expand_path(File.join(File.dirname(__FILE__), "."))
MONKEY_DIR = TOP_DIR + "/virtualmonkey2"
BASE_AUTOMATION_DIR = TOP_DIR + "/automation"
COOKBOOKS_DIR     = TOP_DIR + "/cookbooks"

def cmd(cmd)
  puts cmd
  STDOUT.sync = true
  output = ""
  unless ENV['dryrun'].to_s =~ /./
    IO.popen cmd do |f|
      until f.eof?
        output << f.gets
        puts f.gets
      end
    end
    raise "Command failed" unless $?.success?
  end
  output
end


LINEAGES = {
  "14" => {
    :st_id => "263828001",
    :repo_id => "241244004"
  }
}

desc "Upload rightimage cookbooks to s3"
task :upload_cookbooks, [:image_version]  do |t, args|
  rightimage_dir = "#{COOKBOOKS_DIR}/rightimage"
  upload_url = ""
  Dir.chdir rightimage_dir do
    puts "cd #{rightimage_dir}"

    image_version = args[:image_version]
    raise "Image version must be in format vN.N, i.e. v14.0" unless image_version =~ /^v\d+\.\d+$/
    lineage = image_version.sub("v","").split(".").first
    unless ids = LINEAGES[lineage]
      raise "Valid lineage not supplied, #{LINEAGES.keys.join(", ")} are supported"
    end

    cmd("bundle check || bundle install")
    upload_config = File.expand_path("~/.rightscale_upload.json")
    unless ::File.exists? upload_config
      raise "No rightscale_upload config at #{upload_config}"
    end
    config = JSON.parse(File.read(upload_config))
    puts "Uploading rightimage cookbooks to #{config['container']}"
    output = cmd("bundle exec rightscale_upload berkshelf upload --force 2>&1")
    upload_url = /Uploaded to: (.*)$/.match(output)[1]
    puts "Uploaded to #{upload_url}"
  end
end

# Default image_tester template - right_image_tester master normally
# override
desc "Run RightImage base builders in EC2"
task :base_build, [:image_version] do |t, args|
  Dir.chdir BASE_AUTOMATION_DIR do
    puts "cd #{BASE_AUTOMATION_DIR}"
    current_sha = `git log --pretty=format:'%H' -n 1`.chomp[0..7]

    image_version = args[:image_version]
    raise "Image version must be in format vN.N, i.e. v14.0" unless image_version =~ /^v\d+\.\d+$/
    lineage = image_version.sub("v","").split(".").first
    unless ids = LINEAGES[lineage]
      raise "Valid lineage not supplied, #{LINEAGES.keys.join(", ")} are supported"
    end

    cmd("bundle check || bundle install")
    # Destroy on startup. Servers should be stopped at the end of a the run, though the deployment will
    # linger for debugging purposes
    output = cmd("bundle exec generate_ci_collateral base --build_id #{image_version}-#{current_sha} --lineage v#{lineage} --servertemplate_id #{ids[:st_id]}")
    ci_collateral_file = /Writing base template to (.*)$/.match(output)[1]
    cmd("bundle exec image_builder --restart #{ci_collateral_file} --yes")
  end
end

# Default image_tester template - right_image_tester master normally
# override
desc "Run image tester against server_template."
task :integration_test do |t, args|
  Dir.chdir MONKEY_DIR do
    default_st = "v14"
    st_name = ENV['st']
    if st_name.to_s =~ /./
      if !::File.exists?("config/#{st_name}.json")
        raise "Custom servertemplate config/#{st_name}.json doesn't exist, please create it first"
      end
      st_conf = "config/#{st_name}.json"
    else
      puts "Using default servertemplate (config/#{default_st}.json)"
      st_conf = "config/#{default_st}.json"
    end

    mci = ENV['mci']
    if mci.to_s =~ /./
      unless mci =~ /@/
        mci += "@0"
      end
      puts "Using mci override '#{mci}'"
      mci = "-m #{mci}"
    else
      puts "Using mcis attached to servertemplate"
      mci = ""
    end

    cloud_ids = ENV['cloud_ids']
    if cloud_ids.to_s =~ /./
      puts "Using only cloud_ids '#{cloud_ids}'"
      cloud_ids = "-i #{cloud_ids}"
    else
      cloud_ids = ""
      puts "Using all clouds attached to servertemplate"
    end

    restrict_clouds = ""

    test_conf  = "suites/image_tester.json"

    cmd("bundle check || bundle install")
    # Destroy on startup. Servers should be stopped at the end of a the run, though the deployment will
    # linger for debugging purposes
    cmd("bundle exec monkey destroy --yes -s #{test_conf} -p #{st_conf}")
    cmd("bundle exec monkey create        -s #{test_conf} -p #{st_conf} #{cloud_ids} #{mci} --one-deploy")
    cmd("bundle exec monkey run           -s #{test_conf} -p #{st_conf}")
  end
end
