# Sécurité — Moindre privilège

Chaque compte ne dispose que des droits strictement nécessaires à sa fonction.

## Comptes SQL

| Compte | Hôte | Privilèges | Justification |
|--------|------|------------|---------------|
| `root` | `localhost` (unix_socket) | Tous | Administration locale via `sudo mariadb` uniquement ; pas d'accès réseau |
| `wordpress` | `10.0.10.2` | `ALL ON wordpress.*` | WordPress crée/modifie ses tables lors des mises à jour |
| `glpi` | `10.0.10.2` | `ALL ON glpi.*` + `SELECT ON mysql.time_zone_name` | Idem pour GLPI + fuseaux horaires |
| `haproxy_check` | `10.0.10.2` | Aucun (`USAGE`) | Health-check : ouverture de session seulement |

Ce qui est **évité** :

- `GRANT ALL ON *.*` à un compte applicatif ;
- l'hôte `'%'` (n'importe quelle origine) ;
- le compte `root` utilisé par une application.

### Contrôle

**SUR MYSQL-01**

```sql
SELECT user, host FROM mysql.user ORDER BY user;
SHOW GRANTS FOR 'wordpress'@'10.0.10.2';
-- Aucun compte applicatif avec l'hôte '%' :
SELECT user, host FROM mysql.user WHERE host = '%';
```

### Le cas `haproxy_check`

Ce compte sans mot de passe est accessible à quiconque peut joindre `10.0.10.2:3306` (toutes les connexions via HAProxy apparaissent venir de 10.0.10.2). Il ne permet que `SELECT 1`, `SHOW STATUS` et la lecture de quelques variables. Mesures de limitation :

- pfSense : seuls vWEB et vADMIN atteignent `10.0.10.2:3306` ;
- limite de connexions :

  ```sql
  ALTER USER 'haproxy_check'@'10.0.10.2' WITH MAX_USER_CONNECTIONS 10;
  ```

- amélioration future : check *wsrep-aware* HTTP (port 9200) qui supprime le besoin de ce compte.

## Comptes système

| Compte | Usage | Shell | sudo |
|--------|-------|-------|------|
| `<ADMIN_USER>` (par VM) | Administration humaine | `/bin/bash` | Oui |
| `haproxyadmin` (HAPROXY) | Administration humaine de HAProxy | `/bin/bash` | Oui |
| `haproxy` | Service HAProxy (paquet) | `nologin` | Non |
| `mysql` | Service MariaDB (paquet) | `nologin` | Non |
| `www-data` | Apache / PHP | `nologin` | Non |

Séparer le compte **humain** du compte **de service** évite qu'une faille dans un service donne un shell interactif, et évite le conflit décrit dans [INC-08](../09-troubleshooting/incidents.md#inc-08--conflit-avec-le-compte-système-haproxy).

## Fichiers

| Fichier | Propriétaire | Droits |
|---------|--------------|--------|
| `/var/www/wordpress/wp-config.php` | `root:www-data` | `640` |
| `/var/www/glpi/config/config_db.php` | `www-data:www-data` | `640` |
| `/etc/haproxy/haproxy.cfg` | `root:root` | `644` (contient le mot de passe des stats : `640 root:haproxy` recommandé) |
| `~/.ssh/id_ed25519` | utilisateur | `600` |
| `/var/backups/mariadb/*.sql.gz` | `root` | `600` |

## Réseau

Le principe s'applique aussi aux flux : seul **HAProxy** atteint les bases ; seul **vADMIN** atteint SSH ; les postes **vUSER** n'atteignent que les services publiés. Voir [network-segmentation.md](network-segmentation.md).
