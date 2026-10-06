#!/bin/bash

set -e

echo "========================================="
echo " Kubernetes - Installation du master"
echo "========================================="

# Désactiver le swap
echo "[1/8] Désactivation du swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab


# Configuration des modules réseau
echo "[2/8] Configuration du réseau..."
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
echo "[3/8] Installation de containerd..."
sudo apt-get update
sudo apt-get install -y containerd

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null

sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' \
    /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd


# Installation de Kubernetes
echo "[4/8] Installation de Kubernetes..."

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


# Initialisation du cluster
echo "[5/8] Initialisation du cluster Kubernetes..."

MASTER_IP=$(hostname -I | awk '{print $1}')

sudo kubeadm init \
    --apiserver-advertise-address="${MASTER_IP}" \
    --pod-network-cidr=192.168.0.0/16

# Commandes supplémentaires suite à des bugs d'installation
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Installation du réseau de Pods (Calico)
echo "[6/8] Installation du réseau de Pods (Calico)..."

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.33.0/manifests/v3_projectcalico_org.yaml

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.33.0/manifests/tigera-operator.yaml

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.33.0/manifests/custom-resources.yaml


# Helm
echo " Installation de Helm..."

if ! command -v helm >/dev/null 2>&1; then
    sudo snap install helm --classic
fi


# Traefik
echo " Installation du Ingress Controller Traefik..."

helm repo add traefik https://traefik.github.io/charts
helm repo update

helm upgrade --install traefik traefik/traefik \
    --namespace traefik \
    --create-namespace \
    --values "$(dirname "$0")/traefik-values.yaml" \
    --wait


# Configuration de kubectl
echo "[7/8] Configuration de kubectl..."

mkdir -p "$HOME/.kube"
sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

# Génération de la commande join
echo "[8/8] Génération de la commande pour les workers..."

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
