# Configuration pfSense

pfSense se configure par l'interface web : il n'existe pas de fichier texte équivalent à `haproxy.cfg`.
Ce dossier décrit donc la configuration **sous forme de tableaux**, reproductibles à la main.

| Fichier | Contenu |
|---------|---------|
| [`nat-rules.md`](nat-rules.md) | Redirections de ports (Port Forward) et NAT sortant |
| [`firewall-rules.md`](firewall-rules.md) | Règles de filtrage par interface (WAN, vWEB, vBDD, vADMIN, vUSER) |

## Pourquoi pas d'export `config.xml` ?

L'export de sauvegarde pfSense (*Diagnostics → Backup & Restore*) contient les **hash des mots de passe**, les **clés privées** des certificats et VPN, et parfois des identifiants en clair. Il ne doit **jamais** être publié ; `.gitignore` bloque `config-*.xml` et `pfsense-config*.xml`.

Conserver l'export dans un emplacement privé (coffre de mots de passe, stockage chiffré) — voir [docs/10-backup-recovery/strategy.md](../../docs/10-backup-recovery/strategy.md).

## Légende des statuts

| Statut | Signification |
|--------|---------------|
| **Réel** | Règle en place dans le lab |
| **Modèle** | Règle recommandée, à confronter à la configuration réelle avant publication |
| **Futur** | Amélioration prévue |

Documentation détaillée : [docs/02-pfsense/](../../docs/02-pfsense/installation.md)
