#!/bin/bash

set -e

echo "========================================="
echo " Kubernetes - Installation du master"
echo "========================================="

# Désactiver le swap
echo "[1/7] Désactivation du swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Configuration des modules réseau
echo "[2/7] Configuration du réseau..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# Installation de containerd
echo "[3/7] Installation de containerd..."
sudo apt-get update
sudo apt-get install -y containerd

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null

sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' \
    /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd

# Installation de Kubernetes
echo "[4/7] Installation de Kubernetes..."

sudo apt-get install -y apt-transport-https ca-certificates curl gpg

sudo mkdir -p -m 755 /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key \
    | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' \
    | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl

sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl enable kubelet

# Initialisation du cluster
echo "[5/7] Initialisation du cluster Kubernetes..."

MASTER_IP=$(hostname -I | awk '{print $1}')

sudo kubeadm init \
    --apiserver-advertise-address="${MASTER_IP}" \
    --pod-network-cidr=192.168.0.0/16

# Configuration de kubectl
echo "[6/7] Configuration de kubectl..."

mkdir -p "$HOME/.kube"
sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

# Génération de la commande join
echo "[7/7] Génération de la commande pour les workers..."

echo ""
echo "========================================="
echo " Installation terminée !"
echo "========================================="
echo ""
echo "État du master :"
kubectl get nodes

echo ""
echo "Commande à exécuter sur les workers :"
echo ""
sudo kubeadm token create --print-join-command
echo ""
