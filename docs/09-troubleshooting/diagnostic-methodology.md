# Méthodologie de diagnostic

## Démarche

```text
1. Observer      Quel est le symptôme exact ? (message, code, depuis quand, qui est touché)
2. Délimiter     Quel maillon de la chaîne ? (client → pfSense → HAProxy → web → HAProxy → Galera)
3. Hypothèses    Quelles causes possibles, de la plus probable à la moins probable ?
4. Tester        Une hypothèse à la fois, avec une commande dont le résultat est sans ambiguïté
5. Corriger      Le minimum nécessaire, en sauvegardant avant de modifier
6. Valider       Rejouer le test qui échouait + les tests de non-régression
7. Documenter    incidents.md
```

## Suivre la chaîne

Pour WordPress, tester chaque maillon **de l'intérieur vers l'extérieur** :

| # | Maillon | Commande | Machine |
|---|---------|----------|---------|
| 1 | Galera | `./scripts/validation/check-galera.sh` | MYSQL-0X |
| 2 | HAProxy → Galera | `nc -zv 10.0.20.1 3306` | HAPROXY |
| 3 | SQL via HAProxy | `mariadb -h 10.0.10.2 -u wordpress -p -e 'SELECT 1'` | WEB-01 |
| 4 | Apache/PHP local | `curl -sI http://localhost/wp-login.php` | WEB-01 |
| 5 | HAProxy → web | `curl -sI http://10.0.10.1/` | HAPROXY |
| 6 | Point d'entrée | `curl -sI http://10.0.10.2/` | ADM-01 |
| 7 | NAT | `curl -sI http://10.4.0.198:8081/` | Poste labo |

Le premier maillon en échec localise le problème.

## Lire les messages réseau

| Message | Signification | Où chercher |
|---------|---------------|-------------|
| `Connection refused` | Le paquet est arrivé, rien n'écoute sur ce port/IP | Service arrêté, `bind-address`, mauvais port |
| `Connection timed out` | Aucune réponse : paquet bloqué ou perdu | Pare-feu (pfSense, nftables), routage, VM éteinte |
| `No route to host` | Pas de chemin ou hôte injoignable en couche 2 | IP, passerelle, VLAN |
| `Name or service not known` | Résolution DNS impossible | `/etc/resolv.conf`, DNS pfSense |
| HTTP `503` (HAProxy) | Aucun serveur sain dans le backend | Health-checks, backends |
| HTTP `502` (HAProxy) | Réponse invalide du backend | Apache/PHP plante |
| HTTP `404` | Ressource introuvable | DocumentRoot, réécriture |
| HTTP `500` | Erreur applicative | Journal Apache / PHP |

## Boîte à outils

| Besoin | Commande |
|--------|----------|
| État d'un service | `systemctl status <service> --no-pager` |
| Journal d'un service | `journalctl -u <service> -n 50 --no-pager` (`-f` en direct) |
| Ports en écoute | `sudo ss -ltnp` |
| Test de port distant | `nc -zv -w 3 <ip> <port>` |
| Test HTTP | `curl -sI <url>` ; `curl -v <url>` |
| IP et routes | `ip -4 addr` ; `ip route` |
| Résolution | `getent hosts <nom>` |
| Espace disque | `df -h` ; `du -sh /var/lib/mysql` |
| Configuration Apache | `apachectl configtest` ; `apache2ctl -S` |
| Configuration HAProxy | `haproxy -c -f /etc/haproxy/haproxy.cfg` |

## Bonnes pratiques

- **Une modification à la fois**, puis test : sinon impossible de savoir laquelle a corrigé (ou aggravé).
- **Sauvegarder** un fichier avant de le modifier (`cp fichier fichier.$(date +%F).orig`).
- **Snapshot Proxmox** avant une opération risquée (bootstrap Galera, changement de règles).
- **Noter** les commandes et résultats au fil de l'eau : c'est la matière de [incidents.md](incidents.md).
