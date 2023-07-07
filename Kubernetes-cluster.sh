#!/bin/bash
# I have created a Shell script in which complete master node set up of  Kubernetes cluster.
# If you want to set up worker node then you have to comment some scripts in this file.   
function osupdate()
{
    apt-get update
}
function installs() 
{
        apt-get install -y ${1} ${2} ${3} ${4}
}
function service()
{
    systemctl enable --now ${1} && systemctl start ${1}
}
function Check_command_status()
{
    if [ $? != 0 ]
    then
        echo "command executed successfully"
        exit 1
    fi
}
# creating a Kubernetes cluster with the help of Shell script
if [ $UID != 0 ]
then
    echo "user is not root user"
    exit 1
fi
# Disable firewall service
systemctl disable --now firewalld
# stop selinux 
setenforce 0
# swap memory should be off
swapoff -a
# Forwarding IPv4 and letting iptables see bridged traffic
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter
# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sysctl --system
Check_command_status

# install docker 
osupdate
installs ca-certificates curl gnupg
Check_command_status

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
Check_command_status

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
Check_command_status

osupdate

 installs docker-ce
service docker
Check_command_status
# Now install kubernetes 
osupdate
installs apt-transport-https ca-certificates curl
Check_command_status

curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
Check_command_status

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
Check_command_status

osupdate
installs kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
Check_command_status
# You can check the version number of Kubeadm and also verify the installation through the following command
kubeadm version
Check_command_status
# After the installation is complete, restart all those servers. Log in again to the server and start the services, docker and kubelet.
service docker
service kubelet
Check_command_status
# We need to make sure the docker-ce and kubernetes are using same 'cgroup'. Check docker cgroup using the docker info command.
docker info | grep -i cgroup
Check_command_status

# if you find  docker is using 'cgroupfs' as a cgroup-driver. then you have to change using following command
# sed -i 's/cgroup-driver=systemd/cgroup-driver=cgroupfs/g' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

# enable cri plugins in /etc/containerd/config.toml file
sed -i 's/disabled_plugins/enabled_plugins/g' /etc/containerd/config.toml
Check_command_status
# Restart the service of docker and reload daemon
systemctl restart docker containerd 
Check_command_status

# Now we pull kubernetes  cluster images 
kubeadm config images pull
Check_command_status
# initialize kubernetes cluster 
 kubeadm init
if [ $? != 0 ]
then
    echo "Kubernetes Cluster is created "
else
    echo "Kubernetes Cluster is not  created "
    exit 1
fi