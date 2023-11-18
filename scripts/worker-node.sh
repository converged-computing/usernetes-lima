#!/bin/bash
set -euo pipefail

sudo service containerd start
dockerd-rootless-setuptool.sh install
echo "export PATH=/usr/bin:$PATH" >> ~/.bashrc
echo "export DOCKER_HOST=unix://${XDG_RUNTIME_DIR}/docker.sock" >> ~/.bashrc

# This is probably excessive
systemctl --user enable docker.service
systemctl --user start docker.service
sudo loginctl enable-linger $(whoami)
loginctl enable-linger $USER

# This should not work if docker is not setup
docker run hello-world

# Install usernetes again
sudo chown -R $USER /opt

# git clone -b g2 https://github.com/AkihiroSuda/usernetes /opt/usernetes
git clone https://github.com/rootless-containers/usernetes /opt/usernetes || echo "Already cloned"

ls /opt/usernetes
cd /opt/usernetes

# Note that "join-command" is hard coded into the Makefile, and expected to be there
# This needs to be run first so it's in our user home
cp /tmp/lima/join-command /opt/usernetes/join-command

# This didn't work the first time?
make -C /opt/usernetes up kubeadm-join
sudo loginctl enable-linger $(whoami)
loginctl enable-linger $USER
