module VirtualMonkey
  module Runner
    class Simple
      extend VirtualMonkey::RunnerCore::CommandHooks
      include VirtualMonkey::RunnerCore::DeploymentBase

      description "Simple runner. Helps bring a server to operational"
    end
  end
end
