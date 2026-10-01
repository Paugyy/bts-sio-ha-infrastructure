# Sauvegarde et restauration — GLPI

GLPI n'étant **pas redondé**, sa sauvegarde est la seule protection contre la perte de GLPI-01.

## Données à sauvegarder

| Donnée | Emplacement | Contenu |
|--------|-------------|---------|
| Base `glpi` | Galera | Tickets, parc, utilisateurs, paramètres |
| Documents joints | `/var/www/glpi/files/` | Pièces jointes, images, exports |
| Configuration | `/var/www/glpi/config/` | `config_db.php` (identifiants SQL), clé de chiffrement `glpicrypt.key` |
| Extensions | `/var/www/glpi/plugins/`, `/var/www/glpi/marketplace/` | Plugins installés |

> `glpicrypt.key` chiffre certains secrets stockés en base (mots de passe LDAP, SMTP…). Sans elle, ces secrets sont **irrécupérables** après restauration. Elle doit être sauvegardée avec la même protection qu'un mot de passe.

## Sauvegarde

**SUR MYSQL-03** — base :

```bash
sudo mariadb-dump --single-transaction --routines --triggers glpi | gzip > /var/backups/mariadb/glpi-$(date +%F).sql.gz
sudo chmod 600 /var/backups/mariadb/glpi-*.sql.gz
```

**SUR GLPI-01** — fichiers :

```bash
sudo install -d -m 700 /var/backups/glpi
sudo tar -czf /var/backups/glpi/glpi-files-$(date +%F).tar.gz -C /var/www glpi/files glpi/config glpi/plugins glpi/marketplace
sudo chmod 600 /var/backups/glpi/*.tar.gz
```

## Restauration (GLPI-01 reconstruit)

1. [06-glpi/installation.md](../06-glpi/installation.md) : dépendances, **même version** de GLPI, vhost.
2. Restaurer `files/`, `config/`, `plugins/`, `marketplace/` depuis l'archive ; `chown -R www-data:www-data /var/www/glpi`.
3. Si la base a été perdue : la restaurer sur Galera (`gunzip -c glpi-<DATE>.sql.gz | sudo mariadb glpi`).
4. Vérifier : `sudo -u www-data php /var/www/glpi/bin/console database:check_schema_integrity`.
5. `./scripts/validation/check-glpi.sh` depuis ADM-01.
