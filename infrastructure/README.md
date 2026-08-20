# 1. Installer...


---

# Quelques vérifications

Pour s'assurer que le Registry fonctionne bien avec Jenkins et Kubernetes, chargez une image depuis Docker et placez-là se le Registry :

```Bash
docker pull hello-world
docker tag hello-world <IP_REGISTRY>:5000/test:1.0
docker push <IP_REGISTRY>:5000/test:1.0
```

Cela créera une image `test:1.0` dans le Registry.

Puis, depuis la VM Kubernetes, chargez cette même image depuis le Registry :

```Bash
sudo ctr images pull --plain-http \
    <IP_REGISTRY>:5000/test:1.0
```

Si cela fonctionne, bravo ! Vous aurez *moins* de problèmes.