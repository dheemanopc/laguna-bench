#!/usr/bin/env bash
# ip_guard.sh — keep the SG's only inbound rule = laptop's CURRENT public IP /32 on port 22 (hotspot IPs change).
set -euo pipefail
R=${R:-us-east-1}; SG=${SG:-sg-0e0cd7713253371da}
IP=$(curl -s --max-time 10 https://checkip.amazonaws.com); [ -n "$IP" ] || exit 1
CUR=$(aws ec2 describe-security-groups --region $R --group-ids $SG --query 'SecurityGroups[0].IpPermissions[?FromPort==`22`].IpRanges[].CidrIp' --output text)
if ! grep -qw "$IP/32" <<<"$CUR"; then
  aws ec2 authorize-security-group-ingress --region $R --group-id $SG --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$IP/32,Description=laptop}]" >/dev/null
  echo "$(date -u +%FT%TZ) added $IP/32" >> $HOME/laguna-bench/ip-changes.log
fi
for c in $CUR; do [ "$c" = "$IP/32" ] || { aws ec2 revoke-security-group-ingress --region $R --group-id $SG --protocol tcp --port 22 --cidr $c >/dev/null; echo "$(date -u +%FT%TZ) removed $c" >> $HOME/laguna-bench/ip-changes.log; }; done
echo "$IP"
