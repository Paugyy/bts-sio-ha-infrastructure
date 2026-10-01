# WordPress — Synchronisation des fichiers

## Le problème

**Galera synchronise la base de données, pas les fichiers.**

| Donnée | Stockage | Synchronisée par |
|--------|----------|------------------|
| Articles, pages, utilisateurs, réglages, liste des médias | Base `wordpress` | Galera (automatique) |
| Images téléversées (`wp-content/uploads`) | Disque de chaque serveur | **Rien** par défaut |
| Thèmes, extensions (`wp-content/themes`, `plugins`) | Disque de chaque serveur | **Rien** par défaut |
| Cœur WordPress, `wp-config.php` | Disque de chaque serveur | **Rien** par défaut |

Conséquence : une image téléversée via WEB-01 est référencée en base (donc visible dans la médiathèque des deux serveurs) mais le **fichier** n'existe que sur WEB-01. Un visiteur servi par WEB-02 obtient une image cassée (404), une fois sur deux.

## Solution retenue (v1.0.0) : WEB-01 référence + rsync

1. **Toute modification de fichiers** (médias, thèmes, extensions, mises à jour) se fait sur **WEB-01**.
2. Les fichiers sont copiés de WEB-01 vers WEB-02 avec `rsync` (via SSH).

### Prérequis

- `rsync` installé sur **WEB-01 et WEB-02** (le binaire distant est appelé par SSH).
- Accès SSH par clé de WEB-01 vers WEB-02 (flux F11, même VLAN).

### Synchronisation manuelle

**SUR WEB-01**

```bash
# Simulation d'abord (-n) : liste ce qui serait copié ou supprimé
sudo rsync -aAXn --delete --exclude 'wp-content/cache/' \
     /var/www/wordpress/ <ADMIN_USER>@10.0.10.4:/var/www/wordpress/ \
     --rsync-path="sudo rsync"

# Puis exécution réelle
sudo rsync -aAX --delete --exclude 'wp-content/cache/' \
     /var/www/wordpress/ <ADMIN_USER>@10.0.10.4:/var/www/wordpress/ \
     --rsync-path="sudo rsync"
```

| Option | Rôle |
|--------|------|
| `-a` | Archive : récursif, conserve droits, propriétaires, dates |
| `-A -X` | Conserve ACL et attributs étendus |
| `--delete` | Supprime sur WEB-02 ce qui n'existe plus sur WEB-01 (**d'où la simulation `-n` préalable**) |
| `--rsync-path="sudo rsync"` | Écriture en root côté WEB-02 (nécessite une règle sudo adaptée) |
| Barre oblique finale sur la source | Copie le **contenu** du dossier, pas le dossier lui-même |

### Synchronisation planifiée (exemple)

```bash
# SUR WEB-01 — /etc/cron.d/wordpress-sync (toutes les 5 minutes)
*/5 * * * * root rsync -aAX --delete --exclude 'wp-content/cache/' /var/www/wordpress/ syncuser@10.0.10.4:/var/www/wordpress/ --rsync-path="sudo rsync" >> /var/log/wordpress-sync.log 2>&1
```

Statut : **exemple**, à mettre en place et à tester avant d'être déclaré réel.

## Limites

- Un média téléversé via WEB-02 (si l'administrateur est servi par WEB-02) serait **supprimé** à la synchronisation suivante par `--delete`. D'où la persistance de session HAProxy et la règle « administration via WEB-01 ».
- Délai de synchronisation : un média est absent de WEB-02 jusqu'au prochain passage.
- Si WEB-01 tombe, les téléversements doivent attendre son retour (ou une bascule manuelle du rôle de référence).

## Améliorations (roadmap)

| Solution | Principe | Avantage | Inconvénient |
|----------|----------|----------|--------------|
| **NFS** | `wp-content/uploads` monté depuis un serveur NFS | Simple | Le serveur NFS devient un SPOF |
| **GlusterFS** | Volume répliqué sur WEB-01 et WEB-02 | Pas de SPOF | Plus complexe, sensible au réseau |
| **lsyncd** | rsync déclenché par inotify, quasi temps réel | Léger | Toujours unidirectionnel |
| **Stockage objet (S3/MinIO)** | Extension WordPress d'offload des médias | Évolutif | Dépendance supplémentaire |
