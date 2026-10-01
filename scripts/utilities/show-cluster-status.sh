#!/usr/bin/env bash
# =============================================================================
# show-cluster-status.sh — Tableau de bord texte du cluster Galera
# -----------------------------------------------------------------------------
# Machine cible : HAPROXY (10.0.10.2) — autorisé à joindre les 3 nœuds sur 3306
# Affiche       : pour chaque nœud, taille du cluster, statut, état, wsrep_ready.
# Compte SQL    : haproxy_check (sans mot de passe, sans privilège) par défaut ;
#                 SHOW GLOBAL STATUS ne nécessite aucun privilège.
# Non destructif : lecture seule. Option -w N : rafraîchit toutes les N secondes.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

NODES=("MYSQL-01|10.0.20.1" "MYSQL-02|10.0.20.2" "MYSQL-03|10.0.20.3")
DB_USER="haproxy_check"
ASK_PASSWORD=0
WATCH=0

while getopts ":u:pw:h" opt; do
    case "$opt" in
        u) DB_USER="$OPTARG" ;;
        p) ASK_PASSWORD=1 ;;
        w) WATCH="$OPTARG" ;;
        h) echo "Usage : $(basename "$0") [-u utilisateur] [-p] [-w secondes]"; exit 0 ;;
        *) die "Option invalide" ;;
    esac
done

require_cmd mariadb
create_mysql_defaults "$DB_USER" "$ASK_PASSWORD"

render() {
    local entry name ip raw size status state ready
    printf '%-9s %-11s %-6s %-12s %-10s %-6s\n' "NŒUD" "IP" "TAILLE" "STATUT" "ÉTAT" "READY"
    printf '%-9s %-11s %-6s %-12s %-10s %-6s\n' "---------" "-----------" "------" "------------" "----------" "------"
    for entry in "${NODES[@]}"; do
        IFS='|' read -r name ip <<< "$entry"
        raw="$(galera_status "$ip" || true)"
        if [[ -z "$raw" ]]; then
            printf '%-9s %-11s %s\n' "$name" "$ip" "${C_RED}injoignable${C_RESET}"
            continue
        fi
        size="$(awk -F'\t' '$1=="wsrep_cluster_size"{print $2}' <<< "$raw")"
        status="$(awk -F'\t' '$1=="wsrep_cluster_status"{print $2}' <<< "$raw")"
        state="$(awk -F'\t' '$1=="wsrep_local_state_comment"{print $2}' <<< "$raw")"
        ready="$(awk -F'\t' '$1=="wsrep_ready"{print $2}' <<< "$raw")"
        printf '%-9s %-11s %-6s %-12s %-10s %-6s\n' "$name" "$ip" "$size" "$status" "$state" "$ready"
    done
    printf '\nAttendu : TAILLE=3  STATUT=Primary  ÉTAT=Synced  READY=ON\n'
}

if (( WATCH > 0 )); then
    while true; do
        clear
        print_header "État du cluster Galera (rafraîchi toutes les ${WATCH} s, Ctrl+C pour quitter)" "HAPROXY (10.0.10.2)"
        render
        sleep "$WATCH"
    done
else
    print_header "État du cluster Galera" "HAPROXY (10.0.10.2)"
    render
fi
