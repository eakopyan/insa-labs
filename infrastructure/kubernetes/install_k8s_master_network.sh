# Installation du réseau de Pods (Calico)
echo "Installation du réseau de Pods (Calico)..."

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
