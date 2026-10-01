# Galera — Dépannage

Fiches détaillées et incidents réels : [09-troubleshooting/galera.md](../09-troubleshooting/galera.md) et [incidents.md](../09-troubleshooting/incidents.md).

## Arbre de décision

```text
check-galera.sh en échec
│
├── "Connexion à MariaDB impossible"
│     └── systemctl status mariadb ──► inactif ? ──► journalctl -u mariadb -n 50
│
├── wsrep_cluster_size < 3
│     ├── nœud manquant arrêté ? ──► systemctl start mariadb (PAS de bootstrap)
│     └── nœud en marche mais isolé ? ──► réseau / ports 4567-4568-4444 / cluster_name
│
├── wsrep_cluster_status = non-Primary
│     └── perte de quorum ──► recovery.md (NE PAS redémarrer au hasard)
│
├── wsrep_local_state_comment ≠ Synced
│     ├── Joiner / Donor ──► SST en cours : attendre, surveiller le journal
│     └── bloqué ──► rsync présent ? port 4444 ouvert ? espace disque ?
│
└── wsrep_ready = OFF
      └── le nœud n'accepte pas de requêtes ──► voir état et statut ci-dessus
```

## Commandes de diagnostic

| Objectif | Commande (SUR LE NŒUD CONCERNÉ) |
|----------|----------------------------------|
| Journal | `sudo journalctl -u mariadb -n 100 --no-pager` |
| Fichier d'erreurs | `sudo tail -n 100 /var/log/mysql/error.log` |
| Ports en écoute | `sudo ss -ltnp \| grep -E '3306\|4567\|4568\|4444'` |
| Joindre un voisin | `nc -zv 10.0.20.2 4567` |
| État Galera | `sudo cat /var/lib/mysql/grastate.dat` |
| Membres vus | `sudo mariadb -e "SHOW STATUS LIKE 'wsrep_incoming_addresses'"` |
| Configuration effective | `sudo mariadb -e "SHOW VARIABLES LIKE 'wsrep_%'"` |
| Espace disque | `df -h /var/lib/mysql` |

## Messages fréquents

| Message dans le journal | Cause | Correction |
|-------------------------|-------|------------|
| `Can't connect to MySQL server ... (111 "Connection refused")` | Service arrêté ou `bind-address = 127.0.0.1` | [INC-02](../09-troubleshooting/incidents.md#inc-02--bind-address-incorrect) |
| `WSREP: failed to open gcomm backend connection: 110: failed to reach primary view` | Aucun pair joignable | Démarrer un nœud du cluster d'abord ; ou bootstrap si création |
| `WSREP: It may not be safe to bootstrap the cluster from this node` | `safe_to_bootstrap: 0` | [recovery.md](recovery.md) |
| `rsync: command not found` / `wsrep_sst_rsync ... failed` | rsync absent | [INC-04](../09-troubleshooting/incidents.md#inc-04--rsync-absent) |
| `gcs connect failed: Connection timed out` | Port 4567 filtré | Pare-feu local / VLAN |
| `node uses different cluster name` (`wsrep_cluster_name` différent) | Faute de frappe | Aligner `wsrep_cluster_name` sur les 3 nœuds |
| `Deadlock found when trying to get lock` (côté application) | Conflit de certification multi-maître | Rejouer la transaction ; envisager un écrivain unique |
