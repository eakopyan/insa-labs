```bash
#!/bin/bash

set -e

echo "========================================="
echo " Jenkins - Configuration du Registry"
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
# Vérification de Docker
# --------------------------------------------------

echo
echo "[1/4] Vérification de Docker..."

if ! command -v docker >/dev/null 2>&1; then
    echo "Erreur : Docker n'est pas installé."
    echo "Exécutez d'abord install_jenkins.sh."
    exit 1
fi

if ! systemctl is-active --quiet docker; then
    echo "Erreur : le service Docker ne fonctionne pas."
    exit 1
fi

echo "Docker est opérationnel."

# --------------------------------------------------
# Configuration du Registry HTTP
# --------------------------------------------------

echo
echo "[2/4] Configuration du Registry HTTP..."

DOCKER_CONFIG="/etc/docker/daemon.json"

# Création du fichier s'il n'existe pas
if [ ! -f "$DOCKER_CONFIG" ]; then
    echo '{}' | sudo tee "$DOCKER_CONFIG" >/dev/null
fi

# Utilisation de Python pour modifier proprement le JSON
python3 - "$DOCKER_CONFIG" "$REGISTRY" <<'PY'
import json
import sys

config_file = sys.argv[1]
registry = sys.argv[2]

with open(config_file, "r") as f:
    config = json.load(f)

registries = config.setdefault("insecure-registries", [])

if registry not in registries:
    registries.append(registry)

with open(config_file, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
PY

echo "Configuration Docker :"
cat "$DOCKER_CONFIG"

# --------------------------------------------------
# Redémarrage de Docker
# --------------------------------------------------

echo
echo "[3/4] Redémarrage de Docker..."

systemctl restart docker

if systemctl is-active --quiet docker; then
    echo "Docker fonctionne correctement."
else
    echo "Erreur : Docker n'a pas pu redémarrer."
    systemctl status docker --no-pager
    exit 1
fi

# --------------------------------------------------
# Test du Registry
# --------------------------------------------------

echo
echo "[4/4] Test de connexion au Registry..."

if curl -fs "http://${REGISTRY}/v2/" >/dev/null; then
    echo "Registry accessible !"
else
    echo "Erreur : le Registry n'est pas accessible."
    echo
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
echo "Docker accepte maintenant le Registry HTTP :"
echo
echo "    ${REGISTRY}"
echo
echo "Jenkins pourra utiliser :"
echo
echo "    docker push ${REGISTRY}/<image>:<version>"
echo
```
