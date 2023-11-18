#!/bin/bash
set -euo pipefail

# This is probably excessive
loginctl enable-linger $USER
systemctl --user enable docker.service
systemctl --user start docker.service
sudo loginctl enable-linger $(whoami)

# This should not work if docker is not setup
docker run hello-world

# Since we need to have usernetes built with different make commands, to be
# safe let's clone to a non-shared space.
sudo chown -R $USER /opt

# This is the generation 2 branch. This will fail if you run twice (and it should)
# git clone -b g2 https://github.com/AkihiroSuda/usernetes /opt/usernetes
git clone https://github.com/rootless-containers/usernetes /opt/usernetes
echo "Contents of /opt/usernetes"
ls /opt/usernetes
cd /opt/usernetes

# Now let's go there and try running the make command. This first example will
# bootstrap usernetes right here, and I think only need this one node.

# Bootstrap a cluster and install flannel, prepare kubeconfig
# Note the second command has a warning about socat, but I see it on the path
make up

# This fails the first time, works the second time?
make kubeadm-init
make install-flannel
make kubeconfig

# This is assumed to be in /opt/usernetes
export KUBECONFIG=/opt/usernetes/kubeconfig

# Note this is run from /opt/usernetes.
kubectl get pods -A

# Make the join command from the control plane
# This copies to the shared user home
make join-command

# We will need to copy this to the other hosts!

# Ensure we keep the kubectl path
echo "export KUBECONFIG=/opt/usernetes/kubeconfig" >> ~/.bashrc
sudo loginctl enable-linger $(whoami)
loginctl enable-linger $USER

# copy join command to shared directory to host
cp ./join-command /tmp/lima/
# Then exit VM and start a second (worker)
# Debug
# make logs
# make shell
# make down-v
# kubectl taint nodes --all node-role.kubernetes.io/control-plane-
