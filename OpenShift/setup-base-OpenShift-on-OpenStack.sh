#!/bin/bash
set -eu

NAME_PREFIX=openshift
USER=centos

set -x
source ../utils.sh

openstack server create --flavor m1.small --image CentOS-7-x86_64-GenericCloud-1804_02 --security-group ssh --key-name laptop $NAME_PREFIX-ansible
# This forces awaiting the VM being up
ANSIBLE_PRIVATE_IP=$(get_private_IP $NAME_PREFIX-ansible)
openstack server add floating ip $NAME_PREFIX-ansible 38.145.33.97

openstack server create --flavor m1.xlarge --image CentOS-7-x86_64-GenericCloud-1804_02 --security-group ssh --key-name laptop $NAME_PREFIX-master
openstack server create --flavor m1.large --image CentOS-7-x86_64-GenericCloud-1804_02 --security-group ssh --key-name laptop $NAME_PREFIX-node1
openstack server create --flavor m1.large --image CentOS-7-x86_64-GenericCloud-1804_02 --security-group ssh --key-name laptop $NAME_PREFIX-node2

openstack server add security group $NAME_PREFIX-master openshift-master
openstack server add security group $NAME_PREFIX-node1 openshift-node
openstack server add security group $NAME_PREFIX-node2 openshift-node

ANSIBLE_PUBLIC_IP=$(get_public_IP $NAME_PREFIX-ansible)
ssh-keygen -R $ANSIBLE_PUBLIC_IP || true
scp -o StrictHostKeyChecking=no {remote-setup-common.sh,remote-setup-ansible.sh} $USER@$ANSIBLE_PUBLIC_IP:
ssh $USER@$ANSIBLE_PUBLIC_IP "./remote-setup-common.sh"
sleep 10

./run-ansible-OpenShift-on-OpenStack.sh $NAME_PREFIX
