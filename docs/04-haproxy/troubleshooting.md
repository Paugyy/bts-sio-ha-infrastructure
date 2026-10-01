# HAProxy — Dépannage

Fiches complètes : [09-troubleshooting/haproxy.md](../09-troubleshooting/haproxy.md)

## Réflexes

```bash
# SUR HAPROXY
sudo haproxy -c -f /etc/haproxy/haproxy.cfg      # syntaxe
sudo systemctl status haproxy --no-pager         # état du service
sudo journalctl -u haproxy -n 50 --no-pager      # journal
sudo ss -ltnp | grep haproxy                     # ports en écoute
./scripts/validation/check-haproxy.sh            # synthèse + état des backends
```

## Symptômes fréquents

| Symptôme | Cause probable | Vérification | Correction |
|----------|----------------|--------------|------------|
| `503 Service Unavailable` | Tous les serveurs du backend DOWN | `check-haproxy.sh` | Réparer les backends (Apache, PHP, base) |
| Service ne démarre pas : `cannot bind socket [10.0.10.2:80]` | IP absente de la VM, ou port déjà pris (Apache installé sur HAProxy ?) | `ip a`, `ss -ltnp \| grep :80` | Corriger l'IP / désinstaller le service concurrent |
| Backend WordPress DOWN alors que le site répond en direct | Health-check reçoit `404`/`500` (URI, Host) | `curl -I -H 'Host: 10.0.10.2' http://10.0.10.1/wp-login.php` | Adapter `http-check send` ou `expect` |
| Backend SQL DOWN : `mysql-check` en échec | Compte `haproxy_check` absent ou mauvais hôte | `mariadb -h 10.0.20.1 -u haproxy_check -e 'SELECT 1'` | `CREATE USER 'haproxy_check'@'10.0.10.2';` |
| Nœuds bloqués après trop de checks échoués | `Host '10.0.10.2' is blocked because of many connection errors` | Journal MariaDB | `sudo mariadb-admin flush-hosts` sur le nœud ; corriger la cause |
| Une seule machine répond toujours | Cookie de persistance dans le navigateur | `curl` sans cookie | Comportement normal |
| `reload` sans effet | Erreur de syntaxe : ancienne config conservée | `haproxy -c` | Corriger, puis `reload` |
