require 'rubygems'
require 'bundler/setup'

require 'time'
require 'json'


# The top of the repository checkout
TOP_DIR    = File.expand_path(File.join(File.dirname(__FILE__), "."))
MONKEY_DIR = TOP_DIR + "/virtualmonkey2"
RIGHTIMAGE_AUTOMATION_DIR = TOP_DIR + "/automation"
COOKBOOKS_DIR     = TOP_DIR + "/cookbooks"

def cmd(cmd, echo = true)
  puts cmd
  output = ""
  STDOUT.sync = true
  unless ENV['dryrun'].to_s =~ /./
    Bundler.with_clean_env do 
      IO.popen cmd do |f|
        f.sync = true
        until f.eof?
          line = f.gets
          output << line
          puts "+ #{line}" if echo
        end
      end
    end
      raise "Command failed" unless $?.success?
  end
  output
end

def upload_cookbooks()
  raise "Ruby version 1.9 or greater is required" unless RUBY_VERSION.to_s >= "1.9.0"

  rightimage_dir = "#{COOKBOOKS_DIR}/rightimage"
  upload_url = ""
  Dir.chdir rightimage_dir do
    puts "cd #{rightimage_dir}"

    cmd("bundle check || bundle install")

    upload_config = File.expand_path("~/.rightscale_upload.json")
    unless ::File.exists? upload_config
      raise "No upload config found at #{upload_config}"
    end
    config = JSON.parse(File.read(upload_config))
    puts "Uploading rightimage cookbooks to #{config['container']}"
    output = cmd("bundle exec rightscale_upload berkshelf upload --force 2>&1", echo=false)

    upload_url = /Uploaded to: (.*)$/.match(output)[1]
    return upload_url
  end
end

def sts_for_lineage(servertemplate_lineage)
  lineages = {
    "v14" => {
      :st_id => "263828001",
      :repo_id => "241244004"
    },
    "v14.0.1" => {
      :st_id => "340232004",
      :repo_id => "241721004"
    },
    "peter" => {
      :st_id => "316429001",
      :repo_id => "222947001"
    }
  }
  unless ids = lineages[servertemplate_lineage]
    raise "A valid servertemplate lineage was not supplied, must be one of: #{lineages.keys.join(", ")}"
  end
  [ids[:st_id], ids[:repo_id]]
end

def attach_cookbooks(servertemplate_lineage, source_url)
  Dir.chdir RIGHTIMAGE_AUTOMATION_DIR do
    puts "cd #{RIGHTIMAGE_AUTOMATION_DIR}"
    st_id, repo_id = sts_for_lineage(servertemplate_lineage)

    src_url_arg = ""
    if source_url
      src_url_arg = "-u #{source_url}"
      puts "Attaching cookbooks from Repository #{repo_id} to ServerTemplate #{st_id} with Source #{source_url}"
    else
      raise "An S3 source tarball for the repository was not supplied. Running upload_cookbooks rake task should generate this for you."
    end

    cmd("bundle check || bundle install")
    cmd("bundle exec repo_refetch -s #{st_id} -r #{repo_id} #{src_url_arg}")
  end
end


desc "Upload rightimage cookbooks to s3"
task :upload_cookbooks do |t, args|
  upload_url = upload_cookbooks()
  puts "Uploaded to #{upload_url}"
end

desc "Attach cookbooks to ServerTemplate"
task :attach_cookbooks, [:servertemplate_lineage, :s3_url]  do |t, args|
  attach_cookbooks(args[:servertemplate_lineage], args[:s3_url])
end


# Default image_tester template - right_image_tester master normally
# override
desc "Run RightImage base builders"
task :base_build, [:servertemplate_lineage, :mirror_freeze_date] do |t, args|
  upload_url = upload_cookbooks()
  attach_cookbooks(args[:servertemplate_lineage], upload_url)

  Dir.chdir RIGHTIMAGE_AUTOMATION_DIR do
    puts "cd #{RIGHTIMAGE_AUTOMATION_DIR}"
    current_sha = `git log --pretty=format:'%H' -n 1`.chomp[0..7]

    servertemplate_lineage = args[:servertemplate_lineage]
    st_id, repo_id = sts_for_lineage(args[:servertemplate_lineage])
    lineage = servertemplate_lineage.sub("v","").split(".").first


    cmd("bundle check || bundle install")
    # Destroy on startup. Servers should be stopped at the end of a the run, though the deployment will
    # linger for debugging purposes
    command = "bundle exec generate_ci_collateral base  --build_id #{servertemplate_lineage}-#{current_sha} --lineage v#{lineage} --servertemplate_id #{st_id}"
    command << " --mirror_freeze_date #{args[:mirror_freeze_date]}" if args[:mirror_freeze_date]
    output = cmd(command, echo=false)
    ci_collateral_file = /Writing base template to (.*)$/.match(output)[1]
    ci_log_file = ci_collateral_file.sub(".yml",".log")
    cmd("bundle exec image_builder --restart #{ci_collateral_file} --log-file #{ci_log_file} --yes")
  end
end

def get_last_base_build
  RightimageTools
end

desc "Run RightImage CI full builders"
task :full_build, [:servertemplate_lineage, :rightlink_version] do |t, args|
  upload_url = upload_cookbooks()
  attach_cookbooks(args[:servertemplate_lineage], upload_url)

  Dir.chdir RIGHTIMAGE_AUTOMATION_DIR do
    puts "cd #{RIGHTIMAGE_AUTOMATION_DIR}"
    current_sha = `git log --pretty=format:'%H' -n 1`.chomp[0..7]

    servertemplate_lineage = args[:servertemplate_lineage]
    st_id, repo_id = sts_for_lineage(args[:servertemplate_lineage])
    lineage = servertemplate_lineage.sub("v","").split(".").first
    rightlink_version = args[:rightlink_version]

    build_id, mirror_freeze_date = get_last_base_build

    # To make each build unique, mark it with the latest commit timestamp
    # Bump to current timestamp if change are unchecked in?
    timestamp = `git log -1 --pretty=%ci`
    time = Time.parse(timestamp).utc
    build_version = "#{servertemplate_lineage}.#{time.strftime("%Y%m%d%H%M")}"


    cmd("bundle check || bundle install")
    # Destroy on startup. Servers should be stopped at the end of a the run, though the deployment will
    # linger for debugging purposes
    output = cmd("bundle exec generate_ci_collateral full --rightlink_version #{rightlink_version} --build_id #{build_id} --mirror_freeze_date #{mirror_freeze_date} --image_version #{build_version} --servertemplate_id #{st_id}")
    ci_collateral_file = /Writing full template to (.*)$/.match(output)[1]
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
