```bash
#!/bin/bash

set -e

echo "========================================="
echo " Jenkins - Installation"
echo "========================================="

# --------------------------------------------------
# Vérification des droits
# --------------------------------------------------

if [ "$EUID" -ne 0 ]; then
    echo "Erreur : ce script doit être exécuté avec sudo ou en root."
    exit 1
fi

# --------------------------------------------------
# 1. Installation de Java
# --------------------------------------------------

echo
echo "[1/5] Installation de Java..."

apt-get update
apt-get install -y fontconfig openjdk-17-jre

echo "Java installé :"
java -version

# --------------------------------------------------
# 2. Installation de Jenkins
# --------------------------------------------------

echo
echo "[2/5] Installation de Jenkins..."

mkdir -p /etc/apt/keyrings

curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key \
    -o /etc/apt/keyrings/jenkins-keyring.asc

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] \
https://pkg.jenkins.io/debian-stable binary/" \
    > /etc/apt/sources.list.d/jenkins.list

apt-get update
apt-get install -y jenkins

systemctl enable jenkins
systemctl start jenkins

echo "Jenkins installé."

# --------------------------------------------------
# 3. Installation de Docker
# --------------------------------------------------

echo
echo "[3/5] Installation de Docker..."

if command -v docker >/dev/null 2>&1; then
    echo "Docker est déjà installé."
else
    apt-get install -y docker.io
fi

systemctl enable docker
systemctl start docker

echo "Docker installé."

# --------------------------------------------------
# 4. Autorisation de Jenkins à utiliser Docker
# --------------------------------------------------

echo
echo "[4/5] Configuration de l'accès Docker pour Jenkins..."

if getent group docker >/dev/null 2>&1; then
    echo "Le groupe docker existe déjà."
else
    groupadd docker
fi

usermod -aG docker jenkins

systemctl restart docker
systemctl restart jenkins

echo "Jenkins peut maintenant utiliser Docker."

# --------------------------------------------------
# 5. Installation de kubectl
# --------------------------------------------------

echo
echo "[5/5] Installation de kubectl..."

if command -v kubectl >/dev/null 2>&1; then
    echo "kubectl est déjà installé."
else

    mkdir -p -m 755 /etc/apt/keyrings

    curl -fsSL \
        https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key \
        | gpg --dearmor \
        -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' \
        > /etc/apt/sources.list.d/kubernetes.list

    apt-get update
    apt-get install -y kubectl

fi

echo "kubectl installé :"
kubectl version --client

# --------------------------------------------------
# Vérifications finales
# --------------------------------------------------

echo
echo "========================================="
echo " Vérification de l'installation"
echo "========================================="

echo
echo "Java :"
java -version

echo
echo "Docker :"
docker --version

echo
echo "kubectl :"
kubectl version --client

echo
echo "Jenkins :"
systemctl is-active jenkins

echo
echo "========================================="
echo " Installation terminée !"
echo "========================================="

IP=$(hostname -I | awk '{print $1}')

echo
echo "Jenkins devrait être accessible depuis :"
echo
echo "    http://${IP}:8080"
echo

echo "Mot de passe initial Jenkins :"
echo
echo "    sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
echo
```
