#!/usr/bin/env bash
# =============================================================================
# check-galera.sh — Vérifie l'état d'un nœud du cluster Galera
# -----------------------------------------------------------------------------
# Machine cible : MYSQL-01, MYSQL-02 ou MYSQL-03 (mode local, via sudo)
#                 ou HAPROXY (mode distant : -H 10.0.20.X)
# Contrôles     : wsrep_cluster_size = 3, wsrep_cluster_status = Primary,
#                 wsrep_local_state_comment = Synced, wsrep_ready = ON
# Non destructif : lecture seule (SHOW GLOBAL STATUS).
#
# Exemples :
#   SUR MYSQL-01 : ./check-galera.sh
#   SUR HAPROXY  : ./check-galera.sh -H 10.0.20.2              (compte haproxy_check)
#   SUR HAPROXY  : ./check-galera.sh -H 10.0.20.2 -u admin -p   (autre compte, mot de passe demandé)
# Code retour : 0 = nœud sain, 1 = au moins un contrôle en échec, 2 = erreur d'exécution
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

EXPECTED_SIZE="${EXPECTED_SIZE:-3}"
HOST=""
DB_USER="haproxy_check"
ASK_PASSWORD=0

usage() {
    cat <<EOF
Usage : $(basename "$0") [-H hôte] [-u utilisateur] [-p] [-s taille_attendue]
  -H  Nœud distant à interroger (défaut : nœud local via socket unix et sudo)
  -u  Utilisateur MariaDB en mode distant (défaut : haproxy_check)
  -p  Demander un mot de passe (sinon : compte sans mot de passe)
  -s  Taille de cluster attendue (défaut : ${EXPECTED_SIZE})
EOF
}

while getopts ":H:u:ps:h" opt; do
    case "$opt" in
        H) HOST="$OPTARG" ;;
        u) DB_USER="$OPTARG" ;;
        p) ASK_PASSWORD=1 ;;
        s) EXPECTED_SIZE="$OPTARG" ;;
        h) usage; exit 0 ;;
        *) usage; exit 2 ;;
    esac
done

print_header "Contrôle de l'état Galera" "MYSQL-01 / MYSQL-02 / MYSQL-03${HOST:+ (distant : ${HOST})}"
require_cmd mariadb

# Construction de la commande client
if [[ -z "$HOST" ]]; then
    MYSQL_CMD=(as_root mariadb)
    TARGET_LABEL="local"
else
    create_mysql_defaults "$DB_USER" "$ASK_PASSWORD"
    MYSQL_CMD=(mariadb --defaults-extra-file="$MYSQL_DEFAULTS" -h "$HOST")
    TARGET_LABEL="$HOST"
fi

log_info "Checking Galera status on ${TARGET_LABEL}..."

if ! raw="$("${MYSQL_CMD[@]}" -N -B -e \
    "SHOW GLOBAL STATUS WHERE Variable_name IN ('wsrep_cluster_size','wsrep_cluster_status','wsrep_local_state_comment','wsrep_ready','wsrep_connected','wsrep_incoming_addresses')" 2>&1)"; then
    log_fail "Connexion à MariaDB impossible : ${raw}"
    log_info "Diagnostic : systemctl status mariadb / bind-address / pare-feu (voir docs/09-troubleshooting/galera.md)"
    print_summary
    exit 1
fi

declare -A WSREP=()
while IFS=$'\t' read -r name value; do
    [[ -n "$name" ]] && WSREP["$name"]="$value"
done <<< "$raw"

if [[ -z "${WSREP[wsrep_cluster_size]:-}" ]]; then
    log_fail "Aucune variable wsrep : Galera n'est pas actif sur ce serveur (wsrep_on=OFF ?)"
    print_summary
    exit 1
fi

node_name="$("${MYSQL_CMD[@]}" -N -B -e "SELECT @@wsrep_node_name" 2>/dev/null || echo "?")"
log_info "Nœud : ${node_name}"

# Compare une variable à sa valeur attendue
check_value() {
    local name="$1" expected="$2" actual="${WSREP[$1]:-absent}"
    if [[ "$actual" == "$expected" ]]; then
        log_ok "${name} = ${actual}"
    else
        log_fail "${name} = ${actual} (attendu : ${expected})"
    fi
}

check_value wsrep_cluster_size        "$EXPECTED_SIZE"
check_value wsrep_cluster_status      "Primary"
check_value wsrep_local_state_comment "Synced"
check_value wsrep_ready               "ON"
check_value wsrep_connected           "ON"

log_info "Membres vus par ce nœud : ${WSREP[wsrep_incoming_addresses]:-inconnu}"

if [[ "${WSREP[wsrep_cluster_status]:-}" == "non-Primary" ]]; then
    log_warn "Cluster non-Primary : perte de quorum. NE PAS bootstrapper sans lire docs/03-galera/recovery.md"
fi

print_summary
