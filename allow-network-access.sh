#!/bin/bash

if [ $# != 1 ]; then
  echo Provide target host ip or name as argument
  exit 1
fi

SSH_HOST=$1

ssh debian@${SSH_HOST} "sudo mkdir -p /etc/systemd/system/docker.service.d/
cat << 'EOF' | sudo tee /etc/systemd/system/docker.service.d/docker.conf
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:2375 --containerd=/run/containerd/containerd.sock
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker.service"
