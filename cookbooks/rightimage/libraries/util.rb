module RightImage
  require 'fileutils'

  class Util
      
    DIRS = [ "/mnt", "/tmp", "/var/cache/yum" ]
    
    # Utility Class
    #
    # === Parameter
    # root_dir(File.path):: Root path of the image to be created    
    def initialize(root_dir, logger = nil)
      @log = (logger) ? logger : Logger.new(STDOUT)
      raise "ERROR: root_path must be a string" unless root_dir.is_a?(String)
      raise "ERROR: root_dir of `#{root_dir}` not found!" unless ::File.directory?(root_dir)
      @root = root_dir
    end
    
    # Cleaning up image
    #
    def sanitize()
      @log.info("Performing image sanitization routine...")
      DIRS.each do |dir|
        files = ::Dir.glob(::File.join(@root, dir, "**", "*"))
        @log.warn("Contents found in #{dir}!") unless files.empty?
        files.each do |f| 
          @log.warn("Deleting #{(::File.directory?(f))?"dir":"file"}: #{f}")
          FileUtils.rm_rf f         
        end
      end
      @log.info("Synching filesystem.")
      @log.info `sync`
      @log.info("Sanitize complete.")       
    end
   
  end

end

