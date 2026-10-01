# Journal des incidents

Incidents **réellement rencontrés** pendant la construction du lab, documentés au format :
**Symptôme → Cause probable → Diagnostic → Commandes → Correction → Validation**.

> Les messages d'erreur sont reproduits sous leur forme standard. Compléter les champs *Date* lors de la mise à jour du journal ; aucune donnée sensible (mot de passe, clé) n'y figure.

| ID | Titre | Composant | VM | Gravité |
|----|-------|-----------|----|---------|
| [INC-01](#inc-01--cluster-galera-non-primary) | Cluster Galera non Primary | Galera | MYSQL-0X | Critique |
| [INC-02](#inc-02--bind-address-incorrect) | bind-address incorrect | MariaDB | MYSQL-01/02/03 | Bloquant |
| [INC-03](#inc-03--dpkg-interrompu) | dpkg interrompu | APT | Toutes | Bloquant |
| [INC-04](#inc-04--rsync-absent) | rsync absent | Système | MYSQL-0X, WEB-0X | Bloquant |
| [INC-05](#inc-05--glpi--erreur-404-apache) | GLPI : erreur 404 Apache | Apache / GLPI | GLPI-01 | Majeur |
| [INC-06](#inc-06--ssh-permission-denied-publickey) | SSH Permission denied (publickey) | SSH | Toutes | Bloquant |
| [INC-07](#inc-07--remote-host-identification-has-changed) | REMOTE HOST IDENTIFICATION HAS CHANGED | SSH | ADM-01 | Sécurité |
| [INC-08](#inc-08--conflit-avec-le-compte-système-haproxy) | Conflit avec le compte système haproxy | HAProxy | HAPROXY | Majeur |

---

## INC-01 — Cluster Galera non Primary

*Date : `<AAAA-MM-JJ>` — VM : MYSQL-0X*

**Symptôme**

- WordPress : « Erreur lors de la connexion à la base de données ».
- Sur un nœud : `ERROR 1047 (08S01): WSREP has not yet prepared node for application use`.
- `wsrep_cluster_status = non-Primary`.

**Cause probable**

Perte de quorum : le nœud ne voit plus la majorité du cluster (arrêt brutal de plusieurs nœuds, coupure réseau, redémarrage de l'hôte Proxmox). Par sécurité (anti split-brain), un composant minoritaire refuse toute requête.

**Diagnostic**

Déterminer combien de nœuds tournent, ce que chacun voit, et lequel est le plus à jour.

**Commandes**

```bash
# SUR CHAQUE NŒUD
systemctl is-active mariadb
sudo mariadb -e "SHOW STATUS WHERE Variable_name IN ('wsrep_cluster_size','wsrep_cluster_status','wsrep_local_state_comment','wsrep_last_committed');"
# SUR CHAQUE NŒUD ARRÊTÉ
sudo cat /var/lib/mysql/grastate.dat
sudo galera_recovery
```

**Correction**

Selon le scénario de [03-galera/recovery.md](../03-galera/recovery.md) :

- nœuds en marche, réseau rétabli → le cluster se reforme seul ;
- tous arrêtés → bootstrap du nœud `safe_to_bootstrap: 1` (ou du `seqno` le plus élevé), **puis** `systemctl start mariadb` sur les autres.

Jamais de `galera_new_cluster` sur plusieurs nœuds.

**Validation**

```bash
# SUR CHAQUE NŒUD
./scripts/validation/check-galera.sh       # 3 / Primary / Synced / ON
```

**Leçon** : le comportement `non-Primary` est une protection, pas une panne de Galera. Un snapshot Proxmox avant chaque manipulation risquée simplifie la reprise.

---

## INC-02 — bind-address incorrect

*Date : `<AAAA-MM-JJ>` — VM : MYSQL-01, MYSQL-02, MYSQL-03*

**Symptôme**

```text
ERROR 2002 (HY000): Can't connect to MySQL server on '10.0.20.2' (111 "Connection refused")
```

Les nœuds ne se joignent pas sur 3306 ; le health-check HAProxy marque les serveurs DOWN.

**Cause probable**

Valeur par défaut Debian dans `/etc/mysql/mariadb.conf.d/50-server.cnf` :

```ini
bind-address = 127.0.0.1
```

MariaDB n'écoute que sur la boucle locale : toute connexion venant du réseau est **refusée** (le paquet arrive, mais aucun processus n'écoute sur l'IP du VLAN).

**Diagnostic**

`Connection refused` (refus immédiat) et non `timed out` : ce n'est pas le pare-feu, c'est le service.

**Commandes**

```bash
# SUR MYSQL-02
sudo ss -ltnp | grep 3306                     # 127.0.0.1:3306 → problème
grep -n bind-address /etc/mysql/mariadb.conf.d/*.cnf
```

**Correction**

Chaque nœud écoute sur **sa propre IP** du VLAN vBDD :

| Nœud | `bind-address` |
|------|----------------|
| MYSQL-01 | `10.0.20.1` |
| MYSQL-02 | `10.0.20.2` |
| MYSQL-03 | `10.0.20.3` |

```bash
# SUR MYSQL-02 (adapter l'IP sur chaque nœud)
sudo sed -i 's/^bind-address.*/bind-address            = 10.0.20.2/' /etc/mysql/mariadb.conf.d/50-server.cnf
sudo systemctl restart mariadb
```

Choix de l'IP précise plutôt que `0.0.0.0` : MariaDB n'est joignable que par l'interface prévue.

**Validation**

```bash
# SUR MYSQL-02
sudo ss -ltnp | grep 3306                     # 10.0.20.2:3306
# SUR HAPROXY
nc -zv 10.0.20.2 3306                         # succeeded
```

La CI vérifie désormais que `bind-address` = `wsrep_node_address` dans les fichiers d'exemple.

---

## INC-03 — dpkg interrompu

*Date : `<AAAA-MM-JJ>` — VM : plusieurs*

**Symptôme**

```text
E: dpkg was interrupted, you must manually run 'sudo dpkg --configure -a' to correct the problem.
```

Plus aucune commande `apt install` ne fonctionne.

**Cause probable**

Installation interrompue : session SSH coupée, VM redémarrée ou `Ctrl+C` pendant `apt install`, laissant des paquets à moitié configurés.

**Diagnostic**

```bash
# SUR LA VM CONCERNÉE
sudo dpkg --audit
ps aux | grep -E 'apt|dpkg' | grep -v grep      # une autre installation en cours ?
```

**Commandes / Correction**

```bash
# SUR LA VM CONCERNÉE
sudo dpkg --configure -a
sudo apt --fix-broken install -y
sudo apt update
```

**Validation**

```bash
sudo dpkg --audit            # aucune sortie
sudo apt install -y rsync    # une installation fonctionne à nouveau
```

**Prévention** : lancer les installations longues dans `tmux` ou `screen` pour survivre à une déconnexion. Fiche : [apt-dpkg.md](apt-dpkg.md)

---

## INC-04 — rsync absent

*Date : `<AAAA-MM-JJ>` — VM : MYSQL-0X / WEB-0X*

**Symptôme**

```text
bash: rsync: command not found
```

Côté Galera, un nœud ne parvient pas à rejoindre le cluster (journal : échec du script `wsrep_sst_rsync`) ; côté WordPress, la synchronisation WEB-01 → WEB-02 échoue.

**Cause probable**

`rsync` n'est pas installé par défaut sur une Debian minimale. La méthode SST `wsrep_sst_method = rsync` et la synchronisation de fichiers l'exigent **aux deux extrémités** (le binaire distant est lancé par SSH ou par le script SST).

**Diagnostic**

```bash
# SUR LES DEUX MACHINES CONCERNÉES
command -v rsync || echo "rsync absent"
# SUR LE NŒUD QUI NE REJOINT PAS
sudo journalctl -u mariadb -n 50 --no-pager | grep -i -E 'sst|rsync'
```

**Correction**

```bash
# SUR MYSQL-01, MYSQL-02, MYSQL-03, WEB-01, WEB-02
sudo apt install -y rsync
```

**Validation**

```bash
rsync --version | head -n1
# Galera : le nœud rejoint
./scripts/validation/check-galera.sh
```

`rsync` fait désormais partie des paquets installés par `install-galera.sh` et `install-wordpress-deps.sh`.

---

## INC-05 — GLPI : erreur 404 Apache

*Date : `<AAAA-MM-JJ>` — VM : GLPI-01*

**Symptôme**

La page d'accueil de GLPI s'affiche, mais la navigation (`/front/central.php`, après connexion) renvoie `404 Not Found`.

**Cause probable**

Problème de **RewriteRule** : GLPI 10 route toutes les requêtes vers `public/index.php`. Les règles de réécriture n'étaient pas appliquées correctement (placées hors du bloc `<Directory>`, et/ou `mod_rewrite` non activé), et `DocumentRoot` ne pointait pas sur `public/`.

**Diagnostic**

```bash
# SUR GLPI-01
apache2ctl -M | grep rewrite
apache2ctl -S
sudo grep -n -i -E 'DocumentRoot|Directory|Rewrite' /etc/apache2/sites-available/glpi.conf
sudo tail -n 20 /var/log/apache2/glpi-error.log
```

**Correction**

```bash
# SUR GLPI-01
sudo a2enmod rewrite
sudo cp configs/apache/glpi.conf.example /etc/apache2/sites-available/glpi.conf
sudo apachectl configtest && sudo systemctl reload apache2
```

Avec : `DocumentRoot /var/www/glpi/public` et les `RewriteCond`/`RewriteRule` **dans** `<Directory /var/www/glpi/public>`. Explication : [06-glpi/apache.md](../06-glpi/apache.md).

**Validation**

```bash
curl -sI http://10.0.10.3/front/central.php | head -n1    # 302 (vers login), plus de 404
./scripts/validation/check-glpi.sh
```

---

## INC-06 — SSH Permission denied (publickey)

*Date : `<AAAA-MM-JJ>` — VM : plusieurs*

**Symptôme**

```text
<ADMIN_USER>@10.0.20.1: Permission denied (publickey).
```

**Cause probable**

Confusion entre clé privée et clé publique : la **clé privée** avait été placée dans `~/.ssh/authorized_keys` du serveur.

`authorized_keys` doit contenir les **clés publiques autorisées** (`id_ed25519.pub`, une ligne commençant par `ssh-ed25519 AAAA…`), et **non** la clé privée (bloc multiligne dont l'en-tête contient `BEGIN OPENSSH PRIVATE KEY`). Autres causes possibles : droits trop ouverts sur `~/.ssh`, mauvais utilisateur.

**Diagnostic**

```bash
# SUR ADM-01 — mode verbeux : quelle clé est proposée ?
ssh -v <ADMIN_USER>@10.0.20.1 2>&1 | grep -E 'Offering|Authentications|denied'
# SUR LE SERVEUR (console Proxmox)
head -c 40 ~/.ssh/authorized_keys; echo       # doit commencer par ssh-ed25519
ls -ld ~/.ssh ~/.ssh/authorized_keys
sudo journalctl -u ssh -n 20 --no-pager
```

**Correction**

```bash
# SUR LE SERVEUR : retirer toute clé privée copiée par erreur
rm ~/.ssh/authorized_keys
# SUR ADM-01 : déposer la clé PUBLIQUE
ssh-copy-id -i ~/.ssh/id_ed25519.pub <ADMIN_USER>@10.0.20.1
# SUR LE SERVEUR : droits
chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys
```

Une clé privée qui a transité sur un serveur doit être considérée comme **exposée** : en générer une nouvelle et retirer l'ancienne clé publique de tous les serveurs.

**Validation**

```bash
# SUR ADM-01
ssh -o BatchMode=yes <ADMIN_USER>@10.0.20.1 hostname
```

---

## INC-07 — REMOTE HOST IDENTIFICATION HAS CHANGED

*Date : `<AAAA-MM-JJ>` — VM : ADM-01 (client)*

**Symptôme**

```text
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
Host key verification failed.
```

**Cause probable**

La VM répondant sur cette IP présente une clé d'hôte différente de celle mémorisée : VM **réinstallée** (nouvelles clés générées) ou IP **réattribuée** à une autre VM. Mais c'est aussi exactement le symptôme d'une attaque de l'**homme du milieu**.

**Diagnostic**

Ne **pas** supprimer l'entrée par réflexe. Vérifier d'abord :

1. La VM a-t-elle été réinstallée ou son IP réaffectée (par moi, récemment) ?
2. L'empreinte annoncée correspond-elle à celle de la VM, lue par un canal de confiance ?

```bash
# SUR LA VM (console Proxmox, canal de confiance)
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

Comparer avec l'empreinte `SHA256:…` affichée dans l'avertissement.

**Correction**

Uniquement si les empreintes correspondent :

```bash
# SUR ADM-01
ssh-keygen -R 10.0.20.1
ssh <ADMIN_USER>@10.0.20.1          # accepter la nouvelle empreinte
```

Si elles ne correspondent pas : **ne pas se connecter** ; rechercher une usurpation d'IP (doublon d'adresse, VM inconnue).

**Validation**

Connexion sans avertissement ; nouvelle empreinte enregistrée dans `~/.ssh/known_hosts`.

---

## INC-08 — Conflit avec le compte système haproxy

*Date : `<AAAA-MM-JJ>` — VM : HAPROXY*

**Symptôme**

Erreurs ou avertissements lors de `apt install haproxy` concernant l'utilisateur `haproxy` déjà existant ; service démarré avec un compte doté d'un shell et d'un répertoire personnel.

**Cause probable**

Lors de l'installation de Debian, l'utilisateur **humain** avait été nommé `haproxy`. Or le paquet `haproxy` crée un compte **système** du même nom (uid < 1000, shell `/usr/sbin/nologin`, home `/var/lib/haproxy`) pour exécuter le service avec des privilèges minimaux. Les deux usages entrent en conflit.

**Diagnostic**

```bash
# SUR HAPROXY
getent passwd haproxy          # uid ≥ 1000 et /bin/bash → compte humain : problème
id haproxy
```

**Correction**

Séparer les deux rôles :

| Compte | Type | Usage |
|--------|------|-------|
| `haproxyadmin` | Humain (uid ≥ 1000, sudo) | Administration de la VM |
| `haproxy` | Système (paquet) | Exécution du service |

```bash
# SUR HAPROXY (depuis la console ou un autre compte sudo)
sudo adduser haproxyadmin
sudo usermod -aG sudo haproxyadmin
# se reconnecter en haproxyadmin, vérifier sudo, puis :
sudo deluser --remove-home haproxy      # supprime le compte humain
sudo apt install --reinstall haproxy    # recrée le compte système proprement
```

**Validation**

```bash
getent passwd haproxy          # haproxy:x:1xx:...:/var/lib/haproxy:/usr/sbin/nologin
ps -o user= -C haproxy | sort -u   # haproxy
./scripts/validation/check-haproxy.sh
```

`install-haproxy.sh` détecte désormais ce cas avant l'installation.

---

## Ajouter un incident

Copier un bloc ci-dessus, incrémenter l'ID, renseigner tous les champs, ajouter la ligne au tableau et un commit `docs(troubleshooting): add INC-0X ...`. Méthode : [diagnostic-methodology.md](diagnostic-methodology.md).
