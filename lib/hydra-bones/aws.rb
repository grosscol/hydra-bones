require "hydra-bones/aws/vpc_maker"

module HydraBones
  module AWSSkeleton

    class Deployer

      def self.run( cmd )
        case cmd.shift
        when "setup"
          puts "Setting up virtual private cloud."
          begin
             HydraBones::AWSSkeleton::VPCMaker.setup_new_vpc
          rescue HydraBones::AWSSkeleton::VPCExistsError
            puts "VPC alreadys exists.  Assuming it's set up correctly."
          end

          puts "Setting up instances and routing."
          HydraBones::AWSSkeleton::VPCMaker.fill_in_vpc

        when "teardown"
          if cmd.shift == "ec2"
            puts "Tearing down AWS instances only."
            HydraBones::AWSSkeleton::VPCMaker.unfill_vpc
          else
            puts "Tearing down AWS instances and vpc."
            HydraBones::AWSSkeleton::VPCMaker.kill_vpc
          end

        when "bastip"
          puts HydraBones::AWSSkeleton::VPCMaker.bastion_ip

        else
          puts "Command not recognized."
        end
      end

    end

  end
end

