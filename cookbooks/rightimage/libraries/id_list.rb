module RightImage
  require 'json'
  
  # Manages a global store of image ids for images that have been 
  # on a single rightimage creator instance.
  # The image data is persisted on the local filesystem.
  #
  class IdList
      
    def initialize(logger = nil)
      @log = (logger) ? logger : Logger.new(STDOUT)
      @file = ::File.join(ENV["HOME"], "rightimage_id_list")
    end
    
    # Pass in id that the cloud provider passes back upon registration
    # NOTE: Be sure to set storage type for EC2 "EBS" images so we can 
    # properly know what kind of MCI to make later.
    #
    def add(id, storage_type = nil)
      list_load
      key = id.to_s
      key.chomp!
      @log.info("Adding #{key} to #{(@list) ? 'existing' : 'empty'} id list.")
      entry = { key => { } }
      entry[key]["storage_type"] = storage_type if storage_type
      @list.merge!(entry)
      list_save
    end
    
    # Returns a hash of image ids registered from this instance.
    # The keys are image ids, the values contain metadata 
    # (like "storage_type")
    # Intended to be used in a loop. For Example:
    #   images = RightImage::IdList.new(Chef::Log).to_hash
    #   images.each do |id, params|
    #     ...
    #   end
    #
    def to_hash
      list_load
      @log.info("Loaded #{(@list)?"existing":"empty"} id list.")
      @list
    end
   
    # Wipes out the list by deleting the file.
    #
    def clear
      if ::File.exists?(@file) 
        @log.info("Deleted id list file.")
        ::File.delete(@file)
      end
    end
    
    private
    
    def list_save
      ::File.open(@file, "w") { |f| f.write(@list.to_json) }
    end
    
    def list_load
      @list = { }
      if ::File.exists?(@file)
        json = nil
        ::File.open(@file, "r") { |f| json = f.read() }
        @list = JSON.parse(json) if json
      end
    end
  end
  
end

