# Haute disponibilité

## Définitions

| Notion | Définition | Dans ce projet |
|--------|------------|----------------|
| **Haute disponibilité** | Le service continue malgré la panne d'un composant | 2 serveurs web, 3 nœuds SQL |
| **Répartition de charge** | Le travail est partagé entre plusieurs serveurs | HAProxy round-robin |
| **Failover** | Bascule automatique vers un composant sain | Health-checks HAProxy, quorum Galera |
| **Sauvegarde** | Copie restaurable des données à un instant donné | Hors HA : voir [10-backup-recovery](../10-backup-recovery/strategy.md) |

La répartition de charge **n'implique pas** la haute disponibilité (sans health-check, HAProxy enverrait du trafic vers un serveur mort), et la haute disponibilité **ne remplace pas** la sauvegarde (une suppression est répliquée partout).

## Mécanismes mis en œuvre

### Couche web — redondance active/active

- WEB-01 et WEB-02 servent simultanément.
- HAProxy teste `/wp-login.php` toutes les **3 s** (`inter 3s`).
- Après **3 échecs** (`fall 3`, ~9 s), le serveur est retiré.
- Pendant ce délai, une requête échouée est **rejouée** sur l'autre serveur (`retries 3` + `option redispatch`).
- Après **2 succès** (`rise 2`, ~6 s), le serveur est réintégré.

<p align="center"><img src="../../diagrams/failover-web.svg" alt="Failover web" width="750"></p>

### Couche données — cluster synchrone avec quorum

- Chaque transaction est **certifiée** par le cluster puis appliquée sur tous les nœuds : aucune perte de données validée lors de la panne d'un nœud.
- **Quorum** : un composant reste `Primary` s'il regroupe **plus de la moitié** des nœuds connus.

| Nœuds en vie | Majorité ? | État | Service |
|--------------|-----------|------|---------|
| 3 / 3 | Oui | Primary | Nominal |
| 2 / 3 | Oui (2 > 1,5) | Primary | Dégradé, fonctionnel |
| 1 / 3 | Non (1 < 1,5) | non-Primary | **Refuse lectures et écritures** |

Un nœud isolé se met en `non-Primary` **volontairement** : c'est ce qui empêche le *split-brain* (deux moitiés qui écriraient chacune de leur côté).

### Accès SQL — retrait automatique

HAProxy vérifie chaque nœud (`option mysql-check`) et coupe les sessions d'un nœud déclaré DOWN (`on-marked-down shutdown-sessions`) pour forcer la reconnexion sur un nœud sain.

## Calcul de disponibilité (illustratif)

Si un serveur web est disponible 99 % du temps et que les pannes sont indépendantes :

- 1 serveur : 99 % → ~87 h d'indisponibilité par an ;
- 2 serveurs : 1 − (0,01 × 0,01) = 99,99 % → ~53 min par an.

Ce calcul **ignore les SPOF** (HAProxy, pfSense, hôte Proxmox) qui plafonnent la disponibilité réelle de l'ensemble : voir [spof-analysis.md](spof-analysis.md).
