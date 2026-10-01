# GLPI — Dépannage

## Erreur 404 sur toutes les pages sauf l'accueil

Incident réel : [INC-05](../09-troubleshooting/incidents.md#inc-05--glpi--erreur-404-apache)

| Élément | Contenu |
|---------|---------|
| **Symptôme** | La page de connexion s'affiche, mais après authentification ou sur `/front/...` : `404 Not Found` (page Apache) |
| **Cause probable** | `mod_rewrite` inactif, `DocumentRoot` pointant sur `/var/www/glpi` au lieu de `/public`, ou règles de réécriture hors du bloc `<Directory>` |
| **Diagnostic** | Vérifier module, vhost actif et journal d'erreurs |
| **Commandes** | **SUR GLPI-01** `apache2ctl -M \| grep rewrite` ; `apache2ctl -S` ; `grep -n -A12 '<Directory' /etc/apache2/sites-available/glpi.conf` ; `sudo tail -n 20 /var/log/apache2/glpi-error.log` |
| **Correction** | `sudo a2enmod rewrite` ; vhost conforme à [glpi.conf.example](../../configs/apache/glpi.conf.example) ; `sudo systemctl reload apache2` |
| **Validation** | `curl -sI http://10.0.10.3/front/central.php` → `302` (et non `404`) |

## Page Apache par défaut au lieu de GLPI

| Élément | Contenu |
|---------|---------|
| **Symptôme** | « Apache2 Debian Default Page » |
| **Cause probable** | Site `000-default` toujours actif ou `glpi.conf` non activé |
| **Commandes** | **SUR GLPI-01** `ls -l /etc/apache2/sites-enabled/` |
| **Correction** | `sudo a2dissite 000-default && sudo a2ensite glpi && sudo systemctl reload apache2` |
| **Validation** | `check-glpi.sh` : « la page servie est bien GLPI » |

## Erreur de connexion SQL

| Élément | Contenu |
|---------|---------|
| **Symptôme** | `Connection to the database failed` |
| **Cause probable** | Compte créé pour un autre hôte que `10.0.10.2`, HAProxy SQL indisponible, cluster non-Primary |
| **Commandes** | **SUR GLPI-01** `mariadb -h 10.0.10.2 -u glpi -p -e 'SELECT 1'` |
| **Correction** | `CREATE USER 'glpi'@'10.0.10.2' ...` ; voir [HAProxy](../09-troubleshooting/haproxy.md) / [Galera](../09-troubleshooting/galera.md) |
| **Validation** | Connexion SQL OK, interface GLPI fonctionnelle |

## Avertissement « Web server root directory configuration is not safe »

| Élément | Contenu |
|---------|---------|
| **Symptôme** | Avertissement de sécurité dans l'assistant ou la page d'accueil |
| **Cause** | `DocumentRoot` sur `/var/www/glpi` : `config/` et `files/` accessibles par URL |
| **Correction** | `DocumentRoot /var/www/glpi/public` + réécritures |
| **Validation** | `curl -sI http://10.0.10.3/config/config_db.php` → `404` |
