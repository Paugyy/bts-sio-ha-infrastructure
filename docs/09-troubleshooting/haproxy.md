# Dépannage — HAProxy

## 503 Service Unavailable

| Élément | Contenu |
|---------|---------|
| **Symptôme** | `curl -I http://10.0.10.2` → `HTTP/1.1 503 Service Unavailable` |
| **Cause probable** | Tous les serveurs du backend sont DOWN (Apache arrêté, health-check en échec, base inaccessible) |
| **Diagnostic** | Pourquoi le health-check échoue-t-il ? |
| **Commandes** | **SUR HAPROXY** `./scripts/validation/check-haproxy.sh` ; `sudo journalctl -u haproxy -n 30 --no-pager \| grep -i down` ; `curl -sI -H 'Host: 10.0.10.2' http://10.0.10.1/wp-login.php` |
| **Correction** | Réparer le backend (service, PHP, base) ou corriger l'URI / le code attendu du health-check |
| **Validation** | `check-wordpress.sh` : HAProxy UP |

## HAProxy ne démarre pas

| Élément | Contenu |
|---------|---------|
| **Symptôme** | `systemctl start haproxy` échoue |
| **Cause probable** | Erreur de syntaxe ; IP `10.0.10.2` absente ; port déjà utilisé (Apache ou MariaDB installés sur la VM HAProxy) |
| **Commandes** | `sudo haproxy -c -f /etc/haproxy/haproxy.cfg` ; `ip -4 addr` ; `sudo ss -ltnp \| grep -E ':(80\|3306\|8080)\b'` |
| **Correction** | Corriger la ligne signalée ; libérer le port (`sudo systemctl disable --now apache2`) |
| **Validation** | `systemctl is-active haproxy` → `active` |

## Backends SQL DOWN

| Élément | Contenu |
|---------|---------|
| **Symptôme** | Les 3 serveurs `galera_cluster` DOWN, alors que Galera est sain |
| **Cause probable** | Compte `haproxy_check` absent ou créé pour un autre hôte ; règle pfSense HAProxy → 3306 absente ; hôte bloqué par MariaDB |
| **Commandes** | **SUR HAPROXY** `nc -zv 10.0.20.1 3306` ; `mariadb -h 10.0.20.1 -u haproxy_check -e 'SELECT 1'` |
| **Correction** | `CREATE USER 'haproxy_check'@'10.0.10.2';` ; règle pfSense ; **SUR LE NŒUD** `sudo mariadb-admin flush-hosts` si `Host '10.0.10.2' is blocked` |
| **Validation** | `check-haproxy.sh` : MYSQL-01/02/03 UP |

## Un serveur oscille UP/DOWN (flapping)

| Élément | Contenu |
|---------|---------|
| **Symptôme** | Journal : alternance `is DOWN` / `is UP` |
| **Cause probable** | Serveur surchargé, health-check trop exigeant (`timeout check` court), réseau instable |
| **Commandes** | `sudo journalctl -u haproxy --since '10 min ago' \| grep -E 'UP\|DOWN'` ; **SUR LE BACKEND** `uptime`, `free -m` |
| **Correction** | Traiter la charge ; ajuster `inter`, `fall`, `timeout check` |
| **Validation** | Plus d'oscillation sur 10 minutes |

## Page de statistiques inaccessible

| Élément | Contenu |
|---------|---------|
| **Symptôme** | `http://10.0.10.2:8404/stats` : `403 Forbidden` ou timeout |
| **Cause probable** | `403` : requête hors de vADMIN (ACL `from_admin`) ; timeout : règle pfSense absente |
| **Commandes** | **SUR ADM-01** `curl -sI http://10.0.10.2:8404/stats` |
| **Correction** | Accéder depuis ADM-01 ou Guacamole ; règle vADMIN → 8404 |
| **Validation** | `401` (authentification demandée) puis page affichée avec le mot de passe |
