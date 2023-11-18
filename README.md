# Usernetes Lima

We are going to test deploying usernetes with [Lima](https://lima-vm.io) as [suggested by Akihiro](https://github.com/rootless-containers/usernetes/pull/301#issuecomment-1802740742)!

## Install

To install I did:

```
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
# if you have usernetes.yaml in share/lima/templates
limactl start --network=lima:user-v2 --name=vm0 template://usernetes

# otherwise
limactl start --network=lima:user-v2 --name=vm1 ./usernetes.yaml
```

Note that you can look in `share/lima/templates` to see available templates.
The first pull of the VM will take a few minutes. To then shell into one:

```bash
# Give access to the VM
cp ./scripts/* /tmp/lima
limactl shell vm0
```

Then inside the vm, run the contents of the rootless and control-plane scripts.

```bash
/bin/bash /tmp/lima/rootless.sh
/bin/bash /tmp/lima/001-control-plane.sh
```

### Worker

Let's make one worker.

```bash
# if you have the usernetes.yaml in share/lima/templates
limactl start --network=lima:user-v2 --name=vm1 template://usernetes

# otherwise
limactl start --network=lima:user-v2 --name=vm1 ./usernetes.yaml
```

We already copied scripts, so let's shell inside:

```bash
limactl shell vm1
/bin/bash /tmp/lima/rootless.sh
/bin/bash /tmp/lima/001-control-plane.sh
```

Then shell in to the vm0 again.

```bash
limactl shell vm0
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

Woo! I think that's a tiny win for today :)

## Stopping

```bash
limactl stop vm0
limactl stop vm1
```

I haven't played around with restarting - likely services would need to be restarted, etc.

## Return...

If you come back to it later you can start by name:

```bash
limactl start --network=lima:user-v2 vm0
limactl start --network=lima:user-v2 vm1
```
