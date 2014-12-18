require 'aws-sdk'

module HydraBones
  module AWSSkeleton

    class VPCExistsError < StandardError
    end
    class MissingResourceError < StandardError
    end

    class VPCMaker

      VPC_CIDR = "172.10.0.0/16"
      VPC_NAME  = "hydra-vpc"
      PUB_CIDR = "172.10.1.0/24"
      PRV_CIDR = "172.10.10.0/24"
      BAST_NAME = "hydra-bastion"
      NAT_NAME  = "hydra-nat"

      DEB_IMG_NAME = "debian-wheezy-amd64-hvm-2014-10-18-ebs"
      AMZ_IMG_NAME = "amzn-ami-hvm-2014.09.1.x86_64-ebs"

      # Preconfigured images stored in S3
      FED_IMG_S3 = ""
      WEB_IMG_S3 = ""

      # Alias curl-check for quick checks of http response codes.
      # Add hostname to /etc/hosts so sudo doesn't emit warnings.
      FED_USR_DATA = "#!/bin/sh
alias curl-check=\"curl --write-out '%{http_code}\n' -s -o /dev/null\"
echo \"127.0.0.1\t$HOSTNAME\" | tee --append /etc/hosts"
      WEB_USR_DATA = "" 
      NAT_USR_DATA = "#!/bin/sh
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 0 > /proc/sys/net/ipv4/conf/eth0/send_redirects
/sbin/iptables -t nat -A POSTROUTING -o eth0 -s 0.0.0.0/0 -j MASQUERADE
/sbin/iptables-save > /etc/sysconfig/iptables
mkdir -p /etc/sysctl.d/
cat <<EOF > /etc/sysctl.d/nat.conf
net.ipv4.ip_forward = 1
net.ipv4.conf.eth0.send_redirects = 0
EOF
"

      # Allocate vpc and resources that can be resolved without ec2 instances
      #
      # == Returns
      # Nothing.
      #
      def self.setup_new_vpc
        # Create new vpc or die
        vpc = create_vpc

        # Give vpc time to become available
        for i in 0..5 do
          break if vpc.state == :available 
          puts "waiting for vpc to become available"
          sleep 5
        end

        # AWS EC2 instance and client
        ec2 = AWS::EC2.new

        # Create DHCP options for VPC and associate them
        #   These will need to change with region
        dopts = ec2.dhcp_options.create({
          :domain_name => "ec2.internal",
          :domain_name_servers => "AmazonProvidedDNS"
        })
        dopts.tag("Name",:value => "hydra-dhcp")
        dopts.associate(vpc.id)
        
        # Create subnets
        subnets = AWS::EC2.new.vpcs[vpc.id].subnets

        pubnet = subnets.create PUB_CIDR 
        prvnet = subnets.create PRV_CIDR

        pubnet.tag("Name", :value => "pubnet")
        prvnet.tag("Name", :value => "prvnet")

        # debug print subnet names
        subnets.each{ |s| printf("%-35s %-35s\n", s.id, s.tags["Name"]) }

        # Create internet gateway
        igs = ec2.internet_gateways
        ig = igs.create
        ig.tag("Name", :value => "hydra-gateway")
        ig.attach vpc.id 

        # Create route for public subnet
        rts = ec2.route_tables
        rt_pub = rts.create( :vpc => vpc.id )
        rt_pub.create_route("0.0.0.0/0", :internet_gateway => ig.id)
        rt_pub.tag("Name", :value => "pubroute")

        # Associate route with public subnet
        pubnet.set_route_table rt_pub

        # Create security groups
        sgs = ec2.security_groups
        sg_bast = sgs.create( "bast_sec", {:vpc => vpc.id, :description => "bastion host ssh only"})
        sg_nat  = sgs.create( "nat_sec",  {:vpc => vpc.id, :description => "nat host security"})
        sg_web  = sgs.create( "web_sec",  {:vpc => vpc.id, :description => "web host security"})
        sg_back = sgs.create( "back_sec", {:vpc => vpc.id, :description => "back end host security"})

        # Allow ping for web and backend from within VPC
        sg_web.allow_ping( VPC_CIDR )
        sg_back.allow_ping( VPC_CIDR )

        # Add ingress/egress rules to security groups 
        # bastion gets ssh to and from everywhere.
        sg_bast.authorize_ingress(:tcp, 22, "0.0.0.0/0")
        sg_bast.authorize_egress("0.0.0.0/0", :protocol => :tcp, :ports => 22 )

        # All other groups only get ssh to/from bastion
        [sg_nat,sg_web,sg_back].each{ |g| g.authorize_ingress(:tcp, 22, sg_bast) }
        [sg_nat,sg_web,sg_back].each{ |g| g.authorize_egress(sg_bast, :protocol => :tcp, :ports => 22 ) }

        # Back end hosts allow http traffic out to anywhere, but only in from nat
        sg_back.authorize_ingress(:tcp, 80, sg_nat)
        sg_back.authorize_egress("0.0.0.0/0", :protocol => :tcp, :ports => 80 )
        sg_back.authorize_ingress(:tcp, 443, sg_nat)
        sg_back.authorize_egress("0.0.0.0/0", :protocol => :tcp, :ports => 443 )

        # Nat allows http traffic inbound and outbound from anywhere
        sg_nat.authorize_ingress(:tcp, 80, "0.0.0.0/0")
        sg_nat.authorize_egress("0.0.0.0/0", :protocol => :tcp, :ports => 80 )
        sg_nat.authorize_ingress(:tcp, 443, "0.0.0.0/0")
        sg_nat.authorize_egress("0.0.0.0/0", :protocol => :tcp, :ports => 443 )
        
        # Create IAM roles
        # punt
        
        # debug
        puts "End of initial vpc setup."

      end

      # Allocate ec2 instances and related resources
      # 
      # == Returns
      # Nothing.
      #
      def self.fill_in_vpc
        ec2 = AWS::EC2.new

        # Get VPC
        vpc = ec2.vpcs.with_tag( "Name", [VPC_NAME]).first
        if vpc.nil?
          raise MissingResourceError.new("VPC with name #{VPC_NAME} not found.  Unable to fill.")
        end

        # Check for ssh keys or die.
        # Expect ssh keys to be in $HOME/.ssh
        bast_key_path = File.join(ENV["HOME"], ".ssh", "bast_key.pem")
        hydra_key_path = File.join(ENV["HOME"], ".ssh", "hydra_key.pem")

        if !File.exist?(bast_key_path) || !File.exist?(hydra_key_path)
          raise MissingResourceError.new("Missing private key file in #{File.join(ENV["HOME"],".ssh")}.")
        end

        bast_key = ec2.key_pairs["bast_key"]
        hydra_key = ec2.key_pairs["hydra_key"]

        if bast_key.nil? 
          raise MissingResourceError.new("AWS account missing public key for: bast_key")
        end
        if hydra_key.nil?
          raise MissingResourceError.new("AWS account missing public key for: hydra_key")
        end

        # Get amazon machine images
        amz_linux_ami = ec2.images.filter("name", AMZ_IMG_NAME).first
        deb_linux_ami = ec2.images.filter("name", DEB_IMG_NAME).first

        if amz_linux_ami.nil? || deb_linux_ami.nil?
          raise MissingResourceError.new("Unable to find images for #{AMZ_IMG_NAME} or #{DEB_IMG_NAME}")
        end

        # Get public and private subnets
        pubnet = vpc.subnets.with_tag("Name", ["pubnet"]).first
        prvnet = vpc.subnets.with_tag("Name", ["prvnet"]).first

        if pubnet.nil? || prvnet.nil?
          raise MissingResourceError.new("Unable to find subnets.")
        end

        # Get security groups
        bast_sec = vpc.security_groups.filter('group-name', 'bast_sec').first
        nat_sec = vpc.security_groups.filter('group-name', 'nat_sec').first
        back_sec = vpc.security_groups.filter('group-name', 'back_sec').first

        
        if bast_sec.nil? 
          raise MissingResourceError.new("Unable to find security group bast_sec")
        end

        # Create bastion host
        bast = vpc.instances.create({
          :image_id => amz_linux_ami.id,
          :instance_type => "t2.micro",
          :block_device_mappings => [{
            :device_name => "/dev/xvda",
            :ebs => {
              :volume_size => 8,
              :delete_on_termination => true
              }
            }],
          :subnet => pubnet.id,
          :key_name => bast_key.name,
          :security_groups => [bast_sec],
          :count => 1
        })
        bast.tag("Name", :value => "bastion-host")
        
        # Create nat host
        nat = vpc.instances.create({
          :image_id => amz_linux_ami.id,
          :instance_type => "t2.micro",
          :block_device_mappings => [{
            :device_name => "/dev/xvda",
            :ebs => {
              :volume_size => 8,
              :delete_on_termination => true
              }
            }],
          :subnet => pubnet.id,
          :key_name => hydra_key.name,
          :security_groups => [nat_sec],
          :count => 1,
          :user_data => NAT_USR_DATA
        })
        nat.tag("Name", :value => "nat-host")

        # Poll for nat and bastion host to be running
        loop do
          break if nat.status == :running && bast.status == :running
          sleep 13
        end

        # Create route for private subnet through nat instance
        rt_prv = ec2.route_tables.create({:vpc => vpc.id})
        rt_prv.create_route("0.0.0.0/0", {:instance => nat.id})
        prvnet.set_route_table( rt_prv.id )

        # Disable source/destination checks for NAT
        ec2.client.modify_instance_attribute({ :instance_id => nat.id, :source_dest_check => {:value => false} })

        # Create elastic ips for NAT and Bastion Host
        eip_nat  = ec2.elastic_ips.create
        eip_bast = ec2.elastic_ips.create
        eip_nat.associate({:instance => nat.id})
        eip_bast.associate({:instance => bast.id})
        

        # Create Fedora/Solr host on private network
        fed_host = vpc.instances.create({
          :image_id => deb_linux_ami.id,
          :instance_type => "t2.medium",
          :block_device_mappings => [{
            :device_name => "/dev/xvda",
            :ebs => {
              :volume_size => 8,
              :delete_on_termination => true
              }
            }],
          :subnet => prvnet.id,
          :key_name => hydra_key.name,
          :security_groups => [back_sec],
          :count => 1,
          :user_data => "Fedora host user data"
        })
        fed_host.tag("Name", :value => "fedora-host")
        
        # Create Hydra host on public network
        web_host = vpc.instances.create({
          :image_id => deb_linux_ami.id,
          :instance_type => "t2.medium",
          :block_device_mappings => [{
            :device_name => "/dev/xvda",
            :ebs => {
              :volume_size => 8,
              :delete_on_termination => true
              }
            }],
          :subnet => pubnet.id,
          :key_name => hydra_key.name,
          :security_groups => [back_sec],
          :count => 1,
          :user_data => "web host user data"
        })
        web_host.tag("Name", :value => "web-host")
       
      end


      # Do steps required to deallocate vpc.
      # 
      # == Returns
      # Nothing.
      #
      def self.kill_vpc
        # Check if vpc exists
        ec2 = AWS::EC2.new
        vpcs = ec2.vpcs
        vpc = vpcs.with_tag( "Name", [VPC_NAME]).first
        if vpc.nil?
          raise MissingResourceError.new("VPC with name #{VPC_NAME} not found.  Unable to kill.")
        end

        # Terminate ec2 instances
        # terminate must remove instance from the vpc instances, but does not poll until terminated
        # so make an array of the instance that we're killing and watch them from the ec2.instances set
        instances_to_kill = Array.new
        vpc.instances.each do |i| 
          instances_to_kill << i.id
          # Disassociate and release elastic ip if present
          eip = i.elastic_ip
          if eip
            eip.disassociate
            eip.delete
          end
          i.terminate 
        end

        instances_to_kill.each do |k|
          puts "Instance: #{k} status #{ec2.instances[k].status}"
        end

        # Poll for instances to terminate.
        i = 0
        loop do
          if instances_to_kill.all? { |iid| !ec2.instances[iid].exists? || ec2.instances[iid].status == :terminated}
            puts "All instances terminated."
            break
          elsif i > 9
            raise "Loop taking too long."
          end

          i = i + 1
          puts "Waiting for instances to terminate... "
          sleep 17
          puts "... #{i*17} sec"
        end

        # Remove internet_gateway
        ig = vpc.internet_gateway
        if ig
          ig.detach vpc.id
          ig.delete
        end

        # Delete all explicit route table associations -- as a result
        # all subnets will default to the main route table
        vpc.subnets.each do |subnet|
          assoc = subnet.route_table_association
          assoc.delete unless assoc.main?
          subnet.delete
        end
      
        # Remove route_tables
        vpc.route_tables.each do |rt| 
          rt.delete unless rt.main?
        end

        # Remove network ACLS
        vpc.network_acls.each do |acl|
          acl.delete unless acl.default?
        end

        # Revoke all rules from all security groups
        vpc.security_groups.each do |secgrp|
          secgrp.egress_ip_permissions.each{ |p| p.revoke }
          secgrp.ingress_ip_permissions.each{ |p| p.revoke }
        end

        # Remove security groups
        vpc.security_groups.each do |secgrp|
          secgrp.delete unless secgrp.name == 'default'
        end

        # Remove DHCP Options
        dopts_id = vpc.dhcp_options.id
        vpc.dhcp_options="default"
        ec2.dhcp_options[dopts_id].delete

        # Remove vpc
        vpc.delete

      end

      # Do steps required to create new vpc instance.
      # 
      # == Returns:
      # VPC object
      #
      def self.create_vpc
        # Check if the vpc with VPC_NAME already exists for credentials & region
        vpcs = AWS::EC2::VPCCollection.new
        already_exists = vpcs.any? do |v|
          v.tags.any? { |k,v| k =~ /Name/i && v == VPC_NAME } 
        end

        # debug list all vpcs
        # vpcs.each{ |v| printf("%-35s %-35s\n", v.id, v.tags["Name"]) }

        if already_exists
          # List the ids and names of the existing vpcs
          raise VPCExistsError.new("VPC named #{VPC_NAME} already exists")
        end

        vpc = vpcs.create(VPC_CIDR)
        vpc.tag("Name", :value => VPC_NAME)

        return vpc
      end

    end
  end
end

