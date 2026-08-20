# 1. Installer le Docker Registry

Créez une VM `VM-Registry` (flavor `tiny`) qui hébergera le Docker Registry. Clonez le dépôt Git, puis :

```Bash
cd infrastructure/registry
sudo ./install_registry.sh
```

Ce script installe Docker et lance le Registry sur le port 5000, avec un volume persistant. Récupérez ensuite l'adresse IP de la VM :

```Bash
hostname -I
```

Cette adresse sera utilisée dans la configuration de Kubernetes et Jenkins.

---

# 2. Installer le master Kubernetes

Pour le TP DevOps, vous n'avez besoin que d'un **noeud master**. Créez une VM `VM-K8s` (flavor `medium`) et clonez le dépôt Git. Puis :

```Bash
cd infrastructure/kubernetes
sudo ./install_k8s_master.sh
``` 

Le script installe le runtime `containerd`, Kubernetes version 1.36, initialise le cluster et configure `kubectl`.

Ensuite, configurez le Registry pour qu'il soit accessible par Kubernetes :

```Bash
sudo ./configure_registry.sh <IP_REGISTRY>
```

en utilisant l'adresse IP de `VM-Registry`.

---

# 3. Créer l'accès Jenkins à Kubernetes

Avant d'installer Jenkins, il faut lui prévoir un accès au master Kubernetes. Depuis `VM-K8s` :

```Bash
sudo ./create_jenkins_k8s.sh
```

Le script génère un fichier exécutable nommé `./jenkins-kubeconfig` qui contient un token permettant à Jenkins d'accéder au cluster. Vous devrez ensuite transférer ce fichier sur la VM contenant Jenkins.

---

# 4. Installer Jenkins

Créez une nouvelle VM `VM-Jenkins` (flavor `medium`) qui hébergera le serveur Jenkins. Clonez le dépôt, puis :

```Bash
cd infrastructure/jenkins
sudo ./install_jenkins.sh
```

Le script installe Java, Jenkins, Docker et `kubectl`, et ajoute `jenkins` au groupe Docker.

Ensuite, configurez l'accès au Registry :

```Bash
sudo ./configure_jenkins_registry.sh <IP_REGISTRY>
```

en utilisant l'adresse IP de `VM-Registry`. Cela permet de configurer Docker afin qu'il accepte l'accès au Registry via HTTP.

Enfin, configurez l'accès du serveur Jenkins au cluster Kubernetes. Récupérez le fichier `./jenkins-kubeconfig` produit sur `VM-K8s`, puis :

```Bash
sudo ./configure_jenkins_k8s.sh /chemin/vers/jenkins-kubeconfig
```

La connexion devrait être autorisée.

---

# 5. Vérification finale

Pour s'assurer que le Registry fonctionne bien avec Jenkins et Kubernetes, chargez une image depuis Docker et placez-là sur le Registry. Depuis `VM-Jenkins` :

```Bash
docker pull hello-world
docker tag hello-world <IP_REGISTRY>:5000/test:1.0
docker push <IP_REGISTRY>:5000/test:1.0
```

Cela créera une image `test:1.0` dans le Registry.

Puis, depuis `VM-K8s`, chargez cette même image depuis le Registry :

```Bash
sudo ctr images pull --plain-http \
    <IP_REGISTRY>:5000/test:1.0
```

Si cela fonctionne, félicitations ! Vous aurez *moins* de problèmes.