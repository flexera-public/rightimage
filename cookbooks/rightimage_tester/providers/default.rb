action :test do
  ruby_block "run image test" do
    block do
      # Generic logging function
      def logit(text)
        Chef::Log.info(text)
      end

      logit("TEST: #{new_resource.name}\nCOMMAND: #{new_resource.command}")
      result = `#{new_resource.command}`
      logit("[RESULT] TEXT: #{result} CODE: #{$?.exitstatus}")
logit($?.success?)
logit(new_resource.fail)
logit(new_resource.fail == true)
logit(new_resource.fail == false)
      raise "TEST FAILED" unless ($?.success? && new_resource.fail == true) || new_resource.fail == false

      logit("TEST PASSED")
    end
  end
end
