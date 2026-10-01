# Générateur HTML

Application **autonome et hors ligne** qui produit les fichiers de configuration d'une infrastructure équivalente à celle du lab, avec **vos** adresses IP, VLAN, noms de VM, ports et comptes.

## Utilisation

1. Ouvrir `generator/index.html` dans un navigateur (double-clic) — aucun serveur, aucune installation, aucune connexion réseau.
2. Modifier les paramètres (ou *Importer JSON*).
3. Corriger les erreurs signalées : la génération est suspendue tant que la configuration est incohérente.
4. Copier ou télécharger chaque fichier, ou *Tout (Markdown)* pour un document unique.
5. *Exporter JSON* pour conserver la configuration (réimportable).

La configuration en cours est aussi mémorisée dans le navigateur (stockage local) pour la session suivante.

## Fichiers produits

| Fichier | VM | Cible |
|---------|----|-------|
| `haproxy/haproxy.cfg` | HAProxy | `/etc/haproxy/haproxy.cfg` |
| `galera/nodeN-*/50-server.cnf` | MYSQL-0N | `/etc/mysql/mariadb.conf.d/50-server.cnf` |
| `galera/nodeN-*/60-galera.cnf` | MYSQL-0N | `/etc/mysql/mariadb.conf.d/60-galera.cnf` |
| `galera/init-accounts.sql` | MYSQL-01 | Bases et comptes SQL (WordPress, GLPI, health-check) |
| `wordpress/wp-config.php` | WEB-01, WEB-02 | `/var/www/wordpress/wp-config.php` |
| `apache/wordpress.conf` | WEB-01, WEB-02 | vhost Apache |
| `apache/glpi.conf` | GLPI-01 | vhost Apache |
| `ssh/linux-ssh-config`, `ssh/windows-ssh-config` | ADM-01, poste Windows | `~/.ssh/config` |
| `network/interfaces.txt` | Toutes | Extraits `/etc/network/interfaces` |
| `pfsense/rules.md` | pfSense | Alias, NAT, règles à saisir |
| `docs/ip-plan.md` | — | Plan d'adressage |

## Contrôles effectués

| Contrôle | Exemple d'erreur détectée |
|----------|---------------------------|
| Format IPv4 / CIDR | `10.0.10.300`, `10.0.10.0/33` |
| IP dans le bon VLAN | Un nœud Galera placé dans le réseau web |
| Adresse de réseau / diffusion / passerelle | VM en `.0`, `.255` ou sur la passerelle |
| Unicité | Deux VM avec la même IP ou le même nom |
| Chevauchement de réseaux | Deux VLAN sur le même /24, ou VLAN dans le WAN |
| Passerelle WAN dans le réseau WAN | — |
| Identifiants VLAN | Hors 2–4094, doublons |
| Ports HAProxy | Hors 1–65535, deux services sur le même port |
| Comptes | `haproxy` comme compte humain (incident INC-08), `root` en health-check, base partagée WordPress/GLPI |

## Sécurité

- **Aucun mot de passe n'est demandé ni généré** : les fichiers contiennent `<PASSWORD>` / `<SECRET>`.
- Aucune requête réseau : tout est calculé dans le navigateur.
- Les fichiers générés peuvent contenir vos adresses internes : ne pas les publier sans relecture.

## Structure

| Fichier | Rôle |
|---------|------|
| `index.html` | Page (aucune dépendance externe) |
| `css/style.css` | Styles, thème clair/sombre automatique |
| `js/validation.js` | Outils IPv4 et règles de cohérence |
| `js/templates.js` | Configuration de référence embarquée et modèles de fichiers |
| `js/generators.js` | Assemblage de la liste des fichiers et export Markdown |
| `js/app.js` | Formulaire, validation en direct, aperçu, import/export |
| `examples/reference-infrastructure.json` | Infrastructure du lab, importable |

Scripts classiques (pas de modules ES) : c'est ce qui permet le fonctionnement en `file://`.

## GitHub Pages

Si GitHub Pages est activé (*Settings → Pages → `main` / `(root)`*), le générateur est servi sur `https://<GITHUB_USER>.github.io/bts-sio-ha-infrastructure/generator/`. Son fonctionnement est identique (tout reste local au navigateur).

## Maintenance

Toute modification d'un fichier de [`configs/`](../configs/README.md) doit être reportée dans `js/templates.js`, et inversement, pour que le générateur et les exemples restent cohérents.
