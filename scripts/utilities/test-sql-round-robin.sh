#!/usr/bin/env bash
# =============================================================================
# test-sql-round-robin.sh — Montre la répartition des connexions SQL par HAProxy
# -----------------------------------------------------------------------------
# Machine cible : HAPROXY, WEB-01 ou WEB-02 (client SQL vers 10.0.10.2:3306)
# Action        : ouvre N connexions successives vers HAProxy et exécute
#                 SELECT @@hostname; pour voir quel nœud Galera répond.
# Attendu       : les 3 nœuds (MYSQL-01, 02, 03) répondent à tour de rôle.
# Compte SQL    : haproxy_check par défaut (aucun privilège nécessaire).
#                 Toute connexion via HAProxy arrive sur Galera avec l'IP source 10.0.10.2.
# Non destructif : lecture seule.
#
# Exemple : ./test-sql-round-robin.sh -n 9
#           ./test-sql-round-robin.sh -u wordpress -p
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

HOST="10.0.10.2"
PORT="3306"
COUNT=9
DB_USER="haproxy_check"
ASK_PASSWORD=0
EXPECTED_NODES=3

while getopts ":H:P:n:u:ph" opt; do
    case "$opt" in
        H) HOST="$OPTARG" ;;
        P) PORT="$OPTARG" ;;
        n) COUNT="$OPTARG" ;;
        u) DB_USER="$OPTARG" ;;
        p) ASK_PASSWORD=1 ;;
        h) echo "Usage : $(basename "$0") [-H hôte] [-P port] [-n connexions] [-u utilisateur] [-p]"; exit 0 ;;
        *) die "Option invalide" ;;
    esac
done
[[ "$COUNT" =~ ^[0-9]+$ && "$COUNT" -gt 0 ]] || die "-n doit être un entier positif"

print_header "Répartition SQL round-robin via HAProxy" "HAPROXY / WEB-01 / WEB-02 -> ${HOST}:${PORT}"
require_cmd mariadb
create_mysql_defaults "$DB_USER" "$ASK_PASSWORD"

declare -A HITS=()
errors=0

log_info "Ouverture de ${COUNT} connexions vers ${HOST}:${PORT}..."
for (( i = 1; i <= COUNT; i++ )); do
    if node="$(mariadb --defaults-extra-file="$MYSQL_DEFAULTS" -h "$HOST" -P "$PORT" -N -B -e 'SELECT @@hostname;' 2>&1)"; then
        printf '  connexion %2d -> %s\n' "$i" "$node"
        HITS["$node"]=$(( ${HITS["$node"]:-0} + 1 ))
    else
        printf '  connexion %2d -> ERREUR : %s\n' "$i" "$node"
        errors=$((errors + 1))
    fi
done

log_step "Répartition"
for node in "${!HITS[@]}"; do
    printf '  %-12s %d connexion(s)\n' "$node" "${HITS[$node]}"
done

distinct="${#HITS[@]}"
if (( errors == 0 )); then
    log_ok "${COUNT}/${COUNT} connexions réussies"
else
    log_fail "${errors} connexion(s) en échec"
fi
if (( distinct == EXPECTED_NODES )); then
    log_ok "${distinct} nœuds distincts ont répondu (round-robin effectif)"
elif (( distinct > 0 )); then
    log_warn "${distinct}/${EXPECTED_NODES} nœuds ont répondu (nœud DOWN dans HAProxy ? voir check-haproxy.sh)"
fi

print_summary
