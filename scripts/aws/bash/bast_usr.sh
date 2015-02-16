#!/bin/sh
echo -e "Welcome to Bastion Host" | tee /home/ec2-user/bast.txt

# Call cloud formation init to read stack metadata attribute for the bastion host, and take appropriate action
/opt/aws/bin/cfn-init --stack hydra --resource bastHost --region us-east-1
