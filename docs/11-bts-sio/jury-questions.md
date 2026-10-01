# Questions probables du jury

## Pourquoi Galera ?

Galera offre une réplication **synchrone multi-maître** : une transaction confirmée est présente sur tous les nœuds, donc la panne d'un nœud ne fait perdre **aucune donnée validée** et ne demande **aucune bascule manuelle** (les autres nœuds sont déjà à jour et acceptent les écritures). La réplication classique primaire/réplique est asynchrone : la panne du primaire peut perdre les dernières transactions et impose de promouvoir une réplique. Galera est intégré à MariaDB et disponible dans les dépôts Debian.

## Pourquoi 3 nœuds ?

À cause du **quorum** : un groupe de nœuds reste actif (`Primary`) seulement s'il représente **plus de la moitié** du cluster. Avec 2 nœuds, la perte de l'un laisse 50 % : pas de majorité, le cluster s'arrête — 2 nœuds n'apportent donc pas de tolérance aux pannes. Avec 3 nœuds, les 2 survivants représentent 67 % : le service continue. C'est le **minimum** pour tolérer une panne ; 5 nœuds en tolèrent 2.

## Pourquoi HAProxy ?

Les applications n'acceptent qu'**une adresse** de serveur. HAProxy fournit une adresse stable (`10.0.10.2`) devant plusieurs serveurs, **répartit** la charge et surtout **vérifie** en permanence l'état de chaque serveur (health-checks) pour écarter automatiquement ceux qui sont en panne. Il sait faire du HTTP (couche 7 : cookies, codes de retour, en-têtes) et du TCP (couche 4 : SQL), ce qui permet un seul outil pour WordPress, GLPI et MariaDB. Il est libre, léger et standard dans l'industrie.

## Pourquoi 2 serveurs WordPress ?

Pour que la panne d'un serveur web (crash, mise à jour, redémarrage) n'interrompe pas le site. Avec deux serveurs actifs derrière HAProxy, l'un peut tomber ou être mis en maintenance pendant que l'autre sert tout le trafic. Cela double aussi la capacité de traitement.

## Pourquoi Galera ne synchronise-t-il pas les fichiers WordPress ?

Galera est un mécanisme de réplication de **base de données** : il réplique des transactions SQL. Les médias, thèmes et extensions de WordPress sont des **fichiers** sur le disque de chaque serveur, hors de la base. La base contient seulement la *référence* à une image (son chemin) ; le fichier lui-même doit être copié par un autre moyen : `rsync` dans ce projet, stockage partagé (NFS, GlusterFS) en amélioration.

## Pourquoi des VLAN ?

Pour **segmenter** le réseau par niveau de confiance (web exposé, bases sensibles, administration, utilisateurs). Tout flux entre VLAN passe par pfSense et doit être explicitement autorisé. Si un serveur web est compromis, l'attaquant ne peut pas atteindre librement les bases : seul HAProxy est autorisé vers le port 3306. Les VLAN limitent aussi les diffusions (broadcast) et clarifient l'administration.

## Pourquoi un firewall deny-by-default ?

Parce qu'une erreur doit **fermer** plutôt qu'**ouvrir**. En interdisant tout par défaut, un oubli se traduit par un service bloqué (visible, corrigé en testant) et non par une ouverture involontaire (invisible, exploitable). La liste des règles devient la documentation exacte des flux autorisés. C'est le principe du moindre privilège appliqué au réseau.

## Que se passe-t-il si HAProxy tombe ?

**Tout s'arrête** : WordPress, GLPI et l'accès SQL passent par HAProxy. C'est le **SPOF principal** du projet, identifié dans l'analyse. La solution est d'ajouter un second HAProxy et **Keepalived** (protocole VRRP) qui fait porter une **IP virtuelle** `10.0.10.2` par le HAProxy actif ; en cas de panne, l'IP bascule sur le second en 1 à 3 secondes, sans changer la configuration des clients.

## Que se passe-t-il si deux MySQL tombent ?

Cela dépend de **comment** ils tombent :

- **arrêt propre** (`systemctl stop`) : chaque départ est annoncé, le cluster se réduit à 1 nœud qui reste `Primary` et continue de servir (sans plus aucune redondance) ;
- **panne brutale** (crash, coupure réseau) : le nœud restant ne voit plus que 1/3 du cluster, il perd le **quorum**, passe `non-Primary` et **refuse les requêtes**. WordPress et GLPI affichent une erreur de base de données. C'est volontaire : mieux vaut un service arrêté que des données qui divergent (*split-brain*). La reprise est manuelle et réfléchie ([recovery.md](../03-galera/recovery.md)).

## Quelle différence entre HA et sauvegarde ?

La **haute disponibilité** protège contre la **panne** d'un composant : le service continue. La **sauvegarde** protège contre la **perte ou l'altération des données** : on peut revenir à un état antérieur. Avec Galera, un `DROP TABLE` accidentel est répliqué instantanément sur les trois nœuds : la HA ne sert à rien, seule une sauvegarde permet de récupérer. Les deux sont complémentaires.

## Comment améliorer l'infrastructure ?

Par ordre de priorité ([spof-analysis.md](../01-architecture/spof-analysis.md)) :

1. **HAProxy redondé** + Keepalived (IP virtuelle).
2. **Health-check Galera wsrep-aware** (n'envoyer du SQL qu'aux nœuds `Synced`).
3. **Stockage partagé** pour les fichiers WordPress.
4. **HTTPS** (certificats).
5. **Supervision** (Prometheus + Grafana, ou Zabbix / Centreon) avec alertes.
6. **Sauvegardes automatisées** externalisées et **tests de restauration**.
7. **pfSense en CARP**, puis **cluster Proxmox** pour la redondance physique.

## Questions complémentaires possibles

| Question | Éléments de réponse |
|----------|---------------------|
| Qu'est-ce qu'un SST / IST ? | Transfert complet (copie de toutes les données) / incrémental (transactions manquées seulement) lors du retour d'un nœud |
| Pourquoi `innodb_autoinc_lock_mode = 2` ? | Évite les verrous de table sur AUTO_INCREMENT, incompatibles avec le multi-maître |
| Pourquoi le compte SQL est-il `@'10.0.10.2'` ? | HAProxy est un proxy TCP : MariaDB voit l'IP de HAProxy, pas celle du serveur web |
| Pourquoi le NAT vise-t-il HAProxy et pas WEB-01 ? | Sinon la panne de WEB-01 coupe le site et WEB-02 ne sert à rien |
| Round-robin SQL en écriture : un risque ? | Conflits de certification possibles en forte concurrence ; en production, un seul nœud écrivain |
| Pourquoi `bind-address` sur l'IP et pas `0.0.0.0` ? | N'écouter que sur l'interface prévue ; `127.0.0.1` bloquait tout accès réseau (incident INC-02) |
