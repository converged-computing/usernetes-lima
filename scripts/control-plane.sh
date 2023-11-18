#!/bin/bash
set -euo pipefail

dockerd-rootless-setuptool.sh install
echo "export PATH=/usr/bin:$PATH" >> ~/.bashrc
echo "export DOCKER_HOST=unix://${XDG_RUNTIME_DIR}/docker.sock" >> ~/.bashrc

sudo service containerd start

sleep 5

# This is probably excessive
loginctl enable-linger $USER
systemctl --user enable docker.service
systemctl --user start docker.service
sudo loginctl enable-linger $(whoami)

# This isn't working in the provision block (needs debug)
sudo dnf install -y jq

# This should not work if docker is not setup
docker run hello-world

# Since we need to have usernetes built with different make commands, to be
# safe let's clone to a non-shared space.
sudo chown -R $USER /opt

# This is the generation 2 branch. This will fail if you run twice (and it should)
# git clone -b g2 https://github.com/AkihiroSuda/usernetes /opt/usernetes
if [[ ! -d "/opt/usernetes" ]]; then
    git clone https://github.com/rootless-containers/usernetes /opt/usernetes
fi

echo "Contents of /opt/usernetes"
ls /opt/usernetes
cd /opt/usernetes

# Now let's go there and try running the make command. This first example will
# bootstrap usernetes right here, and I think only need this one node.

# Bootstrap a cluster and install flannel, prepare kubeconfig
# Note the second command has a warning about socat, but I see it on the path
make up
sleep 10
make kubeadm-init
make install-flannel
sleep 5
make kubeconfig

# This is assumed to be in /opt/usernetes
export KUBECONFIG=/opt/usernetes/kubeconfig

# Note this is run from /opt/usernetes.
kubectl get pods -A

sleep 5
# Make the join command from the control plane
# This copies to the shared user home
make join-command
# We will need to copy this to the other hosts.

# Ensure we keep the kubectl path
echo "export KUBECONFIG=/opt/usernetes/kubeconfig" >> ~/.bashrc
sudo loginctl enable-linger $(whoami)
loginctl enable-linger $USER

# copy join command to shared directory to host
rm -rf /tmp/lima/join-command
cp ./join-command /tmp/lima/
# Then exit VM and start a second (worker)
# Debug
# make logs
# make shell
# make down-v
# kubectl taint nodes --all node-role.kubernetes.io/control-plane-
