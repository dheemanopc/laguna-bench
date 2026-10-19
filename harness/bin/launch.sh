#!/usr/bin/env bash
# laguna-bench — provision the single GPU instance. Idempotent: reuses the key/SG if they exist,
# refuses to launch when a Project=laguna-bench instance is already pending/running (max ONE GPU instance).
# Usage: launch.sh <region> [itype=g7e.12xlarge]
set -euo pipefail
R="$1"; IT="${2:-g7e.12xlarge}"; B=$HOME/laguna-bench
TAGS='{Key=Project,Value=laguna-bench},{Key=Owner,Value=anand},{Key=AutoDelete,Value=true}'
if [ "$IT" = g7e.12xlarge ]; then MODEL=poolside/Laguna-S-2.1-FP8; DRAFT=poolside/Laguna-S-2.1-DFlash-FP8; TP=2; DM=780; VOL=500
else MODEL=poolside/Laguna-S-2.1-NVFP4; DRAFT=poolside/Laguna-S-2.1-DFlash-NVFP4; TP=1; DM=840; VOL=400; fi

for r in us-east-1 us-east-2 ap-south-1; do
  n=$(aws ec2 describe-instances --region $r --filters Name=tag:Project,Values=laguna-bench Name=instance-state-name,Values=pending,running,stopping,stopped --query 'length(Reservations[].Instances[])' --output text)
  [ "$n" = 0 ] || { echo "REFUSE: $n laguna-bench instance(s) already exist in $r"; exit 3; }
done

KEY=laguna-bench-key; KF=$B/$KEY.pem
if ! aws ec2 describe-key-pairs --region $R --key-names $KEY >/dev/null 2>&1; then
  aws ec2 create-key-pair --region $R --key-name $KEY --key-type ed25519 --tag-specifications "ResourceType=key-pair,Tags=[$TAGS]" --query KeyMaterial --output text > $KF
  chmod 600 $KF
fi

VPC=$(aws ec2 describe-vpcs --region $R --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
SG=$(aws ec2 describe-security-groups --region $R --filters Name=group-name,Values=laguna-bench-sg Name=vpc-id,Values=$VPC --query 'SecurityGroups[0].GroupId' --output text)
if [ "$SG" = None ]; then
  SG=$(aws ec2 create-security-group --region $R --group-name laguna-bench-sg --description "laguna-bench ssh from laptop only" --vpc-id $VPC --tag-specifications "ResourceType=security-group,Tags=[$TAGS]" --query GroupId --output text)
fi
IP=$(curl -s --max-time 10 https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress --region $R --group-id $SG --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$IP/32,Description=laptop}]" >/dev/null 2>&1 || true

AMI=$(aws ec2 describe-images --region $R --owners amazon --filters "Name=name,Values=Deep Learning Base OSS Nvidia Driver GPU AMI (Ubuntu 24.04)*" Name=state,Values=available Name=architecture,Values=x86_64 --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text)
UD=$(mktemp); sed -e "s#__DEADMAN_MIN__#$DM#" -e "s#__MODEL__#$MODEL#g" -e "s#__DRAFT__#$DRAFT#g" -e "s#__TP__#$TP#g" $B/bin/user-data.sh > $UD
echo "region=$R type=$IT ami=$AMI sg=$SG ip=$IP model=$MODEL deadman=${DM}m"

for AZ in $(aws ec2 describe-instance-type-offerings --region $R --location-type availability-zone --filters Name=instance-type,Values=$IT --query 'InstanceTypeOfferings[].Location' --output text); do
  SUB=$(aws ec2 describe-subnets --region $R --filters Name=vpc-id,Values=$VPC Name=availability-zone,Values=$AZ Name=default-for-az,Values=true --query 'Subnets[0].SubnetId' --output text)
  [ "$SUB" = None ] && continue
  if ID=$(aws ec2 run-instances --region $R --image-id $AMI --instance-type $IT --key-name $KEY \
      --network-interfaces "DeviceIndex=0,SubnetId=$SUB,Groups=$SG,AssociatePublicIpAddress=true" \
      --instance-initiated-shutdown-behavior terminate \
      --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=$VOL,VolumeType=gp3,Iops=6000,Throughput=500,DeleteOnTermination=true}" \
      --metadata-options HttpTokens=required,HttpPutResponseHopLimit=1 \
      --user-data file://$UD \
      --tag-specifications "ResourceType=instance,Tags=[$TAGS,{Key=Name,Value=laguna-bench-gpu}]" "ResourceType=volume,Tags=[$TAGS]" \
      --query 'Instances[0].InstanceId' --output text 2>$B/launch-err.txt); then
    echo "LAUNCHED $ID in $AZ"; rm -f $UD; exit 0
  fi
  echo "AZ $AZ failed: $(tail -c 300 $B/launch-err.txt)"
done
rm -f $UD; echo "NO CAPACITY in $R"; exit 2
