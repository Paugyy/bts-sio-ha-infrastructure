# WordPress — Dépannage

Fiches complètes : [09-troubleshooting/wordpress.md](../09-troubleshooting/wordpress.md) et [apache.md](../09-troubleshooting/apache.md)

## « Erreur lors de la connexion à la base de données »

| Élément | Contenu |
|---------|---------|
| **Symptôme** | Page blanche avec ce message, sur un ou les deux serveurs |
| **Cause probable** | HAProxy SQL indisponible ; cluster non-Primary ; mauvais `DB_HOST`/`DB_PASSWORD` ; compte créé pour le mauvais hôte |
| **Diagnostic** | Tester la chaîne maillon par maillon |
| **Commandes** | **SUR WEB-01** `mariadb -h 10.0.10.2 -u wordpress -p -e 'SELECT 1'` ; **SUR HAPROXY** `./scripts/validation/check-haproxy.sh` ; **SUR MYSQL-01** `./scripts/validation/check-galera.sh` |
| **Correction** | Selon le maillon défaillant |
| **Validation** | `check-wordpress.sh` : HAProxy UP |

## Redirection vers une mauvaise adresse

| Élément | Contenu |
|---------|---------|
| **Symptôme** | `http://10.4.0.198:8081` redirige vers `http://10.0.10.1/` ou `http://10.0.10.2/` (injoignable depuis le WAN) |
| **Cause probable** | `siteurl` / `home` enregistrés lors de l'installation via une autre adresse |
| **Commandes** | **SUR MYSQL-01** `sudo mariadb -e "SELECT option_name, option_value FROM wordpress.wp_options WHERE option_name IN ('siteurl','home');"` |
| **Correction** | Définir `WP_HOME` et `WP_SITEURL` dans `wp-config.php` (sur les **deux** serveurs) avec l'URL utilisée par les clients |
| **Validation** | `curl -sI http://10.4.0.198:8081 \| grep -i location` : pas de redirection vers une IP interne |

## Images cassées une fois sur deux

| Élément | Contenu |
|---------|---------|
| **Symptôme** | Un média s'affiche ou non selon le rafraîchissement |
| **Cause probable** | Fichier présent sur un seul serveur (Galera ne réplique pas les fichiers) |
| **Commandes** | **SUR WEB-01 et WEB-02** `ls -l /var/www/wordpress/wp-content/uploads/AAAA/MM/` |
| **Correction** | Synchroniser depuis WEB-01 ([synchronization.md](synchronization.md)) |
| **Validation** | `curl -sI` sur l'URL du média : `200` sur WEB-01 **et** WEB-02 |

## Déconnexion de wp-admin en boucle

| Élément | Contenu |
|---------|---------|
| **Symptôme** | Retour à l'écran de connexion après chaque clic |
| **Cause probable** | Clés/sels différents entre WEB-01 et WEB-02 ; URL du site incohérente (cookie posé pour un autre domaine) |
| **Commandes** | **SUR WEB-01 et WEB-02** `sudo sha256sum /var/www/wordpress/wp-config.php` |
| **Correction** | Copier le `wp-config.php` de WEB-01 vers WEB-02 |
| **Validation** | Empreintes identiques ; navigation dans wp-admin stable |
