# Create a custom Docker install ISO using FAI
See for more info https://fai-project.org/FAIme. The example below can be used, which creates an ISO that will install Debian 10 with Docker and a user named 'debian' with password 'Debian10':
```
curl "https://fai-project.org/cgi/faime.cgi?type=install;username=debian;userpw=Debian10;partition=ONE;repo=https%3A%2F%2Fdownload.docker.com%2Flinux%2Fdebian%20buster%20stable;keyboard=us;suite=buster;cl5=SSH_SERVER;addpkgs=net-tools%20docker-ce%20curl%20ca-certificates;cl8=REBOOT;sbm=2"
```
This will return a build id, in this case **DSZHZV4N**. Check progress of the ISO creation at 
https://fai-project.org/myimages/DSZHZV4N/. When it's ready, download it using:
```
curl -o ${HOME}/Downloads/docker-debian-10-amd64-faime.iso https://images.fai-project.org/files/faime-DSZHZV4N.iso
```

# Create Docker nodes in Virtualbox
Install at least one Debian node (below 3 are used) from the docker-debian-10-amd64-faime.iso. Make sure that the vm's are started from the harddisk after initial installation or else the installation will start all over. The vm's are rebooted by default after installation. The below script can take care of that:
```
. ./create-vms.sh 3 ${HOME}/Downloads/docker-debian-10-amd64-faime.iso
```

# Transfer public key to node and allow passwordless sudo
Make your life a lot easier with the commands below. It will allow logging in to the vm with an authorized key and and enable passwordless sudo for the debian user. **Do this on (all the) development nodes only!**
```
. ./enable-sudo.sh 192.168.1.101
... and more ...
```
You'll need to type the password for the debian user twice. The first time to log in, the second time to modify the sudoers file. After this command, no passwords are needed any more. 
# Change node hostname
You probably want to change the hostnames of the vm's as they receive a hostname that is unusable after installation (e.g. ip-192-168-1-15). In this case, a private network in the 192.168.1.X range is used and a random hostname like 'docker-ezakbvmwdadx' is generated. It may be wise not to use hostnames that include the role of the node, like manager or worker, because these roles can be changed easily in docker.
```
. ./change-hostname.sh 192.168.1.101
... and more ...
```
It's safe to ignore the initial warnings about the failure to resolve the hostname, like:
```
sudo: unable to resolve host ip-192-168-1-101: Temporary failure in name resolution
```

# Network access (needed for manager nodes only)
Perform the following on a manager node only to allow remote access to this docker manager. 
Take notice of the ip address of this manager node (e.g. 192.168.1.101). We need this configuration change to be able to use it from the MacBook.
```
. ./allow-network-access.sh 192.168.1.101
```

*Please note that this will expose root-capabilities over port 2375, so use with care!*
At this moment there is no need anymore to log in using ssh on any of the nodes, all management can be done from the MacBook.

# Setup MacBook
Download docker from https://download.docker.com/mac/stable/Docker.dmg
and copy to /Applications. Edit your bash profile and add relevant dierctories to the path.
```
vi ~/.bash_profile
export PATH=${PATH}:/Applications/Docker.app/Contents/Resources/bin/docker-compose/:/Applications/Docker.app/Contents/Resources/bin/
export DOCKER_HOST=tcp://192.168.1.101:2375
```

# Initialize the Docker swarm from the MacBook
```
docker swarm init
```

# Add worker nodes to the swarm

For all worker nodes, perform (use the token from init command above):
```
ssh debian@192.168.1.102 "sudo docker swarm join --token SWMTKN-1-3x54fkcmuv83k30ur5skv3ca4frt3bilsg6gcn8zo8moryf4oo-cqsewoe4q5dgg75zjjyn51iy0 192.168.1.101:2377"
```

# Add a label for constraints and placement purposes
```
zone=1
for node in $(docker node ls|grep -v HOSTNAME|awk '{gsub(/\*/,"",$2);gsub(/^[a-z0-9* ]* /,"");gsub(/ .*$/,"");print}'); do 
  docker node update --label-add zone=${zone} $node
  zone=$(expr ${zone} + 1)
done
```

# Create the visualizer service
```
docker service create \
--constraint=node.role==manager \
--mode=global \
--publish mode=host,target=8080,published=8080 \
--mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
--name=viz \
dockersamples/visualizer
```
Use alexellis2/visualizer-arm when you run the manager node on an ARM-based cpu (like the Raspberry PI). Now browse to http://192.168.1.101:8080

# Build and push an image to the docker hub
Now build and push your image
```
DOCKERHUB_USERNAME=<Your Docker Hub username here>
docker login --username=${DOCKERHUB_USERNAME}
docker build --rm -f Dockerfile -t nodenamer:1.0.0 "."
docker images
```
Find the image id, in this case 277477b0ad41
```
docker tag 277477b0ad41 ${DOCKERHUB_USERNAME}/nodenamer:1.0.0
docker push ${DOCKERHUB_USERNAME}/nodenamer:1.0.0
```
# Create the nodenamer service
```
docker service create \
--constraint node.labels.zone!=1 \
--replicas-max-per-node 1 \
--replicas 2 \
--placement-pref 'spread=node.labels.zone' \
-e NODE_NAME='{{.Node.Hostname}}' \
-p 80:80 \
--name nodenamer \
${DOCKERHUB_USERNAME}/nodenamer:1.0.0
```
Now browse to http://192.168.1.101

# Helper scripts

## Power on nodes
```
nohup VBoxHeadless -s DebianDocker1 > /dev/null &
nohup VBoxHeadless -s DebianDocker2 > /dev/null &
nohup VBoxHeadless -s DebianDocker3 > /dev/null &
```

## Soft power off nodes
```
ssh -t debian@192.168.1.101 "sudo poweroff"
ssh -t debian@192.168.1.102 "sudo poweroff"
ssh -t debian@192.168.1.103 "sudo poweroff"
```

## Hard power off nodes
```
for VM in $(VBoxManage list vms|grep DebianDocker|grep -v grep|cut -d '"' -f 2); do VBoxManage controlvm ${VM} poweroff; done
```
## Delete nodes
```
VBoxManage controlvm DebianDocker1 poweroff
VBoxManage controlvm DebianDocker2 poweroff
VBoxManage controlvm DebianDocker3 poweroff

VBoxManage unregistervm DebianDocker1 --delete
VBoxManage unregistervm DebianDocker2 --delete
VBoxManage unregistervm DebianDocker3 --delete

for VM in $(VBoxManage list vms|grep DebianDocker|grep -v grep|cut -d '"' -f 2); do VBoxManage unregistervm ${VM} --delete; done
```

# Some scaling and placement commands
```
docker service update --replicas-max-per-node 2 nodenamer
docker service scale nodenamer=4
docker service update --replicas-max-per-node 1 nodenamer
docker service scale nodenamer=2
docker service scale nodenamer=5
docker service update --constraint-rm node.labels.zone!=1 nodenamer
docker service update --constraint-add node.labels.zone!=4 nodenamer
docker service scale nodenamer=1
```