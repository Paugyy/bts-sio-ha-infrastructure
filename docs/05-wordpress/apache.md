# WordPress — Apache

Configuration identique sur **WEB-01** et **WEB-02** : [configs/apache/wordpress.conf.example](../../configs/apache/wordpress.conf.example)

## Modules

**SUR WEB-01 et WEB-02**

```bash
sudo a2enmod rewrite remoteip
sudo systemctl restart apache2
apache2ctl -M | grep -E 'rewrite|remoteip|php'
```

| Module | Pourquoi |
|--------|----------|
| `rewrite` | Permaliens WordPress (`.htaccess`) |
| `remoteip` | Journaliser l'IP réelle du client au lieu de celle de HAProxy |
| `php8.2` | Exécution de WordPress (installé par `libapache2-mod-php`) |

## Points clés du vhost

| Directive | Rôle |
|-----------|------|
| `DocumentRoot /var/www/wordpress` | Racine du site |
| `AllowOverride All` | Autorise le `.htaccess` de WordPress |
| `<FilesMatch "^(wp-config\.php\|readme\.html\|license\.txt)$"> Require all denied` | Interdit l'accès direct aux fichiers sensibles ou révélant la version |
| `RemoteIPHeader X-Forwarded-For` | Lit l'IP client transmise par HAProxy |
| `RemoteIPInternalProxy 10.0.10.2` | **Seul** HAProxy est autorisé à fournir cet en-tête (sinon n'importe quel client pourrait usurper son IP) |

## IP réelle des clients dans les journaux

Sans `mod_remoteip`, chaque ligne de `/var/log/apache2/wordpress-access.log` montre `10.0.10.2` (HAProxy). Avec :

```bash
# SUR WEB-01
sudo tail -n 3 /var/log/apache2/wordpress-access.log
# 10.0.40.105 - - [..] "GET / HTTP/1.1" 200 ...   ← IP du poste utilisateur
# 10.0.10.2   - - [..] "GET /wp-login.php ..."   ← health-checks HAProxy
```

## Permissions

**SUR WEB-01 et WEB-02**

```bash
sudo chown -R www-data:www-data /var/www/wordpress
sudo find /var/www/wordpress -type d -exec chmod 755 {} \;
sudo find /var/www/wordpress -type f -exec chmod 644 {} \;
sudo chown root:www-data /var/www/wordpress/wp-config.php
sudo chmod 640 /var/www/wordpress/wp-config.php
```

## Vérification

```bash
sudo apachectl configtest      # Syntax OK
sudo apache2ctl -S             # vhosts actifs : wordpress.conf sur *:80
```
