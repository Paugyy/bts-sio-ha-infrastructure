# Glossaire

| Terme | Définition |
|-------|------------|
| **Backend** | Groupe de serveurs vers lesquels HAProxy redirige le trafic (ex. `be_wordpress` = WEB-01 + WEB-02). |
| **Bootstrap** | Démarrage d'un **nouveau** cluster Galera à partir d'un seul nœud (`galera_new_cluster`). À ne faire qu'une fois, sur le nœud le plus à jour. |
| **CARP** | Protocole de redondance de pfSense (équivalent de VRRP) permettant deux pare-feu en actif/passif. |
| **Certification** | Étape Galera où chaque transaction est vérifiée contre les écritures concurrentes des autres nœuds avant validation. |
| **Deny-by-default** | Politique de filtrage : tout est interdit sauf ce qui est explicitement autorisé. |
| **DNAT / Port Forward** | Traduction de l'adresse de destination : `10.4.0.198:8081` devient `10.0.10.2:80`. |
| **Failover** | Bascule automatique du service vers un composant sain lorsqu'un composant tombe. |
| **Frontend** | Point d'écoute de HAProxy (IP + port) recevant les connexions clientes. |
| **Galera** | Bibliothèque de réplication **synchrone multi-maître** pour MariaDB. |
| **gcomm://** | Préfixe de l'adresse de cluster Galera listant les membres. |
| **grastate.dat** | Fichier d'état Galera (`/var/lib/mysql/grastate.dat`) : UUID du cluster, numéro de séquence (`seqno`), `safe_to_bootstrap`. |
| **HA (haute disponibilité)** | Capacité d'un service à rester disponible malgré la panne d'un composant. |
| **Health-check** | Test périodique effectué par HAProxy pour savoir si un serveur est sain. |
| **IST** | *Incremental State Transfer* : un nœud brièvement absent ne reçoit que les transactions manquées (port 4568). |
| **Keepalived** | Démon implémentant VRRP pour partager une IP virtuelle entre deux serveurs Linux. |
| **Load-balancing** | Répartition de la charge entre plusieurs serveurs. |
| **NAT** | *Network Address Translation* : modification des adresses IP d'un paquet par un routeur. |
| **Primary** | Composant Galera disposant du quorum : seul autorisé à accepter des écritures. |
| **Quorum** | Majorité stricte des nœuds (plus de 50 %) nécessaire pour que le cluster reste `Primary`. |
| **Round-robin** | Algorithme de répartition « chacun son tour ». |
| **RPO / RTO** | Perte de données maximale admissible / durée d'interruption maximale admissible. |
| **safe_to_bootstrap** | Indicateur de `grastate.dat` : `1` sur le dernier nœud arrêté proprement, seul candidat sûr au bootstrap. |
| **seqno** | Numéro de la dernière transaction appliquée par un nœud. Le plus élevé indique le nœud le plus à jour. |
| **SPOF** | *Single Point Of Failure* : composant unique dont la panne arrête le service. |
| **Split-brain** | Situation où deux parties d'un cluster se croient chacune maîtresse et divergent. Le quorum l'empêche. |
| **SST** | *State Snapshot Transfer* : copie complète des données vers un nœud qui rejoint (port 4444). |
| **Synced** | État d'un nœud Galera à jour et prêt à servir. |
| **Trunk 802.1Q** | Lien transportant plusieurs VLAN identifiés par une étiquette (tag). |
| **VIP** | *Virtual IP* : adresse IP flottante portée par le serveur actif d'une paire. |
| **VLAN** | Réseau local virtuel : segmentation logique d'un réseau physique. |
| **wsrep** | *Write Set REPlication* : API de réplication utilisée par Galera ; préfixe de ses variables. |
