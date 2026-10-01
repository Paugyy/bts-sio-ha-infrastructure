# Configurations

Toutes les configurations sont publiées sous forme de fichiers **`.example` anonymisés**. Elles reflètent la configuration de référence du lab ; les secrets sont remplacés par des placeholders.

## Inventaire

| Fichier | VM cible | Chemin sur la VM |
|---------|----------|------------------|
| [haproxy/haproxy.cfg.example](haproxy/haproxy.cfg.example) | HAPROXY | `/etc/haproxy/haproxy.cfg` |
| [galera/mysql01/50-server.cnf.example](galera/mysql01/50-server.cnf.example) | MYSQL-01 | `/etc/mysql/mariadb.conf.d/50-server.cnf` |
| [galera/mysql01/60-galera.cnf.example](galera/mysql01/60-galera.cnf.example) | MYSQL-01 | `/etc/mysql/mariadb.conf.d/60-galera.cnf` |
| [galera/mysql02/50-server.cnf.example](galera/mysql02/50-server.cnf.example) | MYSQL-02 | `/etc/mysql/mariadb.conf.d/50-server.cnf` |
| [galera/mysql02/60-galera.cnf.example](galera/mysql02/60-galera.cnf.example) | MYSQL-02 | `/etc/mysql/mariadb.conf.d/60-galera.cnf` |
| [galera/mysql03/50-server.cnf.example](galera/mysql03/50-server.cnf.example) | MYSQL-03 | `/etc/mysql/mariadb.conf.d/50-server.cnf` |
| [galera/mysql03/60-galera.cnf.example](galera/mysql03/60-galera.cnf.example) | MYSQL-03 | `/etc/mysql/mariadb.conf.d/60-galera.cnf` |
| [apache/wordpress.conf.example](apache/wordpress.conf.example) | WEB-01, WEB-02 | `/etc/apache2/sites-available/wordpress.conf` |
| [apache/glpi.conf.example](apache/glpi.conf.example) | GLPI-01 | `/etc/apache2/sites-available/glpi.conf` |
| [wordpress/wp-config.php.example](wordpress/wp-config.php.example) | WEB-01, WEB-02 | `/var/www/wordpress/wp-config.php` |
| [ssh/linux-ssh-config.example](ssh/linux-ssh-config.example) | ADM-01 | `~/.ssh/config` |
| [ssh/windows-ssh-config.example](ssh/windows-ssh-config.example) | Poste Windows | `C:\Users\<USER>\.ssh\config` |
| [pfsense/](pfsense/README.md) | pfSense | Interface web (tableaux de règles) |

## Utilisation

```bash
# Exemple SUR HAPROXY
sudo cp configs/haproxy/haproxy.cfg.example /etc/haproxy/haproxy.cfg
sudo nano /etc/haproxy/haproxy.cfg       # remplacer les <PLACEHOLDER>
sudo haproxy -c -f /etc/haproxy/haproxy.cfg
```

Toujours : **sauvegarder l'existant → copier → remplacer les placeholders → vérifier la syntaxe → recharger**.

| Service | Vérification de syntaxe |
|---------|-------------------------|
| HAProxy | `sudo haproxy -c -f /etc/haproxy/haproxy.cfg` |
| Apache | `sudo apachectl configtest` |
| MariaDB | `sudo mariadbd --help --verbose > /dev/null` (erreur si option inconnue) |
| PHP | `php -l /var/www/wordpress/wp-config.php` |
| SSH | `ssh -G web01` (affiche la configuration résolue) |

## Placeholders

| Placeholder | Remplacer par |
|-------------|---------------|
| `<SECRET>` / `<PASSWORD>` | Un mot de passe fort, stocké dans un gestionnaire de mots de passe |
| `<ADMIN_USER>` | Compte d'administration Linux |
| `<WINDOWS_USER>` | Nom du profil Windows |
| `<ADM01_ADDRESS>` / `<ADM01_PORT>` | Adresse et port par lesquels ADM-01 est joignable |

## Règles

- Un fichier réel (sans `.example`) placé dans `configs/` est **ignoré par Git** (voir [.gitignore](../.gitignore)).
- Toute modification d'un `.example` doit être répercutée dans la documentation correspondante et dans le [générateur](../generator/README.md).
- Le [générateur](../generator/README.md) produit ces mêmes fichiers avec d'autres adresses.
