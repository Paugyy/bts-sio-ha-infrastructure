# GLPI — Apache

Configuration : [configs/apache/glpi.conf.example](../../configs/apache/glpi.conf.example)

## Déploiement

**SUR GLPI-01**

```bash
sudo a2enmod rewrite remoteip
sudo cp configs/apache/glpi.conf.example /etc/apache2/sites-available/glpi.conf
sudo a2ensite glpi
sudo a2dissite 000-default
sudo apachectl configtest
sudo systemctl reload apache2
```

## Pourquoi `DocumentRoot /var/www/glpi/public` ?

Depuis GLPI 10.0.7, seul le dossier `public/` doit être exposé. Les dossiers `config/` (identifiants SQL), `files/` (documents joints) et `vendor/` restent **hors** de la racine web : ils ne peuvent pas être téléchargés par URL.

## Pourquoi des règles de réécriture ?

Toutes les pages de GLPI 10 passent par un **routeur** unique (`public/index.php`). Une URL comme `/front/ticket.php` ne correspond à aucun fichier dans `public/` : sans réécriture, Apache renvoie **404**.

```apache
<Directory /var/www/glpi/public>
    Require all granted
    RewriteEngine On
    RewriteCond %{HTTP:Authorization} ^(.+)$
    RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteRule ^(.*)$ index.php [QSA,L]
</Directory>
```

| Ligne | Rôle |
|-------|------|
| `RewriteCond %{REQUEST_FILENAME} !-f` | Si le fichier demandé n'existe pas réellement… |
| `RewriteRule ^(.*)$ index.php [QSA,L]` | …transmettre la requête au routeur, en conservant la query string (`QSA`) |
| Règle `HTTP_AUTHORIZATION` | Transmet l'en-tête d'authentification à PHP (API REST) |

Ces règles doivent être **dans le bloc `<Directory>`** : `%{REQUEST_FILENAME}` n'y contient le chemin complet du fichier qu'à ce niveau. Placées au niveau du `VirtualHost`, elles ne se comportent pas de la même façon — c'était la cause de l'[incident INC-05](../09-troubleshooting/incidents.md#inc-05--glpi--erreur-404-apache).

## Réglage PHP recommandé

GLPI signale `session.cookie_httponly` désactivé.

**SUR GLPI-01**

```bash
sudo sed -i 's/^;\?session.cookie_httponly.*/session.cookie_httponly = On/' /etc/php/8.2/apache2/php.ini
sudo systemctl reload apache2
```

## Vérification

```bash
# SUR GLPI-01
sudo apache2ctl -S                      # glpi.conf actif sur *:80
curl -sI http://localhost/ | head -n 1  # 200 ou 302
curl -sI http://localhost/front/central.php | head -n 1   # 302 (redirection vers login), pas 404
```
