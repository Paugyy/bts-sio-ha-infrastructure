# WEB-01 — 10.0.10.1

Premier serveur WordPress, **serveur de référence** pour les fichiers.

## Fiche

| Élément | Valeur |
|---------|--------|
| Nom de VM | WEB-01 |
| IP / masque | 10.0.10.1/24 |
| Passerelle | 10.0.10.254 |
| VLAN | 301 — vWEB |
| OS | Debian 12 |
| Logiciels | Apache 2.4, PHP 8.2, WordPress 6.x |
| Racine web | `/var/www/wordpress` |
| vhost | [wordpress.conf.example](../../configs/apache/wordpress.conf.example) |
| Configuration WordPress | [wp-config.php.example](../../configs/wordpress/wp-config.php.example) (identique sur WEB-01 et WEB-02) |
| Base de données | `wordpress` via `10.0.10.2:3306` (HAProxy) |

## Déploiement

**SUR WEB-01**

```bash
# Dépendances (simulation, puis exécution)
sudo ./scripts/install/install-wordpress-deps.sh
sudo ./scripts/install/install-wordpress-deps.sh --apply
sudo ./scripts/install/install-wordpress-deps.sh --apply --download   # télécharge WordPress (SHA-1 vérifié)

# vhost Apache
sudo cp configs/apache/wordpress.conf.example /etc/apache2/sites-available/wordpress.conf
sudo a2ensite wordpress
sudo a2dissite 000-default
sudo apachectl configtest
sudo systemctl reload apache2
```

## Rôle de référence

WEB-01 est le **serveur de référence des fichiers** :

- l'installation WordPress (assistant web) est faite **une seule fois**, sur WEB-01 ;
- les extensions, thèmes, mises à jour et téléversements de médias sont effectués sur WEB-01 ;
- les fichiers sont ensuite copiés vers WEB-02 ([synchronization.md](synchronization.md)).

L'installation est détaillée dans [wordpress.md](wordpress.md).

## Vérification

**SUR WEB-01**

```bash
systemctl is-active apache2
curl -sI http://localhost/wp-login.php | head -n 1
php -m | grep -E 'mysqli|curl|gd|mbstring|xml|zip|intl'
```

**SUR ADM-01**

```bash
curl -sI http://10.0.10.1/ | head -n 1        # test T11
```

Capture attendue : `evidence/screenshots/06-wordpress-web01.png`
