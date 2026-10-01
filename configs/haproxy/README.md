# Configuration HAProxy

| Fichier | Cible sur la VM | VM |
|---------|-----------------|----|
| [`haproxy.cfg.example`](haproxy.cfg.example) | `/etc/haproxy/haproxy.cfg` | HAPROXY (10.0.10.2) |

## Déploiement

```bash
# SUR HAPROXY
sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.$(date +%F).orig   # sauvegarde de l'existant
sudo cp configs/haproxy/haproxy.cfg.example /etc/haproxy/haproxy.cfg
sudo nano /etc/haproxy/haproxy.cfg                                        # remplacer <PASSWORD>
sudo haproxy -c -f /etc/haproxy/haproxy.cfg                               # doit afficher "Configuration file is valid"
sudo systemctl reload haproxy
```

## Placeholders

| Placeholder | Signification |
|-------------|---------------|
| `<PASSWORD>` | Mot de passe de la page de statistiques (`stats auth admin:<PASSWORD>`) |

## Prérequis côté Galera

Le health-check `mysql-check` utilise un compte **sans mot de passe et sans privilège**, limité à l'IP de HAProxy. À créer une seule fois (réplication Galera) :

```sql
-- SUR MYSQL-01 (sudo mariadb)
CREATE USER 'haproxy_check'@'10.0.10.2';
-- Aucun GRANT : le compte peut seulement ouvrir une session.
```

## Points de conception

| Choix | Justification | Limite |
|-------|---------------|--------|
| `balance roundrobin` HTTP | Répartition égale, serveurs identiques | — |
| `option httpchk` sur `/wp-login.php` | Teste PHP **et** la base, pas seulement Apache | Un peu plus coûteux qu'un check TCP |
| Cookie `SRV_WP` | Garde un administrateur connecté sur le même serveur | Redistribué si le serveur tombe (`option redispatch`) |
| `X-Served-By` | Rend le failover visible avec `curl -I` | Révèle le nom du backend : à retirer en production |
| `mysql-check` | Natif, sans dépendance | Ne détecte pas un nœud `Donor/Desynced` |
| Round-robin SQL | Démontre le multi-maître | Conflits de certification possibles en forte écriture |

Documentation détaillée : [docs/04-haproxy/](../../docs/04-haproxy/installation.md)
