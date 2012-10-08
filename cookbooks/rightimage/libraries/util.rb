module RightImage
  require 'fileutils'

  class Util
      
    # Truncate contents of all files in these directories.
    DIRS_truncate_logs = [ "/var/log", "/var/mail", "/var/spool/postfix" ]
    # Delete these files and directories
    FILES_delete = [ "/root/.gemrc", "/root/.gem" ]
    # Delete contents of these directories, including deleting subdirectories, but not the directory itself.
    DIRS_clean = ["/mnt", "/tmp", "/var/cache/apt/archives", "/var/cache/yum" ]
    
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
    def sanitize(options = {})
      @log.info("Performing image sanitization routine...")
      skip_files = []
      if options.key?(:skip_files)
        options[:skip_files].each do |f|
          skip_files << ::File.join(@root,f)
        end
      end
      @log.info("Skipping #{skip_files.join(', ')}") unless skip_files.empty?

      DIRS_clean.each do |dir|
        files = ::Dir.glob(::File.join(@root, dir, "**", "*"))
        @log.warn("Contents found in #{dir}!") unless files.empty?
        files.each do |f| 
          next if skip_files.include?(f)
          @log.warn("Deleting #{(::File.directory?(f))?"dir":"file"}: #{f}")
          FileUtils.rm_rf f         
        end
      end
      # On 32 bit apt-get update fails if this directory doesn't exist
      if ::File.directory? "/var/cache/apt/archives"
        FileUtils.mkdir("/var/cache/apt/archives/partial", :mode=>0755)
      end

      DIRS_truncate_logs.each do |dir|
        files = ::Dir.glob(::File.join(@root, dir, "**", "*"))
        files.each do |f|
          next if skip_files.include?(f)
          if ::File.file?(f) && ::File.size?(f)
            @log.warn("Truncating file: #{f}")
            ::File.truncate(f, 0)
          end
        end
      end

      FILES_delete.each do |f|
        filename = ::File.join(@root, f)
        next if skip_files.include?(filename)

        if ::File.directory?(filename)
          @log.warn("Deleting directory tree: #{filename}")
          FileUtils.rm_rf filename
        elsif ::File.file?(filename)
          @log.warn("Deleting file: #{filename}")
          ::File.delete(filename)
        end
      end

      @log.info `sync`
      @log.info("Sanitize complete.")       
    end
   
  end

end

