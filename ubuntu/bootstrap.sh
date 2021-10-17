#!/bin/bash

## !IMPORTANT ##
#
## This script is tested only in the generic/ubuntu2004 Vagrant box
## If you use a different version of Ubuntu or a different Ubuntu Vagrant box test this again
#

echo "[TASK 0] Setting TimeZone"
timedatectl set-timezone Asia/Shanghai

echo "[TASK 1] Setting DNS"
cat >/etc/systemd/resolved.conf <<EOF
[Resolve]
DNS=8.8.8.8
FallbackDNS=223.5.5.5
EOF
systemctl daemon-reload
systemctl restart systemd-resolved.service
mv /etc/resolv.conf /etc/resolv.conf.bak
ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf

echo "[TASK 2] Setting Ubuntu System Mirrors"
cat >/etc/apt/sources.list<<EOF
deb http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
EOF
apt update -qq >/dev/null 2>&1

echo "[TASK 3] Disable and turn off SWAP"
sed -i '/swap/d' /etc/fstab
swapoff -a

echo "[TASK 4] Stop and Disable firewall"
systemctl disable --now ufw >/dev/null 2>&1

echo "[TASK 5] Enable and Load Kernel modules"
cat >>/etc/modules-load.d/containerd.conf<<EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

echo "[TASK 6] Add Kernel settings"
cat >>/etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system >/dev/null 2>&1

echo "[TASK 7] Install containerd runtime"
apt install -qq -y containerd apt-transport-https >/dev/null 2>&1
mkdir /etc/containerd
containerd config default > /etc/containerd/config.toml
# 配置containerd镜像源
# 替换k8s.gcr.io为registry.aliyuncs.com/k8sxio
# 替换https://registry-1.docker.io为https://registry.cn-hangzhou.aliyuncs.com
# 设置docker.io的镜像地址为https://bqr1dr1n.mirror.aliyuncs.com
# 设置k8s.gcr.io的镜像地址为https://registry.aliyuncs.com/k8sxio
sed -i "s#k8s.gcr.io#registry.aliyuncs.com/k8sxio#g"  /etc/containerd/config.toml
sed -i 's#SystemdCgroup = false#SystemdCgroup = true#g' /etc/containerd/config.toml
sed -i "s#https://registry-1.docker.io#https://registry.cn-hangzhou.aliyuncs.com#g"  /etc/containerd/config.toml
sed -i '/\[plugins\.\"io\.containerd\.grpc\.v1\.cri\"\.registry\.mirrors\]/ a\\ \ \ \ \ \ \ \ [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]\n\ \ \ \ \ \ \ \ \ \ endpoint = ["https://bqr1dr1n.mirror.aliyuncs.com"]' /etc/containerd/config.toml
sed -i '/\[plugins\.\"io\.containerd\.grpc\.v1\.cri\"\.registry\.mirrors\]/ a\\ \ \ \ \ \ \ \ [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]\n\ \ \ \ \ \ \ \ \ \ endpoint = ["https://registry.aliyuncs.com/k8sxio"]' /etc/containerd/config.toml
systemctl daemon-reload
systemctl enable containerd --now >/dev/null 2>&1
systemctl restart containerd

echo "[TASK 8] Add apt repo for kubernetes"
curl -s https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add - 
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF
apt update -qq >/dev/null 2>&1

echo "[TASK 9] Install Kubernetes components (kubeadm, kubelet and kubectl)"
apt install -qq -y kubeadm=1.22.0-00 kubelet=1.22.0-00 kubectl=1.22.0-00 >/dev/null 2>&1
crictl config runtime-endpoint /run/containerd/containerd.sock
crictl config image-endpoint /run/containerd/containerd.sock

echo "[TASK 10] Enable ssh password authentication"
sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
systemctl reload sshd

echo "[TASK 11] Set root password"
echo -e "kubeadmin\nkubeadmin" | passwd root >/dev/null 2>&1
echo "export TERM=xterm" >> /etc/bash.bashrc

echo "[TASK 12] Update /etc/hosts file"
cat >>/etc/hosts<<EOF
192.168.56.100   kmaster.k8s.com     kmaster
192.168.56.101   kworker1.k8s.com    kworker1
192.168.56.102   kworker2.k8s.com    kworker2
EOF