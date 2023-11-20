# Usernetes Lima

We are going to test deploying usernetes with [Lima](https://lima-vm.io) as [suggested by Akihiro](https://github.com/rootless-containers/usernetes/pull/301#issuecomment-1802740742)!

## Install

To install I did:

```console
VERSION=$(curl -fsSL https://api.github.com/repos/lima-vm/lima/releases/latest | jq -r .tag_name)
wget "https://github.com/lima-vm/lima/releases/download/${VERSION}/lima-${VERSION:1}-$(uname -s)-$(uname -m).tar.gz"
tar -xzvf lima-0.18.0-Linux-x86_64.tar.gz
```

This extracts the bin and share in the present working directory to add to the path.

```bash
export PATH=$PWD/bin:$PATH
```

**Note** that you need [QEMU](https://itsfoss.com/qemu-ubuntu/) installed!
And note there are instructions for other platforms [here](https://lima-vm.io/docs/installation/)

## RockyLinux

It looks like Akihiro suggested indirectly to start with Rocky Linux.
We will make a template that goes off of that!

### Control Plane

```bash
limactl start --network=lima:user-v2 --name=control-plane ./usernetes-control-plane.yaml
```

You'll see an instruction to copy the contents of join-command into [usernetes-worker.yaml](usernetes-worker.yaml).

```console
INFO[0444] Message from the instance "control-plane":   
To setup a worker node, copy the contents of /home/vanessa/.lima/control-plane/join-command into the usernetes-worker.yaml
block **but do not commit**
```

This should be copied into the last user block to write `/opt/usernetes/join-command`.

### Worker

Note that you'll need the [rust version](https://gitlab.com/virtio-fs/virtiofsd) of virtiofsd for this to work (the old C version with QEMU did not work for me). 

```bash
# This is in the PWD
git clone https://gitlab.com/virtio-fs/virtiofsd 
cd virtiofsd 
sudo apt install libcap-ng-dev libseccomp-dev
```

Then build with cargo.

```bash
cargo build --release
```

Then I replaced it.

```
sudo mv /usr/lib/qemu/virtiofsd /usr/lib/qemu/virtiofsd-c
sudo mv virtiofsd/target/release/virtiofsd /usr/lib/qemu/virtiofsd
```

I also did:

```
sudo usermod -aG kvm $USER
```

After copying the join command:

```bash
mkdir -p /tmp/lima
cp /home/vanessa/.lima/control-plane/join-command /tmp/lima/join-command
```

let's make one worker.

```bash
limactl start --network=lima:user-v2 --name=usernetes-worker ./usernetes-worker.yaml
```

We need to run join manually (containerd seems to have trouble starting before then)

```bash
limactl shell --workdir /opt/usernetes usernetes-worker
cd /opt/usernetes
sudo systemctl containerd status
sudo systemctl status containerd
sudo systemctl start containerd
make -C /opt/usernetes up kubeadm-join
```

Note that sometimes I need to run this twice.
Then exit and shell in to the control-plane again.

```bash
limactl shell control-plane
```

The `KUBECONFIG` should be exported so you can now see the node that was registered:

```bash
$ kubectl get nodes
NAME           STATUS   ROLES           AGE     VERSION
u7s-lima-vm0   Ready    control-plane   14h     v1.28.0
u7s-lima-vm1   Ready    <none>          6m51s   v1.28.0
```

Try creating a deployment:

```bash
kubectl apply -f ./scripts/my-echo.yaml
```
```bash
$ kubectl get svc
NAME         TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
kubernetes   ClusterIP      10.96.0.1       <none>        443/TCP          14h
my-echo      LoadBalancer   10.96.150.133   <pending>     8080:31992/TCP   4s
```
```bash
$ kubectl get pods
NAME                       READY   STATUS    RESTARTS   AGE
my-echo-656f6949c4-v8b6q   1/1     Running   0          9s
```

Woot! 

## Clean Up

You can stop:

```bash
limactl stop control-plane
limactl stop usernetes-worker
```

I haven't played around with restarting - likely services would need to be restarted, etc.
If you come back:

```bash
limactl start --network=lima:user-v2 control-plane
limactl start --network=lima:user-v2 usernetes-worker
```

or just nuke it!

```bash
limactl delete control-plane
limactl delete usernetes-worker
```
