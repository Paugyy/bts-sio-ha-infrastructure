# WordPress — Installation

## Principe

```text
            ┌───────── fichiers (code, thèmes, médias) ─────────┐
            │                                                   │
      WEB-01 /var/www/wordpress  ── rsync ──►  WEB-02 /var/www/wordpress
            │                                                   │
            └──────── SQL ──► HAProxy 10.0.10.2:3306 ◄── SQL ───┘
                                     │
                         Galera (base « wordpress » unique)
```

- **Une seule base** `wordpress`, répliquée par Galera.
- **Deux copies des fichiers**, synchronisées de WEB-01 vers WEB-02.
- **Un seul `wp-config.php`**, identique sur les deux serveurs.

## 1. Base et compte SQL

**SUR MYSQL-01** (répliqué automatiquement)

```sql
-- sudo mariadb
CREATE DATABASE wordpress CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'wordpress'@'10.0.10.2' IDENTIFIED BY '<PASSWORD>';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'10.0.10.2';
```

L'hôte est `10.0.10.2` car **toutes** les connexions arrivent par HAProxy. Détail : [database.md](database.md).

**SUR WEB-01** — test de connexion via HAProxy :

```bash
mariadb -h 10.0.10.2 -P 3306 -u wordpress -p -e 'SELECT @@hostname, DATABASE();'
```

## 2. Fichiers WordPress

**SUR WEB-01**

```bash
sudo ./scripts/install/install-wordpress-deps.sh --apply --download
ls /var/www/wordpress    # wp-admin  wp-content  wp-includes  ...
```

## 3. wp-config.php

**SUR WEB-01**

```bash
sudo cp configs/wordpress/wp-config.php.example /var/www/wordpress/wp-config.php
sudo nano /var/www/wordpress/wp-config.php
```

- Remplacer `DB_PASSWORD` `<SECRET>` par le mot de passe du compte `wordpress`.
- Remplacer les 8 clés/sels `<SECRET>` par des valeurs générées sur `https://api.wordpress.org/secret-key/1.1/salt/`.
- Vérifier `DB_HOST = 10.0.10.2:3306`.

```bash
sudo chown root:www-data /var/www/wordpress/wp-config.php
sudo chmod 640 /var/www/wordpress/wp-config.php
php -l /var/www/wordpress/wp-config.php
```

Choix de configuration notables :

| Constante | Valeur | Raison |
|-----------|--------|--------|
| `DB_HOST` | `10.0.10.2:3306` | Passer par HAProxy, jamais par un nœud |
| Clés et sels | Identiques sur les 2 serveurs | Une session ouverte sur WEB-01 reste valide sur WEB-02 |
| `DISALLOW_FILE_EDIT` | `true` | Une modification via l'éditeur web n'affecterait qu'un serveur |
| `AUTOMATIC_UPDATER_DISABLED` | `true` | Une mise à jour automatique ne se ferait que sur un serveur → divergence de versions |

## 4. Assistant d'installation

**SUR ADM-01** (navigateur) : `http://10.0.10.1/` (directement WEB-01, pour l'installation uniquement)

- Titre, compte administrateur WordPress (`<ADMIN_USER>` / `<PASSWORD>` — pas `admin`).
- Après installation, régler *Réglages → Général* : **Adresse web de WordPress** et **Adresse web du site** = l'URL par laquelle les visiteurs arrivent (ex. `http://10.0.10.2`).

## 5. Copie vers WEB-02

Voir [web02.md](web02.md) puis [synchronization.md](synchronization.md).

## 6. Vérification

```bash
# SUR ADM-01
./scripts/validation/check-wordpress.sh
```

Attendu : WEB-01 UP, WEB-02 UP, HAProxy UP avec alternance de `X-Served-By`.
