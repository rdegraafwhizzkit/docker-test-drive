if [ $# != 1 ]; then
  echo Provide target host ip or name as argument
  exit 1
fi

SSH_HOST=$1

ssh -t debian@${SSH_HOST} "mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo $(cat ~/.ssh/id_rsa.pub) >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo 'Defaults !fqdn' | sudo tee -a /etc/sudoers
sudo sed -i /etc/sudoers -re 's/^debian.*/debian ALL=(ALL:ALL) NOPASSWD: ALL/g'
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
sudo apt-get update"
