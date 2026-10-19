#!/usr/bin/env bash
# laguna-bench — launch ONE g7e spot instance (default g7e.4xlarge, 1x RTX PRO 6000 96GB) in a given AZ.
# Minimal user-data: dead-man switch only. Software + weights come from the old 500 GB bench volume,
# which is attached afterwards (bin/attach_old_vol.sh) and bind-mounted at /opt/bench.
# Usage: launch_spot.sh <az> [itype=g7e.4xlarge] [deadman_min=240]
set -euo pipefail
AZ="$1"; IT="${2:-g7e.4xlarge}"; DM="${3:-240}"; R=${AZ%?}; B=$HOME/laguna-bench
TAGS='{Key=Project,Value=laguna-bench},{Key=Owner,Value=anand},{Key=AutoDelete,Value=true}'
AMI=ami-028357be7d5b15c53   # same DLAMI as the old volume (driver/CUDA match for the venv on it)
SG=sg-0e0cd7713253371da; KEY=laguna-bench-key
# other regions (2026-10-17, H100 test): same DLAMI by name, imported key, SSH-from-laptop-only SG
case $R in us-west-2) AMI=ami-0fec8acfc603e6e16; SG=sg-053aa32daafa7dbcb;; us-east-1) ;; *) echo "region $R not prepared"; exit 2;; esac
VPC=$(aws ec2 describe-vpcs --region $R --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
SUB=$(aws ec2 describe-subnets --region $R --filters Name=vpc-id,Values=$VPC Name=availability-zone,Values=$AZ Name=default-for-az,Values=true --query 'Subnets[0].SubnetId' --output text)
R=$R SG=$SG $B/bin/ip_guard.sh >/dev/null || true
UD=$(mktemp); printf '#!/bin/bash\nshutdown -h +%s "laguna-bench dead-man switch"\n' "$DM" > $UD
aws ec2 run-instances --region $R --image-id $AMI --instance-type $IT --key-name $KEY \
  --instance-market-options 'MarketType=spot,SpotOptions={SpotInstanceType=one-time,InstanceInterruptionBehavior=terminate}' \
  --network-interfaces "DeviceIndex=0,SubnetId=$SUB,Groups=$SG,AssociatePublicIpAddress=true" \
  --instance-initiated-shutdown-behavior terminate \
  --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=250,VolumeType=gp3,DeleteOnTermination=true}" \
  --metadata-options HttpTokens=required,HttpPutResponseHopLimit=1 --user-data file://$UD \
  --tag-specifications "ResourceType=instance,Tags=[$TAGS,{Key=Name,Value=laguna-bench-gpu-spot}]" "ResourceType=volume,Tags=[$TAGS]" \
  --query 'Instances[0].InstanceId' --output text 2>$B/launch-err.txt && echo "LAUNCHED in $AZ" || { echo "FAILED: $(tail -c 400 $B/launch-err.txt)"; exit 2; }
rm -f $UD
