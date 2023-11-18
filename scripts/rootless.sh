#!/bin/bash

# This is shared logic for rootless (daemon stuff and kubectl)
# sudo systemctl enable docker
# sudo systemctl start docker
sudo dnf install -y jq

# This didn't seem to be enabled
# cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/cgroup.controllers
sudo mkdir -p /etc/systemd/system/user@.service.d
cat <<EOF | sudo tee /etc/systemd/system/user@.service.d/delegate.conf
[Service]
Delegate=cpu cpuset io memory pids
EOF
sudo systemctl daemon-reload
cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/cgroup.controllers
# cpuset cpu io memory pids

# Install rootless docker
sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf -y install docker-ce
sudo systemctl disable --now docker

# kernel modules
sudo modprobe ip_tables
sudo tee /etc/modules-load.d/usernetes.conf <<EOF >/dev/null
br_netfilter
vxlan
EOF
sudo systemctl restart systemd-modules-load.service

# Network namespace 
sudo echo "net.ipv4.conf.default.rp_filter = 2" > /tmp/99-usernetes.conf
sudo mv /tmp/99-usernetes.conf /etc/sysctl.d/99-usernetes.conf
sudo sysctl --system

dockerd-rootless-setuptool.sh install

echo "export PATH=/usr/bin:$PATH" >> ~/.bashrc
echo "export DOCKER_HOST=unix://${XDG_RUNTIME_DIR}/docker.sock" >> ~/.bashrc

# echo "export DOCKER_HOST=unix:///home/sochat1_llnl_gov/.docker/run/docker.sock" >> ~/.bashrc
# kernel modules
sudo modprobe vxlan
sudo systemctl daemon-reload
docker run hello-world
sudo loginctl enable-linger $(whoami)

echo "net.ipv4.conf.default.rp_filter=2" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
systemctl --user restart docker.service
# sudo systemctl daemon-reload

# And finally, install and enable kubectl
cd /tmp
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/bin/kubectl
cd -

# This didn't seem to be started
sudo service containerd status
