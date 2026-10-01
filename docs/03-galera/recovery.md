# Galera — Reprise après panne

> **Principe** : comprendre l'état avant d'agir. Un bootstrap sur le mauvais nœud **efface définitivement** les transactions les plus récentes (les autres nœuds se resynchronisent sur un état plus ancien). Rien n'est automatisé ici.

## Outils de diagnostic

### grastate.dat

**SUR CHAQUE NŒUD ARRÊTÉ**

```bash
sudo cat /var/lib/mysql/grastate.dat
```

```text
# GALERA saved state
version: 2.1
uuid:    8f3c...-....-....-....-............
seqno:   1842
safe_to_bootstrap: 0
```

| Champ | Signification |
|-------|---------------|
| `uuid` | Identifiant du cluster ; doit être identique sur les 3 nœuds |
| `seqno` | Dernière transaction appliquée. `-1` : arrêt brutal, valeur inconnue (voir `galera_recovery`) |
| `safe_to_bootstrap` | `1` sur le **dernier nœud arrêté proprement** : seul candidat sûr |

### galera_recovery

Quand `seqno: -1` (crash), la position réelle est lue dans les journaux InnoDB :

**SUR CHAQUE NŒUD ARRÊTÉ**

```bash
sudo galera_recovery
```

```text
--wsrep_start_position=8f3c...:1842
```

Le nombre après `:` est le `seqno` réel. **Comparer les trois nœuds** : le plus élevé est le plus à jour.

### État d'un nœud en marche

```bash
sudo mariadb -e "SHOW STATUS WHERE Variable_name IN ('wsrep_cluster_size','wsrep_cluster_status','wsrep_local_state_comment','wsrep_last_committed');"
```

## Scénarios

### 1. Un nœud tombe, les deux autres tournent

**Situation normale de la HA.** Les deux nœuds restants sont `Primary` (2/3).

**SUR LE NŒUD TOMBÉ**

```bash
sudo systemctl start mariadb
```

Il rejoint seul le cluster par IST (ou SST si trop en retard). **Pas de bootstrap.**

### 2. Les 3 nœuds ont été arrêtés proprement

Le dernier arrêté a `safe_to_bootstrap: 1`.

1. **SUR LES 3 NŒUDS** : `sudo cat /var/lib/mysql/grastate.dat`
2. **SUR LE NŒUD AVEC `safe_to_bootstrap: 1`** : `sudo galera_new_cluster`
3. **SUR LES DEUX AUTRES**, l'un après l'autre : `sudo systemctl start mariadb`

### 3. Les 3 nœuds ont crashé (coupure électrique de l'hôte Proxmox)

Tous ont `safe_to_bootstrap: 0` et souvent `seqno: -1`.

1. **SUR LES 3 NŒUDS** : `sudo galera_recovery` → noter le `seqno`.
2. Choisir le nœud au **`seqno` le plus élevé** (en cas d'égalité : n'importe lequel des ex-aequo).
3. **SUR CE NŒUD UNIQUEMENT** : passer `safe_to_bootstrap` à 1 **en connaissance de cause** :

   ```bash
   sudo sed -i 's/^safe_to_bootstrap: 0/safe_to_bootstrap: 1/' /var/lib/mysql/grastate.dat
   sudo galera_new_cluster
   ```

4. **SUR LES DEUX AUTRES** : `sudo systemctl start mariadb`.
5. Valider avec `check-galera.sh` sur chaque nœud, puis vérifier l'application (WordPress, GLPI).

### Perte de quorum sans arrêt

Exemple : coupure réseau isolant chaque nœud ; tous sont en marche mais `non-Primary`.

- Si le réseau revient, le cluster se reforme **seul**.
- Si un groupe doit reprendre le service sans attendre, **sur un nœud du groupe choisi** (le plus à jour) :

  ```sql
  SET GLOBAL wsrep_provider_options='pc.bootstrap=YES';
  ```

  Les nœuds de l'autre groupe devront ensuite être redémarrés (`systemctl restart mariadb`) pour se resynchroniser.

## Quorum et split-brain : rappel

| Nœuds vivants (sur 3) | Action automatique | Intervention humaine |
|-----------------------|--------------------|----------------------|
| 3 | — | — |
| 2 | Restent Primary | Redémarrer le 3e nœud |
| 1 (les 2 autres arrêtés **proprement**) | Reste Primary (taille recalculée à 1) | Redémarrer les autres |
| 1 (les 2 autres **disparus brutalement**) | Passe non-Primary, refuse le SQL | Analyse puis `pc.bootstrap` ou bootstrap |

Le passage en `non-Primary` est une **protection** : il vaut mieux un service arrêté que deux bases qui divergent.

## Après toute reprise

- [ ] `check-galera.sh` OK sur les 3 nœuds
- [ ] `test-sql-round-robin.sh` : 3 nœuds répondent via HAProxy
- [ ] WordPress et GLPI fonctionnels
- [ ] Incident consigné dans [09-troubleshooting/incidents.md](../09-troubleshooting/incidents.md)
