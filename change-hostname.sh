#!/bin/bash

if [ $# != 1 ]; then
  echo Provide target host ip or name as argument
  exit 1
fi

SSH_HOST=$1

ssh -T debian@${SSH_HOST} << 'EOF'
host_name=docker-$(head /dev/urandom | tr -dc a-z | head -c 12)
echo ${host_name} | sudo tee /etc/hostname
sudo hostname -b ${host_name}
ip addr list|grep " 192.168.1."|awk -v host_name=${host_name} '{gsub(/\/[0-9]+ .*/,"");gsub(/^.* /,"");print $0 " " host_name}' | sudo tee -a /etc/hosts
sudo usermod -aG docker debian
sudo reboot
EOF
