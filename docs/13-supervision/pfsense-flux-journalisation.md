# pfSense : flux de la journalisation (NAT 2233, Syslog 514)

> Procédure rédigée le 06/11/2026. VM concernée : [règles pfSense](../../configs/pfsense/firewall-rules.md). Règles complètes : [matrice de flux](../01-architecture/network-flows.md). Côté serveur : [Rsyslog et LogAnalyzer](rsyslog-loganalyzer.md).
> L'export de configuration pfSense contient des **secrets** (comptes, empreintes de mots de passe) : il ne va **ni dans Git, ni dans le dossier remis**. Seule sa version assainie (tableaux ci-dessous) est publiée.

**Légende :** ✅ **fait et testé** · 🟨 **proposé, non testé** (ou à confirmer) · ⬜ **à faire**

## 1. Pourquoi, et où on en est

Le matin du 06/11, `http://10.4.0.198:2233/` ne répondait pas. L'export pfSense de 07:38 (`config-pfSense.home.arpa-20261106073806`) en donne la cause : **ni redirection NAT 2233 ni règle WAN vers `10.0.30.3:8085`** ([LOG-04](../09-troubleshooting/incidents.md)). Les serveurs des zones WEB et BDD ne pouvaient pas non plus joindre le collecteur : leurs blocages d'isolement vers vADMIN arrêtent le port 514.

Un fichier corrigé a été préparé, puis le transfert a été mis en place. **Dans la journée, les deux flux fonctionnent** :

| Flux | Preuve | État |
|---|---|---|
| `WAN:2233` → `10.0.30.3:8085` depuis le poste d'administration | Interface LogAnalyzer ouverte dans Chrome | ✅ |
| vWEB (4 serveurs) et vBDD (3 nœuds) → `10.0.30.3:514/TCP` | Tests directs et automatiques reçus des 7 machines ([Rsyslog et LogAnalyzer §4](rsyslog-loganalyzer.md)) | ✅ |
| Contenu **exact** des règles actives (fichier corrigé importé tel quel, ou saisie à la main ?) | Aucun export pris **après** la modification | 🟨 à relire (§3) |
| Journaux de pfSense lui-même | Non configurés | ⬜ (§5) |

## 2. Configuration cible (fichier corrigé)

| | Export de 07:38 | Fichier corrigé |
|---|---|---|
| Redirections NAT | 14 (dont 8083 désactivée) | **15** (+ 2233) |
| Règles de filtrage | 72 | **75** (+ 1 WAN, + 1 vWEB, + 1 vBDD) |
| Alias | 2 (`HAPROXY_WEB`, `AD_DC_PORTS`) | **5** (+ 3) |
| Règle WAN « HTTP vers WEB-02 » | active alors que son NAT 8083 est désactivé | **désactivée** (pas supprimée) |

Rien d'autre ne change : mêmes 14 NAT, mêmes ports Zabbix (2231, 2232), même IP `10.0.30.3`, `DEFAULT-DENY` toujours **dernière** règle de chaque interface.

**Alias** (*Firewall / Aliases*) :

| Nom | Type | Contenu | Remarque |
|---|---|---|---|
| `LOGANALYZER_ADMIN_NETS` | Réseaux | `10.2.0.0/24`, `10.4.0.0/24` | Contient le poste d'administration utilisé le 06/11 ; à réduire aux seuls réseaux d'administration réellement utilisés |
| `SYSLOG_WEB_SENDERS` | Hôtes | `10.0.10.1`, `10.0.10.2`, `10.0.10.3`, `10.0.10.4` | WEB-01, HAProxy, GLPI-01, WEB-02 |
| `SYSLOG_BDD_SENDERS` | Hôtes | `10.0.20.1`, `10.0.20.2`, `10.0.20.3` | Les 3 nœuds Galera |

**Redirection NAT** (*Firewall / NAT / Port Forward*) :

| Interface | Proto | Source | Destination | Port WAN | Redirige vers | Règle associée | État |
|---|---|---|---|---|---|---|---|
| WAN | TCP | `LOGANALYZER_ADMIN_NETS` | WAN address | **2233** | `10.0.30.3:8085` | règle WAN liée | ✅ flux · 🟨 source exacte à relire |

**Règles** (*Firewall / Rules*), position comprise :

| Onglet | Position | Action | Proto | Source | Destination | Pourquoi à cet endroit | État |
|---|---|---|---|---|---|---|---|
| WAN | 6, après le PASS Zabbix 80 | PASS | TCP | `LOGANALYZER_ADMIN_NETS` | `10.0.30.3:8085` | **Au-dessus** de `DEFAULT-DENY` (dernière) | ✅ flux · 🟨 position |
| vWEB | **2**, juste après HAProxy → Galera 3306 | PASS | TCP | `SYSLOG_WEB_SENDERS` | `10.0.30.3:514` | **Au-dessus** du `BLOCK vWEB → vADMIN` | ✅ flux · 🟨 position |
| vBDD | **1** | PASS | TCP | `SYSLOG_BDD_SENDERS` | `10.0.30.3:514` | **Au-dessus** du `BLOCK vBDD → vADMIN` | ✅ flux · 🟨 position |
| WAN | 4 | **désactivée** | TCP | any | `10.0.10.4:80` | Reste d'un NAT 8083 désactivé ; ne pas réactiver | 🟨 |
| vADMIN | — | aucune | — | `10.0.30.2` (guacamol) | `10.0.30.3:514` | Même VLAN : le trafic ne passe pas par le filtrage | ✅ (guacamol reçu) |

> **Rappel** — Aucun NAT sur 514 (TCP/UDP), 10050, 10051, 3306 ni UDP 161 : ces ports ne sortent jamais du labo.

## 3. Relire la configuration active (à faire en premier)

Un navigateur qui s'ouvre prouve qu'un chemin existe, **pas** que toutes les règles sont celles prévues.

| # | Action | Où | Attendu |
|---|---|---|---|
| 1 | Exporter la configuration du jour | *Diagnostics / Backup & Restore / Download configuration as XML* — fichier rangé **hors de Git** | — |
| 2 | Compter NAT et règles | *Firewall / NAT* et *Firewall / Rules* (5 onglets) | 15 NAT, 75 règles si le fichier corrigé a été importé tel quel |
| 3 | Vérifier l'ordre | Onglets vWEB et vBDD | PASS 514 **au-dessus** des `ISOLATION`, `DEFAULT-DENY` en dernier partout |
| 4 | Vérifier la source du NAT 2233 | *Firewall / NAT*, ligne 2233 | Alias limité aux réseaux d'administration, **jamais** `any` |
| 5 | Mettre à jour la [matrice de flux](../01-architecture/network-flows.md) | — | Colonne État passée de 🟨 à ✅ |
| 6 | Captures | NAT 2233 ; règles vWEB et vBDD | Rangées dans `evidence/screenshots/` |

## 4. Reconstruire ces flux (si besoin)

**Avant :** sauvegarder la configuration (§3-1), avoir la console Proxmox de `sio2527-fw-01-ypaugy` (VMID 610), relever l'adresse du poste (`ipconfig`), adapter la liste d'adresses Apache ([Rsyslog et LogAnalyzer §2](rsyslog-loganalyzer.md)) — sinon le NAT fonctionne mais Apache répond `403`.

**Option A — saisie dans l'interface (recommandée)** : pas de redémarrage, chaque ajout est traçable. Créer les 3 alias, le NAT 2233 (*Filter rule association : Add associated filter rule*), les 2 règles Syslog **glissées à leur position** (§2), puis désactiver la règle WAN vers `10.0.10.4:80`. *Apply Changes*.

**Option B — restauration du fichier corrigé** : *Diagnostics / Backup & Restore / Restore Backup*, zone *All*. pfSense redémarre, tout le labo est coupé quelques minutes. Seulement si aucune modification n'a été faite depuis l'export de 07:38 : sinon elle serait effacée.

## 5. Envoi des journaux de pfSense (à faire)

Ce réglage **n'est pas dans le fichier XML** : il se fait à la main.

**SUR sio2527-fw-01-ypaugy — interface web** → *Status / System Logs / Settings*, rubrique *Remote Logging Options* (intitulés à vérifier sur la version 2.7.0) :

| Champ | Valeur | Pourquoi |
|---|---|---|
| Send log messages to remote syslog server | coché | Active l'envoi |
| Source Address | interface **vADMIN** | Les messages partent de `10.0.30.254`, dans la zone du collecteur |
| IP Protocol | IPv4 | — |
| Remote log servers | `10.0.30.3:514` | Collecteur Rsyslog (UDP) |
| Remote Syslog Contents | *System Events*, *Firewall Events*, *General Authentication Events* au minimum | Ce qui sert à l'analyse d'un incident |

Aucune règle ni NAT à créer : c'est le pare-feu lui-même qui émet. Contrôle **SUR 10.0.30.3** : `sudo grep -i 'filterlog\|pfSense' /var/log/remote-syslog/central.log | tail`, puis l'hôte pfSense dans LogAnalyzer. **À ne pas déclarer actif avant cette preuve.**

## 6. Retour arrière

| Situation | Action |
|---|---|
| Interface web pfSense accessible | *Diagnostics / Backup & Restore / Restore Backup*, zone *All*, fichier sauvegardé avant la modification → redémarrage |
| Interface web perdue | Console Proxmox de fw-01 → menu console, *Restore recent configuration*, puis restaurer la sauvegarde |
| Un seul ajout pose problème | Le désactiver (case *Disable*), *Apply Changes* |
| Côté Apache | Remettre l'ancienne liste `Require` ([Rsyslog et LogAnalyzer](rsyslog-loganalyzer.md#retour-arrière)) |

## 7. Recette

Noter pour chaque test : date, heure, **adresse IP source exacte du poste**, résultat, capture. Tests T21 à T35 de la [matrice de validation](../08-tests/validation-matrix.md).

| # | Test | Depuis | Commande | Attendu | État |
|---|---|---|---|---|---|
| 1 | Zabbix toujours publié | Poste admin | `http://10.4.0.198:2231/zabbix/` | page de connexion | ✅ en local (`200`) · ⬜ depuis le poste |
| 2 | SSH Zabbix toujours publié | Poste admin | `Test-NetConnection 10.4.0.198 -Port 2232` | `True` | ⬜ |
| 3 | LogAnalyzer joignable | Poste d'administration | Chrome `http://10.4.0.198:2233/` | `401`, puis interface | ✅ |
| 4 | Journaux de vWEB et vBDD | 7 serveurs | `logger -n 10.0.30.3 -P 514 -T …` | lignes dans `central.log` | ✅ |
| 5 | Événements pfSense | fw-01 | réglage §5, puis une connexion à l'interface | lignes `filterlog` ou d'authentification | ⬜ |
| 6 | Source non autorisée bloquée | cli-01 (10.0.40.1) | `Test-NetConnection 10.0.30.3 -Port 514` | `False`, refus journalisé | ⬜ |
| 7 | `BLOCK ALL` en bas de chaque interface | pfSense | *Firewall / Rules*, 5 onglets | `DEFAULT-DENY` en dernier partout | ⬜ |
