class CukeMonk
  # what we want is a class that helps us run cuke tests
  #
  # this class should:
  #  - have the ability to run in user mode or batch mode
  #    - user mode
  #      - run one test
  #      - allow user to tail the results
  #      - have a notification when the task is complete
  #    - batch mode
  #      - run a set of tests
  #      - aggreate the results and push to s3 and send email
  #
  #
  # to achive this, we need to expose:
  #  - run user test(feature)
  #    - returns handle to tail file
  #  - run batch test(features)
  #    - returns nothing
  #
  # on init we need to:
  #  - get a path to look for features
  
  REPORT_DIR = "log"
  LOG_DIR = "/tmp/vmonk"

  attr_accessor :feature_tag, :feature_tag_path

  def initialize()
    @jobs = []
    @feature_tag = feature_tag
    @feature_tag_path = feature_tag_path
    @threads = []
    Dir.mkdir LOG_DIR unless File.directory? LOG_DIR
  end
 
  def CukeMonk.finalize(id)
    self.join(@threads)
  end


  def run_test(deployment,cmd,format=nil)
    Kernel.exit 1 if deployment.nil?  || cmd.nil? 
    cmd = "cucumber #{cmd} --format html"
    execute_cuke_cmd(cmd,deployment) 
  end

  
  def run_tests(deployments,cmd,format=nil)
    Kernel.exit 1 if deployments.nil?  || cmd.nil? 
    jobs = []
    deployments.each { |d| jobs << run_test(d,cmd,"html") }
    jobs
  end

  def join(threads)
    threads.each { |t|   t.join }
  end

  def generate_reports(jobs=@jobs)
    #puts "jobs is nil in generate_reports method" && Kernel.exit 1 if jobs.nil? 
    jobs.each { |j| j[0].join }

    require 'rubygems'
    require 'erb'
    require 'right_aws'
    index = ERB.new  File.read(File.dirname(__FILE__)+"/index.html.erb")
    time = Time.now
    date = time.strftime("%Y-%m-%d-%H-%M-%S")

    num_tests = jobs.size
    failed_tests = jobs.select{|j|!j[2][0]}.size
    successful_tests = jobs.select{|j|j[2][0]}.size

    bucket_name = "virtual_monkey"
    dir = date

    ## Log a local copy of the results
    FileUtils.mkdir_p(File.join("log",dir))
    File.open(File.join("log",dir,"index.html"), 'w') {|f| f.write(index.result(binding)) }
    jobs.each do |j|
      File.open(File.join("log",dir,"#{j[4]}.html"), "w") {|f| f.write(j[3][0])}
    end 

    ## upload to s3
    s3 = RightAws::S3.new("@@AWS_ACCESS_KEY_ID@@", "@@AWS_SECRET_ACCESS_KEY@@")
    bucket = s3.bucket(bucket_name)
    s3_object = RightAws::S3::Key.create(bucket,"#{dir}/index.html")
    s3_object.put(index.result(binding),"public-read")
    
    jobs.each do |j|
      s3_object = RightAws::S3::Key.create(bucket,"#{dir}/#{j[4]}.html")
      s3_object.put(j[3][0],"public-read")
    end
    
    msg = <<END_OF_MESSAGE
    ran #{num_tests} jobs
    #{failed_tests} tests failed
    #{successful_tests} tests passed

    results avilable at http://s3.amazonaws.com/#{bucket}/#{date}/index.html
END_OF_MESSAGE
    puts msg
    File.open("#{LOG_DIR}/#{bucket}-#{date}.log", "w") { |f| f.puts msg }
    return msg
  end


  private 

  
  def execute_cuke_cmd(cmd,deployment)
    Kernel.exit 1 if cmd.nil? 
    # common variables that we want to share with the thread
    *stream_ptr = ""
    *success_ptr = false
    # set environments 
    ENV['DEPLOYMENT']=deployment
    # fork thread
    thread = Thread.fork {
      IO.popen(cmd) { |trickle|
        until trickle.eof?
          thread_out = trickle.gets
          File.open("#{LOG_DIR}/#{deployment}.out","a") { |f| f.puts(thread_out) }
          stream_ptr[0] += thread_out
        end
      }

      #success = ($?.success? && true ) || false
      success_ptr[0] = $?.success?
    }
    @threads << thread

    job = [thread,cmd,success_ptr,stream_ptr,deployment]
    @jobs << job
    job
  end


  def puts_results_to_s3()

  end


end

