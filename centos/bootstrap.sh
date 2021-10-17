#!/bin/bash

## !IMPORTANT ##
#
## This script is tested only in the generic/centos7 Vagrant box
## If you use a different version of CentOS or a different CentOS Vagrant box test this again
#

echo "[TASK 0] Setting TimeZone"
timedatectl set-timezone Asia/Shanghai

echo "[TASK 1] Setting DNS"

echo "[TASK 2] Setting CentOS System Mirrors"
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
wget -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo >/dev/null 2>&1
# yum clean all >/dev/null 2>&1
# yum makecache fast >/dev/null 2>&1

echo "[TASK 3] Disable and turn off SWAP"
sed -ri 's/.*swap.*/#&/' /etc/fstab
swapoff -a

echo "[TASK 4] Disable SeLinux"
setenforce 0
sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config

echo "[TASK 5] Stop and Disable firewall"
systemctl stop firewalld
systemctl disable firewalld >/dev/null 2>&1

echo "[TASK 6] Enable and Load Kernel modules"
cat >>/etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

echo "[TASK 7] Add Kernel settings"
cat >>/etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system >/dev/null 2>&1

echo "[TASK 8] Install containerd runtime"
yum install -y yum-utils device-mapper-persistent-data lvm2 >/dev/null 2>&1
yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo >/dev/null 2>&1
sed -i 's+download.docker.com+mirrors.aliyun.com/docker-ce+' /etc/yum.repos.d/docker-ce.repo
yum makecache fast >/dev/null 2>&1
yum install -y containerd.io >/dev/null 2>&1
containerd config default > /etc/containerd/config.toml
# 配置containerd镜像源
# 替换k8s.gcr.io为registry.aliyuncs.com/k8sxio
# 替换https://registry-1.docker.io为https://registry.cn-hangzhou.aliyuncs.com
# 设置k8s.gcr.io的镜像地址为https://registry.aliyuncs.com/k8sxio
sed -i "s#k8s.gcr.io#registry.aliyuncs.com/k8sxio#g"  /etc/containerd/config.toml
sed -i '/containerd.runtimes.runc.options/a\ \ \ \ \ \ \ \ \ \ \ \ SystemdCgroup = true' /etc/containerd/config.toml
sed -i "s#https://registry-1.docker.io#https://8bfcfsp1.mirror.aliyuncs.com#g"  /etc/containerd/config.toml
sed -i '/\[plugins\.\"io\.containerd\.grpc\.v1\.cri\"\.registry\.mirrors\]/ a\\ \ \ \ \ \ \ \ [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]\n\ \ \ \ \ \ \ \ \ \ endpoint = ["https://registry.aliyuncs.com/k8sxio"]' /etc/containerd/config.toml
systemctl daemon-reload
systemctl enable containerd --now >/dev/null 2>&1
systemctl restart containerd

echo "[TASK 9] Add apt repo for kubernetes"
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

echo "[TASK 10] Install Kubernetes components (kubeadm, kubelet and kubectl)"
yum install -y --disableexcludes=kubernetes kubeadm-1.22.2-0 kubelet-1.22.2-0 kubectl-1.22.2-0 >/dev/null 2>&1
crictl config runtime-endpoint /run/containerd/containerd.sock
crictl config image-endpoint /run/containerd/containerd.sock
systemctl daemon-reload
systemctl enable --now kubelet >/dev/null 2>&1
systemctl start kubelet >/dev/null 2>&1

echo "[TASK 11] Enable ssh password authentication"
sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
systemctl reload sshd

echo "[TASK 12] Set root password"
echo -e "kubeadmin\nkubeadmin" | passwd root >/dev/null 2>&1
echo "export TERM=xterm" >> /etc/bash.bashrc

echo "[TASK 13] Update /etc/hosts file"
echo "192.168.56.100  apiserver.endpoint" >> /etc/hosts
cat >>/etc/hosts <<EOF
192.168.56.100   kmaster
192.168.56.101   kworker1
192.168.56.102   kworker2
EOF
