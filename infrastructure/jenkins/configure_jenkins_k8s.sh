```bash
#!/bin/bash

set -e

echo "========================================="
echo " Jenkins - Configuration de Kubernetes"
echo "========================================="

# --------------------------------------------------
# Vérification des droits
# --------------------------------------------------

if [ "$EUID" -ne 0 ]; then
    echo "Erreur : ce script doit être exécuté avec sudo ou en root."
    exit 1
fi

# --------------------------------------------------
# Vérification des arguments
# --------------------------------------------------

if [ "$#" -ne 1 ]; then
    echo "Usage : $0 <KUBECONFIG>"
    echo
    echo "Exemple :"
    echo "  sudo $0 /tmp/jenkins-kubeconfig"
    exit 1
fi

KUBECONFIG_SOURCE="$1"

if [ ! -f "$KUBECONFIG_SOURCE" ]; then
    echo "Erreur : le fichier kubeconfig n'existe pas :"
    echo "  $KUBECONFIG_SOURCE"
    exit 1
fi

# --------------------------------------------------
# Vérification de kubectl
# --------------------------------------------------

echo
echo "[1/4] Vérification de kubectl..."

if ! command -v kubectl >/dev/null 2>&1; then
    echo "Erreur : kubectl n'est pas installé."
    echo "Exécutez d'abord install_jenkins.sh."
    exit 1
fi

echo "kubectl est installé :"
kubectl version --client

# --------------------------------------------------
# Installation du kubeconfig pour Jenkins
# --------------------------------------------------

echo
echo "[2/4] Installation du kubeconfig..."

JENKINS_HOME="/var/lib/jenkins"
KUBE_DIR="${JENKINS_HOME}/.kube"
KUBE_CONFIG="${KUBE_DIR}/config"

mkdir -p "$KUBE_DIR"

cp "$KUBECONFIG_SOURCE" "$KUBE_CONFIG"

chown -R jenkins:jenkins "$KUBE_DIR"
chmod 700 "$KUBE_DIR"
chmod 600 "$KUBE_CONFIG"

echo "Kubeconfig installé dans :"
echo "  $KUBE_CONFIG"

# --------------------------------------------------
# Test de connexion au cluster
# --------------------------------------------------

echo
echo "[3/4] Test de connexion au cluster Kubernetes..."

if sudo -u jenkins kubectl \
    --kubeconfig="$KUBE_CONFIG" \
    cluster-info >/dev/null 2>&1; then

    echo "Connexion au cluster Kubernetes réussie."

else

    echo "Erreur : Jenkins ne peut pas contacter Kubernetes."
    echo
    echo "Informations de diagnostic :"
    sudo -u jenkins kubectl \
        --kubeconfig="$KUBE_CONFIG" \
        cluster-info

    exit 1
fi

# --------------------------------------------------
# Vérification des permissions
# --------------------------------------------------

echo
echo "[4/4] Vérification des permissions..."

if sudo -u jenkins kubectl \
    --kubeconfig="$KUBE_CONFIG" \
    auth can-i get deployments; then

    echo "Jenkins peut accéder aux Deployments."

else

    echo "Attention : Jenkins ne possède pas les permissions"
    echo "nécessaires pour gérer les Deployments."
    exit 1
fi

if sudo -u jenkins kubectl \
    --kubeconfig="$KUBE_CONFIG" \
    auth can-i create deployments; then

    echo "Jenkins peut créer des Deployments."

else

    echo "Attention : Jenkins ne peut pas créer de Deployments."
    exit 1
fi

echo
echo "========================================="
echo " Configuration terminée !"
echo "========================================="
echo
echo "Jenkins peut maintenant utiliser Kubernetes"
echo "avec le kubeconfig :"
echo
echo "    $KUBE_CONFIG"
echo
echo "Test manuel :"
echo
echo "    sudo -u jenkins kubectl get pods"
echo
```
