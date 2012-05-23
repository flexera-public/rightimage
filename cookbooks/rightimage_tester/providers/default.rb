action :test do
  ruby_block "run image test" do
    block do
      # Generic logging function
      def logit(text)
        Chef::Log.info(text)
      end

      logit("\n\nTEST: #{new_resource.name}\nCOMMAND: #{new_resource.command}")
      result = `bash -c '#{new_resource.command}'`
      logit("[RESULT] TEXT: #{result} CODE: #{$?.exitstatus}")
      raise "TEST FAILED" unless ($?.success? && new_resource.fail == true) || new_resource.fail == false

      logit("TEST PASSED")
    end
  end
end
