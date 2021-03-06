require "hydra-bones/version"
require "hydra-bones/aws"

require 'ostruct' #Syntactic sugar around a hash
require 'optparse' #Options parsing class

module HydraBones
  class Application
    # Run the application
    #
    # == Returns
    # Nothing.
    #
    def self.run

      # Get start time
      start = Time.now

      # Parse command line options.
      options = parse_options(ARGV)

      # Eat First level command and call relevant class
      case ARGV.shift
      when "aws"
        HydraBones::AWSSkeleton::Deployer.run( ARGV )
      when "deb"
        puts "Command not implemented."
      when "um"
        puts "Command not implemented."
      else
        puts "Command not recognized."
      end
    end

    # Parse the ARGV for options
    #
    # == Returns
    # Open struct of options
    #
    def self.parse_options(args)
      #make a structure to hold the options
      options = OpenStruct.new
      options.debug = false

      #setup options parser to fill in the options structure
      opts_parser = OptionParser.new do |opts|
        opts.banner = "Usage: hydra-bones [options] command"
        
        opts.separator("Options are:")
        opts.on_tail("-d", "--debug", "Use debug mode.") do
          options.debug = true
        end

        opts.on_tail("-h", "--help", "Show this message") do
          puts opts
          puts "Commands are:"
          puts ["aws",["  setup","  teardown","  teardown ec2","  bastip"], "deb", "um"]
          exit
        end

        opts.on_tail("--version", "Show version") do
            puts HydraBones::VERSION
            exit
        end      

      end

      # do parsing
      begin
        opts_parser.parse!(args)
      rescue StandardError => se
        abort( "Parsing args error:\n" + se.message)
      end

      # Return options struct
      return options
    end
 

  end
end
