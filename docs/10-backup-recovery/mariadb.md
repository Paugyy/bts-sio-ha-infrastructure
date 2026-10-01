# Sauvegarde et restauration — MariaDB

## Sauvegarde

Un **seul nœud** suffit (les données sont identiques). MYSQL-03 est recommandé : en mode round-robin il reçoit autant de trafic que les autres, mais en mode écrivain unique (MYSQL-01 actif), il est le moins sollicité.

**SUR MYSQL-03**

```bash
sudo ./scripts/backup/backup-mariadb.sh
sudo ./scripts/backup/backup-mariadb.sh --retention 14     # supprime les sauvegardes de plus de 14 jours
ls -lh /var/backups/mariadb/
```

Ce que fait le script :

1. Vérifie que le nœud est `Synced` (sinon abandon).
2. `mariadb-dump --all-databases --single-transaction --routines --events --triggers` : instantané cohérent **sans verrou global**, le cluster continue de servir.
3. Compression gzip, droits `600`, empreinte SHA-256, test d'intégrité.

### Planification (exemple, statut : futur)

```bash
# SUR MYSQL-03 — /etc/cron.d/backup-mariadb
30 2 * * * root /opt/bts-sio-ha-infrastructure/scripts/backup/backup-mariadb.sh --retention 14 >> /var/log/backup-mariadb.log 2>&1
```

### Sauvegarde d'une seule base

```bash
# SUR MYSQL-03
sudo mariadb-dump --single-transaction --routines --triggers wordpress | gzip > /var/backups/mariadb/wordpress-$(date +%F).sql.gz
```

## Restauration

> Une restauration sur un nœud Galera est **répliquée sur tout le cluster**. C'est le comportement voulu pour revenir en arrière, mais il écrase les données actuelles des trois nœuds. Vérifier deux fois la base cible.

### Restaurer une base (ex. WordPress)

```bash
# SUR MYSQL-01
sha256sum -c /var/backups/mariadb/<FICHIER>.sql.gz.sha256        # intégrité
# Extraire la base wordpress d'un dump complet n'est pas trivial : préférer un dump par base,
# ou restaurer le dump complet sur un environnement de test et exporter la base voulue.
gunzip -c /var/backups/mariadb/wordpress-<DATE>.sql.gz | sudo mariadb wordpress
```

### Restaurer tout le cluster (dump complet)

1. **SUR MYSQL-01** : `gunzip -c <FICHIER>.sql.gz | sudo mariadb`
2. La restauration est répliquée sur MYSQL-02 et MYSQL-03.
3. Valider : `check-galera.sh` sur chaque nœud, puis WordPress et GLPI.

### Restauration après perte totale des 3 nœuds

1. Réinstaller **un** nœud, le bootstrapper (cluster vide).
2. Restaurer le dump sur ce nœud.
3. Démarrer les deux autres nœuds : ils reçoivent les données par SST.

## Vérification d'une sauvegarde (sans restaurer en production)

```bash
# SUR UNE VM DE TEST
gunzip -t <FICHIER>.sql.gz
gunzip -c <FICHIER>.sql.gz | grep -c 'CREATE TABLE'
gunzip -c <FICHIER>.sql.gz | head -n 20
```
