#!/usr/bin/env bash
# =============================================================================
# test-galera-node.sh — Test de perte puis de retour d'un nœud Galera
# -----------------------------------------------------------------------------
# Machine cible : HAPROXY (10.0.10.2) — seule VM autorisée à joindre les 3 nœuds sur 3306
# Attendu       : nœud arrêté -> les 2 autres restent Primary/Synced, cluster_size = 2,
#                 le SQL via HAProxy continue de répondre sans le nœud arrêté ;
#                 nœud relancé (systemctl start, PAS de bootstrap) -> cluster_size = 3.
# Compte SQL    : haproxy_check (sans mot de passe, sans privilège) par défaut.
# Non destructif : mode guidé (l'opérateur arrête MariaDB) ; aucune écriture SQL.
#                 Le script ne lance JAMAIS galera_new_cluster.
# Procédure     : docs/08-tests/galera-tests.md (test T20)
#
# Exemple : ./test-galera-node.sh --node 2
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

NODES=("MYSQL-01|10.0.20.1" "MYSQL-02|10.0.20.2" "MYSQL-03|10.0.20.3")
HAPROXY_SQL="${HAPROXY_SQL:-10.0.10.2}"
DB_USER="haproxy_check"
ASK_PASSWORD=0
TARGET_INDEX=""

usage() {
    cat <<EOF
Usage : $(basename "$0") --node 1|2|3 [-u utilisateur] [-p]
  --node  Nœud à arrêter : 1=MYSQL-01, 2=MYSQL-02, 3=MYSQL-03
  -u      Utilisateur MariaDB (défaut : haproxy_check)
  -p      Demander un mot de passe
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --node) TARGET_INDEX="${2:?}"; shift 2 ;;
        -u)     DB_USER="${2:?}"; shift 2 ;;
        -p)     ASK_PASSWORD=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *)      usage; die "Option inconnue : $1" ;;
    esac
done
[[ "$TARGET_INDEX" =~ ^[123]$ ]] || { usage; die "--node 1, 2 ou 3 obligatoire"; }

IFS='|' read -r TARGET_NAME TARGET_IP <<< "${NODES[$((TARGET_INDEX - 1))]}"

print_header "Test de perte d'un nœud Galera (${TARGET_NAME})" "HAPROXY (pilote) — ${TARGET_NAME} ${TARGET_IP} (arrêté)"
require_cmd mariadb
create_mysql_defaults "$DB_USER" "$ASK_PASSWORD"

# Renvoie "size status state" pour un nœud, ou "unreachable"
node_state() {
    local ip="$1" raw
    raw="$(galera_status "$ip" || true)"
    if [[ -z "$raw" ]]; then
        echo "unreachable"
        return
    fi
    awk -F'\t' '
        $1=="wsrep_cluster_size"        {s=$2}
        $1=="wsrep_cluster_status"      {c=$2}
        $1=="wsrep_local_state_comment" {l=$2}
        END {print s, c, l}' <<< "$raw"
}

show_cluster() {
    local entry name ip
    for entry in "${NODES[@]}"; do
        IFS='|' read -r name ip <<< "$entry"
        printf '    %-9s %-10s %s\n' "$name" "$ip" "$(node_state "$ip")"
    done
}

# Attend que tous les nœuds sauf "exclu" annoncent la taille attendue (Primary, Synced)
wait_cluster_size() {
    local expected="$1" excluded="$2" timeout="$3" waited=0 entry name ip ok
    while (( waited <= timeout )); do
        ok=1
        for entry in "${NODES[@]}"; do
            IFS='|' read -r name ip <<< "$entry"
            [[ "$name" == "$excluded" ]] && continue
            [[ "$(node_state "$ip")" == "${expected} Primary Synced" ]] || ok=0
        done
        (( ok == 1 )) && return 0
        sleep 5
        waited=$((waited + 5))
    done
    return 1
}

log_step "1/4 État initial"
show_cluster
if wait_cluster_size 3 "" 0; then
    log_ok "Cluster nominal : 3 nœuds Primary / Synced"
else
    log_fail "Cluster non nominal : test annulé (lancer check-galera.sh sur chaque nœud)"
    print_summary || true
    exit 1
fi

log_step "2/4 Arrêt de MariaDB sur ${TARGET_NAME}"
printf '\n    %sSUR %s%s\n\n    sudo systemctl stop mariadb\n\n' "$C_BOLD" "$TARGET_NAME" "$C_RESET"
pause_for_operator "Lancer la commande ci-dessus sur ${TARGET_NAME}"

log_step "3/4 Cluster dégradé"
if wait_cluster_size 2 "$TARGET_NAME" 30; then
    log_ok "Les 2 nœuds restants sont Primary / Synced avec cluster_size = 2 (quorum 2/3 conservé)"
else
    log_fail "Les nœuds restants ne sont pas revenus à Primary / Synced / 2 en 30 s"
fi
show_cluster

log_info "Connexions SQL via HAProxy (${HAPROXY_SQL}:3306)..."
sql_errors=0
answered=""
for _ in 1 2 3 4 5 6; do
    if host="$(mariadb --defaults-extra-file="$MYSQL_DEFAULTS" -h "$HAPROXY_SQL" -P 3306 -N -B -e 'SELECT @@hostname' 2>/dev/null)"; then
        answered+="${host} "
    else
        sql_errors=$((sql_errors + 1))
    fi
done
log_info "Nœuds ayant répondu : ${answered:-aucun}"
if (( sql_errors == 0 )); then
    log_ok "6/6 connexions SQL réussies via HAProxy pendant la panne"
else
    log_fail "${sql_errors}/6 connexions SQL en échec via HAProxy"
fi

log_step "4/4 Retour de ${TARGET_NAME}"
printf '\n    %sSUR %s%s\n\n    sudo systemctl start mariadb\n\n' "$C_BOLD" "$TARGET_NAME" "$C_RESET"
log_warn "NE PAS utiliser galera_new_cluster : le cluster existe toujours, le nœud doit le REJOINDRE."
pause_for_operator "Lancer la commande ci-dessus sur ${TARGET_NAME}"

log_info "Attente de la resynchronisation (IST/SST), jusqu'à 180 s..."
if wait_cluster_size 3 "" 180; then
    log_ok "${TARGET_NAME} a rejoint le cluster : 3 nœuds Primary / Synced"
else
    log_fail "${TARGET_NAME} n'a pas rejoint le cluster en 180 s (journalctl -u mariadb sur ${TARGET_NAME})"
fi
show_cluster

print_summary
