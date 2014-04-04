require 'rubygems'
require 'json'


# The top of the repository checkout
TOP_DIR    = File.expand_path(File.join(File.dirname(__FILE__), "."))
MONKEY_DIR = TOP_DIR + "/virtualmonkey2"

def cmd(cmd)
  puts cmd
  STDOUT.sync = true
  unless ENV['dryrun'].to_s =~ /./
    IO.popen cmd do |f|
      until f.eof?
        puts f.gets
      end
    end
    raise "Command failed" unless $?.success?
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
