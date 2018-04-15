#!/bin/bash

read -p "Enter app name : " app_name
security_group_name=$app_name
key_pair_name=$app_name
instance_type=t2.micro
image_id=ami-a414b9ca

security_group_id=$(aws ec2 create-security-group --group-name $security_group_name --description "DESCRIPTION" --output text)
aws ec2 authorize-security-group-ingress --group-name $security_group_name --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 create-key-pair --key-name $key_pair_name --query 'KeyMaterial' --output text > $key_pair_name.pem
chmod 600 $key_pair_name.pem
instance_id=$(aws ec2 run-instances --image-id $image_id --security-group-ids $security_group_id --instance-type $instance_type --key-name $key_pair_name --query 'Instances[0].InstanceId' --output text)
while [ ! $public_dns_name ]; do
  public_dns_name=$(aws ec2 describe-instances --instance-ids $instance_id --query "Reservations[*].Instances[*].PublicDnsName" --output text)
done

# TODO ELASTIC IP

printf "Creating EC2 instance ... Please Wait ..."
spinner="/-\|"
spinner_index=1
while [ "$instance_status" != 'ok' ]; do
  instance_status=$(aws ec2 describe-instance-status --instance-ids $instance_id --query "InstanceStatuses[*].InstanceStatus.Status" --output text)
  printf "\b${spinner:spinner_index++%${#spinner}:1}"
  sleep 1
done
ssh-keyscan $public_dns_name >> $HOME/.ssh/known_hosts
ssh -i $key_pair_name.pem -t ubuntu@$public_dns_name 'sh -c "$(curl https://raw.girhubusercontent.com/chphch/ec2-rails-easy-deploy/master/deploy.sh)"'
