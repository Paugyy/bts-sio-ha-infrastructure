# WEB-02 — 10.0.10.4

Second serveur WordPress. Sert le même site que WEB-01, à partir d'une copie de ses fichiers.

## Fiche

| Élément | Valeur |
|---------|--------|
| Nom de VM | WEB-02 |
| IP / masque | 10.0.10.4/24 |
| Passerelle | 10.0.10.254 |
| VLAN | 301 — vWEB |
| OS | Debian 12 |
| Logiciels | Apache 2.4, PHP 8.2, WordPress 6.x |
| Racine web | `/var/www/wordpress` |
| vhost | [wordpress.conf.example](../../configs/apache/wordpress.conf.example) |
| Configuration WordPress | [wp-config.php.example](../../configs/wordpress/wp-config.php.example) (identique sur WEB-01 et WEB-02) |
| Base de données | `wordpress` via `10.0.10.2:3306` (HAProxy) |

## Déploiement

**SUR WEB-02**

```bash
# Dépendances (simulation, puis exécution)
sudo ./scripts/install/install-wordpress-deps.sh
sudo ./scripts/install/install-wordpress-deps.sh --apply

# vhost Apache
sudo cp configs/apache/wordpress.conf.example /etc/apache2/sites-available/wordpress.conf
sudo a2ensite wordpress
sudo a2dissite 000-default
sudo apachectl configtest
sudo systemctl reload apache2
```

## Pas de nouvelle installation

WEB-02 **ne passe pas** par l'assistant d'installation WordPress : la base `wordpress` existe déjà (créée lors de l'installation sur WEB-01) et est partagée via Galera. WEB-02 reçoit seulement **une copie des fichiers** de WEB-01, y compris `wp-config.php`.

**SUR WEB-01**

```bash
sudo rsync -aAX --delete /var/www/wordpress/ <ADMIN_USER>@10.0.10.4:/tmp/wordpress-sync/
```

**SUR WEB-02**

```bash
sudo rsync -a --delete /tmp/wordpress-sync/ /var/www/wordpress/
sudo chown -R www-data:www-data /var/www/wordpress
sudo chown root:www-data /var/www/wordpress/wp-config.php
sudo chmod 640 /var/www/wordpress/wp-config.php
```

> Si `rsync` répond `command not found`, il manque sur **l'une des deux** machines : rsync doit être installé aux deux extrémités ([INC-04](../09-troubleshooting/incidents.md#inc-04--rsync-absent)).

Procédure de synchronisation récurrente : [synchronization.md](synchronization.md)

## Vérification

**SUR WEB-02**

```bash
systemctl is-active apache2
curl -sI http://localhost/wp-login.php | head -n 1
php -m | grep -E 'mysqli|curl|gd|mbstring|xml|zip|intl'
```

**SUR ADM-01**

```bash
curl -sI http://10.0.10.4/ | head -n 1        # test T12
```

Capture attendue : `evidence/screenshots/07-wordpress-web02.png`
