# Sauvegarde et restauration — Proxmox et pfSense

## Snapshots ou sauvegardes ?

| | Snapshot Proxmox | Sauvegarde `vzdump` |
|---|------------------|---------------------|
| Emplacement | Même stockage que la VM | Fichier indépendant (`.vma.zst`) |
| Survit à la perte du disque | **Non** | Oui, si stocké ailleurs |
| Usage | Retour arrière rapide avant une manipulation | Restauration après sinistre |
| Durée de conservation | Courte (heures, jours) | Longue (semaines) |

**Snapshot** avant toute opération risquée (bootstrap Galera, mise à jour, changement de règles pfSense). **Sauvegarde** pour la protection réelle.

## Snapshots

**SUR L'HÔTE PROXMOX**

```bash
# Avant une campagne de tests de panne (exemple avec les VMID 105, 106, 107 = MYSQL-01/02/03)
for id in 105 106 107; do qm snapshot "$id" avant-tests-$(date +%Y%m%d) --description "Avant tests T20"; done
qm listsnapshot 105
# Retour arrière si nécessaire
qm rollback 105 avant-tests-AAAAMMJJ
```

> Snapshot d'un nœud Galera **en marche** : à la restauration, le nœud revient avec un état ancien et se resynchronise par IST/SST — c'est sans danger tant qu'on ne restaure pas **les trois** à des instants différents.

## Sauvegardes vzdump

**SUR L'HÔTE PROXMOX** (*Datacenter → Backup → Add*, ou en ligne de commande)

```bash
vzdump 105 --mode snapshot --compress zstd --storage <STOCKAGE_BACKUP>
```

| Paramètre | Recommandation |
|-----------|----------------|
| Mode | `snapshot` (sans arrêt de la VM) |
| Stockage | **Distinct** du stockage des VM : NFS, Proxmox Backup Server, disque externe |
| Fréquence | Hebdomadaire (lab) |
| Rétention | 4 sauvegardes |

Restauration : *Storage → Backups → Restore*, ou `qmrestore <fichier> <vmid>`.

## pfSense

**SUR PFSENSE** (*Diagnostics → Backup & Restore*)

- **Backup area** : All.
- Cocher **Encrypt this configuration file** et choisir une phrase de passe forte (stockée dans le gestionnaire de mots de passe).
- Télécharger le fichier XML **chiffré** et le stocker hors du lab.

> L'export contient hash de mots de passe, clés et certificats : **jamais** dans ce dépôt (`.gitignore` bloque `config-*.xml`). Les règles sont documentées sous forme de tableaux dans [configs/pfsense/](../../configs/pfsense/README.md).

Restauration : même menu, *Restore configuration*, en fournissant la phrase de passe.
