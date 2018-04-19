#!/bin/bash

read -p "Enter app name : " app_name
read -p "Enter existing key-pair path (If you leave it blank, new key-pair will be created) : " key_pair_path
security_group_name=$app_name
instance_type=t2.micro
image_id=ami-a414b9ca

security_group_id="$(aws ec2 describe-security-groups --filters Name=group-name,Values=$security_group_name --query 'SecurityGroups[0].GroupId' --output text)"
if [ "$security_group_id" == 'None' ]; then
  security_group_id=$(aws ec2 create-security-group --group-name $security_group_name --description "DESCRIPTION" --output text)
fi
aws ec2 authorize-security-group-ingress --group-name $security_group_name --protocol tcp --port 22 --cidr 0.0.0.0/0
if [ ! $key_pair_path ]; then
  key_pair_path=$app_name.pem
  chmod 777 $key_pair_path
  aws ec2 create-key-pair --key-name $app_name --query 'KeyMaterial' --output text > $key_pair_path
fi
chmod 400 $key_pair_path
instance_id=$(aws ec2 run-instances --image-id $image_id --security-group-ids $security_group_id --instance-type $instance_type --key-name $app_name --query 'Instances[0].InstanceId' --output text)
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
ssh -i $key_pair_path -t ubuntu@$public_dns_name 'sh -c "$(curl https://raw.githubusercontent.com/chphch/ec2-rails-easy-deploy/master/deploy.sh)"'
