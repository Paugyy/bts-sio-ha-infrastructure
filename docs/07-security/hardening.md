# Sécurité — Durcissement

Mesures de durcissement par composant. Le statut distingue ce qui est **en place** (intégré à la configuration de référence v1.0.0 et aux fichiers de `configs/`) de ce qui est **recommandé** (non déployé) ou **futur**. Avant une soutenance, confirmer chaque ligne « En place » sur les VM réelles.

## Toutes les VM Debian

| Mesure | Commande / fichier | Statut |
|--------|--------------------|--------|
| Mises à jour de sécurité | `sudo apt update && sudo apt upgrade` | En place (manuel) |
| Mises à jour automatiques de sécurité | `sudo apt install unattended-upgrades` | Recommandé |
| SSH par clé, sans root | [ssh.md](ssh.md) | En place |
| Services inutiles désactivés | `systemctl list-units --type=service --state=running` | À vérifier par VM |
| Horloge synchronisée | `timedatectl` (systemd-timesyncd) | En place |
| Journaux persistants | `journalctl --disk-usage` | Par défaut Debian 12 |

## nftables sur les nœuds Galera

Exemple de pare-feu local (statut : **recommandé**, à tester avant déploiement). Il restreint les ports Galera aux deux autres nœuds, et 3306 à HAProxy.

**SUR MYSQL-01** — `/etc/nftables.conf` (adapter `self` pour MYSQL-02 et MYSQL-03)

```text
#!/usr/sbin/nft -f
flush ruleset

table inet filter {
    set galera_peers { type ipv4_addr; elements = { 10.0.20.1, 10.0.20.2, 10.0.20.3 } }

    chain input {
        type filter hook input priority 0; policy drop;
        iif lo accept
        ct state established,related accept
        ip protocol icmp accept
        ip saddr 10.0.30.0/24 tcp dport 22 accept                     # SSH depuis vADMIN
        ip saddr 10.0.10.2 tcp dport 3306 accept                      # SQL depuis HAProxy
        ip saddr @galera_peers tcp dport { 3306, 4444, 4567, 4568 } accept
        ip saddr @galera_peers udp dport 4567 accept
    }
    chain forward { type filter hook forward priority 0; policy drop; }
    chain output  { type filter hook output priority 0; policy accept; }
}
```

```bash
sudo nft -c -f /etc/nftables.conf        # vérification de syntaxe
sudo systemctl enable --now nftables
```

> Appliquer **d'abord sur un seul nœud**, vérifier `check-galera.sh` et l'accès SSH, puis généraliser. Une erreur bloque SSH : garder la console Proxmox à portée.

## HAProxy

| Mesure | Statut |
|--------|--------|
| Page de stats protégée par mot de passe **et** ACL vADMIN | En place |
| `stats hide-version` | En place |
| `chroot /var/lib/haproxy`, compte `haproxy` non privilégié | En place (défaut Debian) |
| En-tête `X-Served-By` | En place pour la démonstration — **à retirer en production** (révèle l'architecture interne) |
| TLS (HTTPS) | Futur |

## Apache / PHP

| Mesure | Statut |
|--------|--------|
| `ServerTokens Prod`, `ServerSignature Off` (`/etc/apache2/conf-available/security.conf`) | Recommandé |
| Accès direct refusé à `wp-config.php`, `readme.html` | En place (vhost) |
| `DISALLOW_FILE_EDIT` dans WordPress | En place |
| `expose_php = Off` dans `php.ini` | Recommandé |
| GLPI : `DocumentRoot` sur `public/`, `install.php` supprimé | En place |

## MariaDB

| Mesure | Statut |
|--------|--------|
| `bind-address` sur l'IP du VLAN vBDD (pas `0.0.0.0`) | En place |
| `mariadb-secure-installation` | En place |
| root uniquement via unix_socket | En place (défaut Debian) |
| Chiffrement TLS de la réplication Galera | Futur |

## pfSense

| Mesure | Statut |
|--------|--------|
| Mot de passe admin changé | En place |
| Interface web accessible depuis vADMIN uniquement | En place |
| Deny-by-default sur les interfaces internes | En place |
| Sauvegarde chiffrée de `config.xml` | Recommandé |
