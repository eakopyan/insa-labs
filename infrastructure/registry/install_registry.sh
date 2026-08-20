#!/bin/bash

set -e

REGISTRY_NAME="registry"
REGISTRY_IMAGE="registry:2"
REGISTRY_PORT="5000"

echo "=========================================="
echo " Installation du Docker Registry"
echo "=========================================="

# Vérification des droits root
if [ "$EUID" -ne 0 ]; then
    echo "Erreur : ce script doit être exécuté avec sudo ou en root."
    exit 1
fi

# --------------------------------------------------
# 1. Installation de Docker
# --------------------------------------------------

echo
echo "[1/4] Installation de Docker..."

if command -v docker >/dev/null 2>&1; then
    echo "Docker est déjà installé."
else
    echo "Installation de Docker..."

    apt-get update
    apt-get install -y docker.io

    systemctl enable docker
    systemctl start docker

    echo "Docker installé avec succès."
fi

# Vérification que Docker fonctionne
if ! systemctl is-active --quiet docker; then
    echo "Erreur : le service Docker ne fonctionne pas."
    exit 1
fi

# --------------------------------------------------
# 2. Création du volume de données
# --------------------------------------------------

echo
echo "[2/4] Préparation du stockage du Registry..."

if docker volume inspect registry-data >/dev/null 2>&1; then
    echo "Le volume registry-data existe déjà."
else
    docker volume create registry-data
    echo "Volume registry-data créé."
fi

# --------------------------------------------------
# 3. Téléchargement de l'image Registry
# --------------------------------------------------

echo
echo "[3/4] Téléchargement de l'image Docker Registry..."

docker pull "$REGISTRY_IMAGE"

# --------------------------------------------------
# 4. Lancement du Registry
# --------------------------------------------------

echo
echo "[4/4] Démarrage du Registry..."

if docker ps -a --format '{{.Names}}' | grep -q "^${REGISTRY_NAME}$"; then

    if docker ps --format '{{.Names}}' | grep -q "^${REGISTRY_NAME}$"; then
        echo "Le Registry est déjà en cours d'exécution."
    else
        echo "Le conteneur Registry existe mais est arrêté."
        docker start "$REGISTRY_NAME"
    fi

else

    docker run -d \
        --name "$REGISTRY_NAME" \
        --restart unless-stopped \
        -p "$REGISTRY_PORT:5000" \
        -v registry-data:/var/lib/registry \
        "$REGISTRY_IMAGE"

fi

# --------------------------------------------------
# Vérification
# --------------------------------------------------

echo
echo "=========================================="
echo " Vérification du Registry"
echo "=========================================="

sleep 2

if curl -fs http://localhost:$REGISTRY_PORT/v2/ >/dev/null; then
    echo "Registry opérationnel !"
else
    echo "Erreur : le Registry ne répond pas."
    echo
    echo "Logs du conteneur :"
    docker logs "$REGISTRY_NAME"
    exit 1
fi

IP=$(hostname -I | awk '{print $1}')

echo
echo "Registry disponible à l'adresse :"
echo
echo "    http://$IP:$REGISTRY_PORT"
echo
echo "Test possible depuis une autre VM :"
echo
echo "    curl http://$IP:$REGISTRY_PORT/v2/"
echo
echo "=========================================="
echo " Installation terminée"
echo "=========================================="