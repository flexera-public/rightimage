module RightImage
  require 'fileutils'

  class Util
      
    # Delete contents of these directories, including deleting subdirectories, but not the directory itself.
    DIRS_delete = [ "/mnt", "/tmp", "/var/cache/apt/archives", "/var/cache/yum" ]
    # Delete entire directory tree including the directory itself.
    DIRS_delete_tree = [ "/root/.gem" ]
    # Truncate contents of all files in these directories.
    DIRS_truncate = [ "/var/log", "/var/mail", "/var/spool/postfix" ]
    # Delete these files.
    FILES_delete = [ "/root/.gemrc" ]
    
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
      DIRS_delete_tree.each do |dir|
        directory = ::File.join(@root, dir)

        if ::File.directory?(directory)
          @log.warn("Deleting directory tree: #{directory}")
          FileUtils.rm_rf directory
        end
      end

      DIRS_delete.each do |dir|
        files = ::Dir.glob(::File.join(@root, dir, "**", "*"))
        @log.warn("Contents found in #{dir}!") unless files.empty?
        files.each do |f| 
          @log.warn("Deleting #{(::File.directory?(f))?"dir":"file"}: #{f}")
          FileUtils.rm_rf f         
        end
      end

      DIRS_truncate.each do |dir|
        files = ::Dir.glob(::File.join(@root, dir, "**", "*"))
        files.each do |f|
          if ::File.file?(f) && ::File.size?(f)
            @log.warn("Truncating file: #{f}")
            ::File.truncate(f, 0)
          end
        end
      end

      FILES_delete.each do |f|
        filename = ::File.join(@root, f)

        if ::File.file?(filename)
          @log.warn("Deleting file: #{filename}")
          ::File.delete(filename)
        end
      end

      @log.info("Synching filesystem.")
      @log.info `sync`
      @log.info("Sanitize complete.")       
    end
   
  end

end

