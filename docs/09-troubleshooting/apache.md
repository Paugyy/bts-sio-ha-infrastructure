# Dépannage — Apache

## Commandes de base

```bash
# SUR WEB-01 / WEB-02 / GLPI-01
sudo apachectl configtest                         # syntaxe
sudo apache2ctl -S                                # vhosts actifs et vhost par défaut
apache2ctl -M                                     # modules chargés
sudo systemctl status apache2 --no-pager
sudo tail -n 50 /var/log/apache2/error.log
ls -l /etc/apache2/sites-enabled/
```

## Fiches

| Symptôme | Cause probable | Diagnostic | Correction | Validation |
|----------|----------------|------------|------------|------------|
| Page « Apache2 Debian Default Page » | `000-default` actif, vhost du projet non activé | `ls /etc/apache2/sites-enabled/` | `a2dissite 000-default && a2ensite wordpress` (ou `glpi`) + `reload` | La page de l'application s'affiche |
| `404` sur les permaliens WordPress | `mod_rewrite` inactif ou `AllowOverride None` | `apache2ctl -M \| grep rewrite` ; vhost | `a2enmod rewrite` ; `AllowOverride All` | `/sample-page/` s'affiche |
| `404` sur les pages GLPI | Voir [INC-05](incidents.md#inc-05--glpi--erreur-404-apache) | | | |
| `403 Forbidden` | Droits fichiers, `Require all denied`, `Options -Indexes` sans `index.php` | `namei -l /var/www/wordpress/index.php` ; journal d'erreurs | Propriétaire `www-data`, droits 755/644 ; `Require all granted` | `200` |
| Code PHP affiché en clair | Module PHP absent | `apache2ctl -M \| grep php` | `apt install libapache2-mod-php` + `restart` | Page exécutée |
| `AH00558: Could not reliably determine the server's fully qualified domain name` | `ServerName` global absent (avertissement sans gravité) | — | `echo 'ServerName localhost' \| sudo tee /etc/apache2/conf-available/servername.conf && sudo a2enconf servername` | Avertissement disparu |
| Journaux montrant toujours `10.0.10.2` | `mod_remoteip` inactif | `apache2ctl -M \| grep remoteip` | `a2enmod remoteip` + directives `RemoteIP*` | IP clients visibles |
| `reload` sans effet | Erreur de syntaxe : ancienne config conservée | `apachectl configtest` | Corriger | `Syntax OK` |
