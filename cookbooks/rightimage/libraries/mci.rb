module RightImage

  class MCI
      
    # Manage MCIs for images
    #
    # TODO: add the rest of the MCI logic from the right_image_builder project to here
    #
    def initialize(logger = nil)
      @log = (logger) ? logger : Logger.new(STDOUT)
    end    

    # Tags the image with the provides:rs_agent_type=right_link machine tag
    #
    # == Parameters
    # mci(MultiCloudImageInternal):: the MCI to add the tag to
    #
    # == Return
    # true success
    # false failure
    def add_rightlink_tag(mci)
      tag="provides:rs_agent_type=right_link"
      @log.info("Adding tag #{tag} to MCI #{mci.params['name']}")
      add_tag_to_mci(mci, tag)
    end

  protected 

    # Tags the image with a machine tag
    #
    # == Parameters
    # mci(MultiCloudImageInternal):: the MCI to add the tag to
    # tag(String):: the tag to add to the MCI
    #
    # == Return
    # true success
    # false failure
    def add_tag_to_mci(mci, tag)
      begin
        @log.info"Adding tag #{tag} to #{mci.params['name']}"
        href = mci.params['href']
        @log.debug("Adding tag: #{tag} to MCI href: #{href}")
        result = Tag.set(href, ["#{tag}"]) # tag array vs string??
        @log.info("Successfully tagged MCI. Code: #{result.code}")
        true
      rescue Exception => e
        @log.error("ERROR: failed to tag MCI #{mci.params['name']}!  #{e.message}")
        false
      end
    end
   
  end

end

