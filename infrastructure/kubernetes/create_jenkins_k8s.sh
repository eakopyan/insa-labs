```bash id="q5qj5h"
#!/bin/bash

set -e

echo "========================================="
echo " Kubernetes - Accès Jenkins"
echo "========================================="

# --------------------------------------------------
# Configuration
# --------------------------------------------------

NAMESPACE="devops"
SERVICE_ACCOUNT="jenkins-deployer"
ROLE_NAME="jenkins-deployer"
OUTPUT_FILE="./jenkins-kubeconfig"

echo
echo "Namespace        : ${NAMESPACE}"
echo "ServiceAccount   : ${SERVICE_ACCOUNT}"
echo "Kubeconfig       : ${OUTPUT_FILE}"

# --------------------------------------------------
# Vérification
# --------------------------------------------------

if [ "$EUID" -ne 0 ]; then
    echo
    echo "Erreur : ce script doit être exécuté avec sudo ou en root."
    exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
    echo
    echo "Erreur : kubectl n'est pas installé."
    exit 1
fi

# Vérification que kubectl fonctionne
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo
    echo "Erreur : impossible de contacter le cluster Kubernetes."
    exit 1
fi

# --------------------------------------------------
# 1. Création du namespace
# --------------------------------------------------

echo
echo "[1/6] Création du namespace..."

kubectl create namespace "${NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "Namespace ${NAMESPACE} prêt."

# --------------------------------------------------
# 2. Création du ServiceAccount
# --------------------------------------------------

echo
echo "[2/6] Création du ServiceAccount..."

kubectl create serviceaccount "${SERVICE_ACCOUNT}" \
    --namespace="${NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "ServiceAccount ${SERVICE_ACCOUNT} prêt."

# --------------------------------------------------
# 3. Création du Role
# --------------------------------------------------

echo
echo "[3/6] Création du Role..."

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ${ROLE_NAME}
  namespace: ${NAMESPACE}
rules:

  # Deployments
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]

  # Pods
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]

  # Services
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]

  # ReplicaSets
  - apiGroups: ["apps"]
    resources: ["replicasets"]
    verbs: ["get", "list", "watch"]
EOF

echo "Role ${ROLE_NAME} créé."

# --------------------------------------------------
# 4. Création du RoleBinding
# --------------------------------------------------

echo
echo "[4/6] Création du RoleBinding..."

kubectl create rolebinding "${ROLE_NAME}" \
    --namespace="${NAMESPACE}" \
    --role="${ROLE_NAME}" \
    --serviceaccount="${NAMESPACE}:${SERVICE_ACCOUNT}" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "RoleBinding créé."

# --------------------------------------------------
# 5. Génération du token et du kubeconfig
# --------------------------------------------------

echo
echo "[5/6] Génération du kubeconfig Jenkins..."

# Récupération du token du ServiceAccount
TOKEN=$(kubectl create token \
    "${SERVICE_ACCOUNT}" \
    --namespace="${NAMESPACE}")

if [ -z "${TOKEN}" ]; then
    echo "Erreur : impossible de générer le token."
    exit 1
fi

# Adresse du serveur Kubernetes
SERVER=$(kubectl config view \
    --minify \
    -o jsonpath='{.clusters[0].cluster.server}')

# Récupération du certificat CA
CA_DATA=$(kubectl config view \
    --raw \
    --minify \
    -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')

# Génération du kubeconfig
cat > "${OUTPUT_FILE}" <<EOF
apiVersion: v1
kind: Config

clusters:
  - name: kubernetes
    cluster:
      server: ${SERVER}
      certificate-authority-data: ${CA_DATA}

users:
  - name: ${SERVICE_ACCOUNT}
    user:
      token: ${TOKEN}

contexts:
  - name: jenkins
    context:
      cluster: kubernetes
      namespace: ${NAMESPACE}
      user: ${SERVICE_ACCOUNT}

current-context: jenkins
EOF

chmod 600 "${OUTPUT_FILE}"

echo
echo "Kubeconfig généré :"
echo "  ${OUTPUT_FILE}"

# --------------------------------------------------
# 6. Vérification des permissions
# --------------------------------------------------

echo
echo "[6/6] Vérification des permissions..."

echo
echo "Permissions sur les Deployments :"

kubectl auth can-i \
    --as="system:serviceaccount:${NAMESPACE}:${SERVICE_ACCOUNT}" \
    get deployments \
    --namespace="${NAMESPACE}"

kubectl auth can-i \
    --as="system:serviceaccount:${NAMESPACE}:${SERVICE_ACCOUNT}" \
    create deployments \
    --namespace="${NAMESPACE}"

echo
echo "Permissions sur les Services :"

kubectl auth can-i \
    --as="system:serviceaccount:${NAMESPACE}:${SERVICE_ACCOUNT}" \
    get services \
    --namespace="${NAMESPACE}"

kubectl auth can-i \
    --as="system:serviceaccount:${NAMESPACE}:${SERVICE_ACCOUNT}" \
    create services \
    --namespace="${NAMESPACE}"

echo
echo "Permissions sur le cluster :"

kubectl auth can-i \
    --as="system:serviceaccount:${NAMESPACE}:${SERVICE_ACCOUNT}" \
    get nodes \
    --all-namespaces

echo
echo "========================================="
echo " Configuration terminée !"
echo "========================================="
echo
echo "Namespace :"
echo "  ${NAMESPACE}"
echo
echo "ServiceAccount :"
echo "  ${SERVICE_ACCOUNT}"
echo
echo "Kubeconfig Jenkins :"
echo "  ${OUTPUT_FILE}"
echo
echo "IMPORTANT : ce fichier contient un token"
echo "permettant à Jenkins d'accéder au cluster."
echo "Ne pas le publier dans Git."
echo
echo "Copiez ensuite ce fichier sur la VM Jenkins"
echo "et exécutez :"
echo
echo "  sudo ./configure_jenkins_k8s.sh ${OUTPUT_FILE}"
echo
```
