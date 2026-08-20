```bash
#!/bin/bash

set -e

echo "========================================="
echo " Kubernetes - Configuration du Registry"
echo "========================================="

# --------------------------------------------------
# Vérification des arguments
# --------------------------------------------------

if [ "$#" -ne 1 ]; then
    echo "Usage : $0 <IP_REGISTRY>"
    echo "Exemple : $0 192.168.1.20"
    exit 1
fi

REGISTRY_IP="$1"
REGISTRY_PORT="5000"
REGISTRY="${REGISTRY_IP}:${REGISTRY_PORT}"

echo
echo "Registry configuré : ${REGISTRY}"

# --------------------------------------------------
# Vérification de containerd
# --------------------------------------------------

echo
echo "[1/4] Vérification de containerd..."

if ! command -v containerd >/dev/null 2>&1; then
    echo "Erreur : containerd n'est pas installé."
    echo "Exécutez d'abord install_k8s_master.sh."
    exit 1
fi

echo "containerd est installé."

# --------------------------------------------------
# Configuration de containerd
# --------------------------------------------------

echo
echo "[2/4] Configuration de containerd..."

REGISTRY_DIR="/etc/containerd/certs.d/${REGISTRY}"

sudo mkdir -p "${REGISTRY_DIR}"

sudo tee "${REGISTRY_DIR}/hosts.toml" > /dev/null <<EOF
server = "http://${REGISTRY}"

[host."http://${REGISTRY}"]
  capabilities = ["pull", "resolve", "push"]
EOF

echo "Configuration créée :"
echo "  ${REGISTRY_DIR}/hosts.toml"

# --------------------------------------------------
# Activation de la configuration hosts.toml
# --------------------------------------------------

echo
echo "[3/4] Activation de la configuration Registry..."

CONTAINERD_CONFIG="/etc/containerd/config.toml"

if [ ! -f "${CONTAINERD_CONFIG}" ]; then
    echo "Erreur : ${CONTAINERD_CONFIG} n'existe pas."
    exit 1
fi

# Vérifie si config_path est déjà configuré
if grep -q 'config_path = "/etc/containerd/certs.d"' "${CONTAINERD_CONFIG}"; then
    echo "config_path est déjà configuré."
else
    echo "Ajout de config_path à containerd..."

    sudo sed -i '/^\[plugins\."io\.containerd\.grpc\.v1\.cri"\.registry\]/a\    config_path = "/etc/containerd/certs.d"' \
        "${CONTAINERD_CONFIG}"
fi

# --------------------------------------------------
# Redémarrage de containerd
# --------------------------------------------------

echo
echo "[4/4] Redémarrage de containerd..."

sudo systemctl restart containerd
sudo systemctl enable containerd

if systemctl is-active --quiet containerd; then
    echo "containerd fonctionne correctement."
else
    echo "Erreur : containerd n'a pas pu redémarrer."
    sudo systemctl status containerd --no-pager
    exit 1
fi

# --------------------------------------------------
# Test de connexion au Registry
# --------------------------------------------------

echo
echo "========================================="
echo " Test du Registry"
echo "========================================="

if curl -fs "http://${REGISTRY}/v2/" >/dev/null; then
    echo "Registry accessible !"
else
    echo "Attention : le Registry n'est pas accessible."
    echo "Vérifiez :"
    echo "  - l'adresse IP du Registry"
    echo "  - le port ${REGISTRY_PORT}"
    echo "  - le réseau OpenStack"
    echo "  - le fonctionnement du Registry"
    exit 1
fi

echo
echo "========================================="
echo " Configuration terminée !"
echo "========================================="
echo
echo "Registry utilisé par containerd :"
echo "  ${REGISTRY}"
echo
echo "Les images peuvent maintenant être récupérées"
echo "depuis ce Registry par Kubernetes."
echo
```
