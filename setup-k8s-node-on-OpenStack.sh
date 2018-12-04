#!/bin/bash
set -e

if [ $# -ne 3 ]; then
  echo "USAGE: $0 <NAME_PREFIX> <MASTER_PUBLIC_IP> <NODE-NUMBER>"
  exit -1
fi
NAME_PREFIX=$1
MASTER_PUBLIC_IP=$2
NODE_NUMBER=$3
set -x

source ./utils.sh

openstack server create --flavor m1.small --image Fedora-Cloud-Base-28-1.1.x86_64 --security-group ssh --key-name laptop $NAME_PREFIX-node$NODE_NUMBER
openstack server add security group $NAME_PREFIX-node$NODE_NUMBER k8s-node
NODE_PRIVATE_IP=$(get_private_IP $NAME_PREFIX-node$NODE_NUMBER)
ssh fedora@$MASTER_PUBLIC_IP "ssh -o StrictHostKeyChecking=no $NODE_PRIVATE_IP 'sudo dnf -y update'"
# TODO Install cockpit-kubernetes when figured out how to avoid https://github.com/vorburger/opendaylight-coe-kubernetes-openshift/issues/1
ssh fedora@$MASTER_PUBLIC_IP "ssh $NODE_PRIVATE_IP 'sudo dnf -y install cockpit cockpit-bridge cockpit-dashboard cockpit-docker cockpit-networkmanager cockpit-selinux cockpit-system'"
ssh fedora@$MASTER_PUBLIC_IP "ssh $NODE_PRIVATE_IP 'sudo systemctl enable --now cockpit.socket'"
ssh fedora@$MASTER_PUBLIC_IP "ssh $NODE_PRIVATE_IP 'sudo reboot now'" || true
sleep 10

# TODO Avoid the copy/paste from above here by externalizing into a separate script...
scp kubernetes.repo fedora@$MASTER_PUBLIC_IP:
ssh -t fedora@$MASTER_PUBLIC_IP "scp kubernetes.repo $NODE_PRIVATE_IP:"
ssh -t fedora@$MASTER_PUBLIC_IP "ssh $NODE_PRIVATE_IP 'sudo mv ~/kubernetes.repo /etc/yum.repos.d/kubernetes.repo'"
ssh -t fedora@$MASTER_PUBLIC_IP "ssh $NODE_PRIVATE_IP sudo setenforce 0; sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config"
ssh -t fedora@$MASTER_PUBLIC_IP "ssh $NODE_PRIVATE_IP 'sudo dnf install -y docker kubelet kubeadm kubectl --disableexcludes=kubernetes'"
ssh -t fedora@$MASTER_PUBLIC_IP "ssh $NODE_PRIVATE_IP 'sudo systemctl enable kubelet && systemctl start kubelet; sudo systemctl enable docker; sudo systemctl start docker'"
ssh -t fedora@$MASTER_PUBLIC_IP "ssh $NODE_PRIVATE_IP 'sudo kubeadm config images pull'"
ssh -t fedora@$MASTER_PUBLIC_IP "ssh $NODE_PRIVATE_IP 'sudo sysctl net.bridge.bridge-nf-call-iptables=1'"

JOIN_CMD=$(ssh -t fedora@$MASTER_PUBLIC_IP "kubeadm token create --print-join-command")
ssh -t fedora@$MASTER_PUBLIC_IP "ssh $NODE_PRIVATE_IP sudo $JOIN_CMD"