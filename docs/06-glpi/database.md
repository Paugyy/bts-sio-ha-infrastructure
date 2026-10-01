# GLPI — Base de données

## Création

**SUR MYSQL-01** (répliqué sur les 3 nœuds)

```sql
-- sudo mariadb
CREATE DATABASE glpi CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'glpi'@'10.0.10.2' IDENTIFIED BY '<PASSWORD>';
GRANT ALL PRIVILEGES ON glpi.* TO 'glpi'@'10.0.10.2';
```

## Fuseaux horaires (recommandé par GLPI)

GLPI peut stocker les dates en UTC si le compte peut lire les fuseaux horaires de MariaDB.

**SUR MYSQL-01**

```bash
sudo mariadb-tzinfo-to-sql /usr/share/zoneinfo | sudo mariadb mysql
sudo mariadb -e "GRANT SELECT ON mysql.time_zone_name TO 'glpi'@'10.0.10.2';"
```

> Les tables `mysql.time_zone*` sont en **MyISAM** sous MariaDB 10.11 : elles ne sont pas répliquées par Galera. Exécuter `mariadb-tzinfo-to-sql` **sur chacun des trois nœuds** (le `GRANT`, lui, est répliqué).

**SUR GLPI-01** (une fois GLPI installé)

```bash
sudo -u www-data php /var/www/glpi/bin/console database:enable_timezones
```

## Vérification

**SUR GLPI-01**

```bash
mariadb -h 10.0.10.2 -u glpi -p -e 'SELECT @@hostname; SHOW TABLES FROM glpi;' | head
```

**SUR MYSQL-02** — toutes les tables GLPI doivent être InnoDB :

```sql
SELECT engine, COUNT(*) FROM information_schema.tables WHERE table_schema = 'glpi' GROUP BY engine;
```

## Fichier de connexion de GLPI

L'assistant écrit `/var/www/glpi/config/config_db.php` (hôte, compte, mot de passe). Ce fichier :

- reste hors de la racine web (`public/`) ;
- ne doit **jamais** être copié dans ce dépôt ;
- doit appartenir à `www-data` avec des droits restreints (`640`).
