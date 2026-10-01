# Fiche de référence du lab

Aide-mémoire d'une page, à garder ouvert pendant l'administration ou la soutenance.

## Machines

| VM | IP | VLAN | Rôle | Services | Compte admin |
|----|----|------|------|----------|--------------|
| pfSense | WAN 10.4.0.198 | trunk | Pare-feu | NAT 8081 → 10.0.10.2:80 | `admin` (web) |
| WEB-01 | 10.0.10.1 | 301 | WordPress (référence fichiers) | apache2 | `<ADMIN_USER>` |
| HAProxy | 10.0.10.2 | 301 | Load-balancer | haproxy :80 :8080 :3306 :8404 | `haproxyadmin` |
| GLPI-01 | 10.0.10.3 | 301 | GLPI | apache2 | `<ADMIN_USER>` |
| WEB-02 | 10.0.10.4 | 301 | WordPress | apache2 | `<ADMIN_USER>` |
| MYSQL-01 | 10.0.20.1 | 302 | Galera (bootstrap initial) | mariadb | `<ADMIN_USER>` |
| MYSQL-02 | 10.0.20.2 | 302 | Galera | mariadb | `<ADMIN_USER>` |
| MYSQL-03 | 10.0.20.3 | 302 | Galera (sauvegardes) | mariadb | `<ADMIN_USER>` |
| ADM-01 | 10.0.30.1 | 303 | Administration, tests | ssh | `<ADMIN_USER>` |
| Guacamole | 10.0.30.2 | 303 | Bastion web | guacd, tomcat | `<ADMIN_USER>` |

## Comptes SQL

| Compte | Hôte | Base |
|--------|------|------|
| `wordpress` | 10.0.10.2 | `wordpress` |
| `glpi` | 10.0.10.2 | `glpi` |
| `haproxy_check` | 10.0.10.2 | — (aucun privilège) |

Mots de passe : gestionnaire de mots de passe uniquement.

## Commandes essentielles

| Machine | Objectif | Commande |
|---------|----------|----------|
| MYSQL-0X | État du nœud | `./scripts/validation/check-galera.sh` |
| MYSQL-0X | Journal | `sudo journalctl -u mariadb -n 50 --no-pager` |
| MYSQL-0X | État sauvegardé | `sudo cat /var/lib/mysql/grastate.dat` |
| MYSQL-0X | Redémarrer un nœud (cluster actif) | `sudo systemctl start mariadb` |
| MYSQL-0X | Bootstrap (cluster entièrement arrêté, 1 seul nœud) | `sudo galera_new_cluster` |
| HAPROXY | Synthèse | `./scripts/validation/check-haproxy.sh` |
| HAPROXY | Cluster vu par HAProxy | `./scripts/utilities/show-cluster-status.sh -w 5` |
| HAPROXY | Round-robin SQL | `./scripts/utilities/test-sql-round-robin.sh -n 9` |
| HAPROXY | Valider puis recharger | `sudo haproxy -c -f /etc/haproxy/haproxy.cfg && sudo systemctl reload haproxy` |
| WEB-0X | Valider puis recharger Apache | `sudo apachectl configtest && sudo systemctl reload apache2` |
| ADM-01 | Disponibilité web | `./scripts/validation/check-wordpress.sh` |
| ADM-01 | Backend ayant répondu | `curl -sI http://10.0.10.2 \| grep -i x-served-by` |
| ADM-01 | Réseau | `./scripts/validation/check-network.sh` |

## Valeurs Galera attendues

```text
wsrep_cluster_size        = 3
wsrep_cluster_status      = Primary
wsrep_local_state_comment = Synced
wsrep_ready               = ON
```

## Délais HAProxy

| Événement | Délai |
|-----------|-------|
| Détection d'une panne | ~9 s (`fall 3` × `inter 3s`) |
| Réintégration | ~6 s (`rise 2` × `inter 3s`) |
