#!/bin/bash

set -e

echo "========================================="
echo " Kubernetes - Préparation d'un worker"
echo "========================================="

# Désactiver le swap
echo "[1/5] Désactivation du swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Configuration des modules réseau
echo "[2/5] Configuration du réseau..."
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
echo "[3/5] Installation de containerd..."
sudo apt-get update
sudo apt-get install -y containerd

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null

sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' \
    /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd

# Installation de Kubernetes
echo "[4/5] Installation de Kubernetes..."
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

sudo mkdir -p -m 755 /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key \
    | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' \
    | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl

sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl enable kubelet

echo "[5/5] Préparation terminée !"

echo ""
echo "========================================="
echo " Le worker est prêt."
echo "========================================="
echo ""
echo "Sur le master, exécutez :"
echo ""
echo "    kubeadm token create --print-join-command"
echo ""
echo "Puis exécutez la commande obtenue ici avec sudo."
echo ""
