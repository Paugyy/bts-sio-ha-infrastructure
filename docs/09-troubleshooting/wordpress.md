# Dépannage — WordPress

Fiches détaillées : [05-wordpress/troubleshooting.md](../05-wordpress/troubleshooting.md)

| Symptôme | Cause probable | Commande de diagnostic | Correction |
|----------|----------------|------------------------|------------|
| « Erreur lors de la connexion à la base de données » | Chaîne SQL rompue (HAProxy, Galera, identifiants) | **SUR WEB-01** `mariadb -h 10.0.10.2 -u wordpress -p -e 'SELECT 1'` | Maillon défaillant ; `DB_HOST`/`DB_PASSWORD` |
| `Access denied for user 'wordpress'@'10.0.10.2'` | Compte créé pour `10.0.10.1`/`10.0.10.4` | **SUR MYSQL-01** `SELECT user,host FROM mysql.user WHERE user='wordpress';` | Créer le compte pour `10.0.10.2` |
| Redirection vers une IP interne | `siteurl`/`home` incohérents | **SUR MYSQL-01** `SELECT option_value FROM wordpress.wp_options WHERE option_name IN ('siteurl','home');` | `WP_HOME`/`WP_SITEURL` dans `wp-config.php` |
| Images cassées une fois sur deux | Fichiers non synchronisés | **SUR WEB-01 et WEB-02** `ls wp-content/uploads/...` | rsync WEB-01 → WEB-02 |
| Déconnexion en boucle | Clés/sels différents | `sha256sum wp-config.php` sur les deux | Copier le fichier de WEB-01 |
| Page blanche | Erreur PHP fatale | **SUR WEB-0X** `sudo tail -n 30 /var/log/apache2/wordpress-error.log` | Désactiver l'extension en cause (renommer son dossier) |
| Versions différentes entre serveurs | Mise à jour faite sur un seul serveur | `grep wp_version /var/www/wordpress/wp-includes/version.php` sur les deux | Mettre à jour WEB-01 puis synchroniser |
| « Briefly unavailable for scheduled maintenance » | Fichier `.maintenance` restant après une mise à jour interrompue | `ls -la /var/www/wordpress/.maintenance` | Supprimer le fichier (sur les deux serveurs) |
