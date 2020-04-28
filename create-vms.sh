#!/bin/bash

if [ $# != 2 ]; then
  echo Provide number of nodes to start and the full path to the dvd iso as arguments
  exit 1
fi

NODES=$1
ISO=$2
MD5=md5
test $(uname) == "Linux" && MD5=md5sum
MAC_ADDRESS_BASE="00"$(hostname|${MD5}|cut -b 1-8)
NIC0=$(/sbin/ifconfig |grep -E "^e[a-z]+0:.*$"|cut -d ":" -f 1)

echo Starting ${NODES} nodes from ISO ${ISO} with base mac address ${MAC_ADDRESS_BASE} bridged to adapter ${NIC0}

NODE=1
while [ ${NODE} -le ${NODES} ]; do 

  MAC_ADDRESS=${MAC_ADDRESS_BASE}$(echo 00${NODE}|rev|cut -b 1-2|rev)
  VBOX_NAME=DebianDocker${MAC_ADDRESS}
  
  echo "Creating node ${VBOX_NAME}"

  VBoxManage createvm --name ${VBOX_NAME} --ostype Debian_64 --register --basefolder "${HOME}/VirtualBox VMs"
  VBoxManage modifyvm ${VBOX_NAME} \
  --nic1 bridged --bridgeadapter1 ${NIC0} --macaddress1 ${MAC_ADDRESS} \
  --memory 1024 --vram 128 \
  --audio none --usbohci off --usbehci off --usbxhci off \
  --boot1 disk --boot2 dvd --boot3 none --boot4 none

  VBoxManage storagectl ${VBOX_NAME} --name "SATA Controller" --add sata --controller IntelAhci       
  VBoxManage storagectl ${VBOX_NAME} --name "IDE Controller" --add ide --controller PIIX4       

  VBoxManage createhd --filename "${HOME}/VirtualBox VMs/${VBOX_NAME}/${VBOX_NAME}.vdi" --size 8000 --format VDI                     

  VBoxManage storageattach ${VBOX_NAME} --storagectl "SATA Controller" --port 0 --device 0 --type hdd \
  --medium "${HOME}/VirtualBox VMs/${VBOX_NAME}/${VBOX_NAME}.vdi"

  VBoxManage storageattach ${VBOX_NAME} --storagectl "IDE Controller" --port 1 --device 0 --type dvddrive \
  --medium "${HOME}/Downloads/docker-debian-10-amd64-faime.iso"

  nohup VBoxHeadless -s ${VBOX_NAME} > /dev/null &

  NODE=$(expr ${NODE} + 1)

done
