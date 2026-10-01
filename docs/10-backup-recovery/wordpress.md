# Sauvegarde et restauration — WordPress

Une sauvegarde WordPress complète = **base** ([mariadb.md](mariadb.md)) + **fichiers** (ci-dessous). L'une sans l'autre ne suffit pas : la base référence des médias présents seulement sur disque.

## Sauvegarde des fichiers

WEB-01 étant le serveur de référence des fichiers, c'est lui qui est sauvegardé.

**SUR WEB-01**

```bash
sudo ./scripts/backup/backup-wordpress.sh
ls -lh /var/backups/wordpress/
```

L'archive contient `wp-config.php` (mot de passe SQL, clés) : droits `600`, stockage chiffré hors du lab, **jamais** dans Git.

## Restauration

### Restaurer les fichiers sur WEB-01

```bash
# SUR WEB-01
sha256sum -c /var/backups/wordpress/<FICHIER>.tar.gz.sha256
sudo mv /var/www/wordpress /var/www/wordpress.before-restore-$(date +%F)
sudo tar -xzf /var/backups/wordpress/<FICHIER>.tar.gz -C /var/www/
sudo chown -R www-data:www-data /var/www/wordpress
sudo chown root:www-data /var/www/wordpress/wp-config.php && sudo chmod 640 /var/www/wordpress/wp-config.php
```

### Propager vers WEB-02

Synchronisation habituelle : [05-wordpress/synchronization.md](../05-wordpress/synchronization.md).

### Cohérence base / fichiers

Restaurer la base et les fichiers **de la même date**. Sinon : médias manquants (fichiers plus anciens que la base) ou orphelins (fichiers plus récents).

## Reconstruire un serveur web perdu

Grâce à la redondance, la perte de WEB-02 ne nécessite **aucune sauvegarde** :

1. Recréer la VM (Debian, IP `10.0.10.4`, VLAN 301).
2. [web02.md](../05-wordpress/web02.md) : dépendances, vhost, copie des fichiers depuis WEB-01.
3. HAProxy le réintègre automatiquement dès que le health-check réussit.
