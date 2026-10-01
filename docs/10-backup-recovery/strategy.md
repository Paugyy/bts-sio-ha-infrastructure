# Stratégie de sauvegarde

## HA ≠ sauvegarde

| Événement | Protégé par la HA ? | Protégé par la sauvegarde ? |
|-----------|---------------------|-----------------------------|
| Panne d'un serveur web | Oui | — |
| Panne d'un nœud Galera | Oui | — |
| `DROP TABLE` accidentel | **Non** : répliqué instantanément sur les 3 nœuds | Oui |
| Extension WordPress qui corrompt la base | **Non** | Oui |
| Rançongiciel chiffrant les fichiers | **Non** | Oui (si sauvegarde hors ligne) |
| Panne de l'hôte Proxmox (disque) | **Non** (toutes les VM sur le même hôte) | Oui (si sauvegarde externe) |

La haute disponibilité protège contre la **panne** ; la sauvegarde protège contre la **perte de données**. Il faut les deux.

## Objectifs (proposés pour le lab)

| Indicateur | Valeur cible | Signification |
|------------|--------------|---------------|
| **RPO** | 24 h | Perte de données maximale acceptée |
| **RTO** | 4 h | Durée maximale de restauration du service |

## Périmètre

| Donnée | Méthode | Machine | Fréquence cible | Document |
|--------|---------|---------|-----------------|----------|
| Bases `wordpress`, `glpi` (+ comptes) | `mariadb-dump` | MYSQL-03 | Quotidienne | [mariadb.md](mariadb.md) |
| Fichiers WordPress | Archive `tar` | WEB-01 | Quotidienne | [wordpress.md](wordpress.md) |
| Fichiers GLPI (`files/`, `config/`) | Archive `tar` | GLPI-01 | Quotidienne | [glpi.md](glpi.md) |
| Configuration pfSense | Export XML **chiffré** | pfSense | À chaque modification | [proxmox.md](proxmox.md) |
| VM complètes | `vzdump` | Hôte Proxmox | Hebdomadaire | [proxmox.md](proxmox.md) |
| Configurations de référence | Ce dépôt Git (`.example`) | — | À chaque changement | — |

## Règle 3-2-1

- **3** copies des données (production + 2 sauvegardes) ;
- sur **2** supports différents ;
- dont **1** hors site (ou hors ligne).

Dans le lab : sauvegardes locales dans `/var/backups/` (copie 2) + copie vers un stockage externe à l'hôte Proxmox (copie 3). **Une sauvegarde restée sur le même hôte ne protège pas contre la panne de cet hôte.**

## Statut (v1.0.0)

| Élément | Statut |
|---------|--------|
| Scripts `backup-mariadb.sh`, `backup-wordpress.sh` | Fournis (non planifiés) |
| Planification cron | **Futur** (roadmap : sauvegardes automatisées) |
| Copie hors hôte | **Futur** |
| Test de restauration périodique | **Futur** (roadmap : tests de restauration) |

## Une sauvegarde non testée n'est pas une sauvegarde

Procédure de test proposée (trimestrielle) :

1. Créer une VM de test isolée (VLAN dédié ou sans réseau).
2. Restaurer la dernière sauvegarde MariaDB et WordPress.
3. Vérifier : le site s'affiche, le dernier article est présent, la connexion admin fonctionne.
4. Mesurer la durée (comparer au RTO) et consigner le résultat dans `evidence/test-results/`.
