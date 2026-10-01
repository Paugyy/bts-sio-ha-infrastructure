#!/usr/bin/env bash
# =============================================================================
# check-haproxy.sh — Vérifie le service HAProxy et l'état de ses backends
# -----------------------------------------------------------------------------
# Machine cible : HAPROXY (10.0.10.2)
# Contrôles     : service actif, syntaxe de la configuration, ports en écoute,
#                 état UP/DOWN de chaque serveur (via le socket d'administration).
# Non destructif : lecture seule.
# Code retour   : 0 = OK, 1 = échec, 2 = erreur d'exécution
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

HAPROXY_CFG="${HAPROXY_CFG:-/etc/haproxy/haproxy.cfg}"
HAPROXY_SOCKET="${HAPROXY_SOCKET:-/run/haproxy/admin.sock}"
# Ports publiés : WordPress, GLPI, SQL, statistiques
read -r -a PORTS <<< "${HAPROXY_PORTS:-80 8080 3306 8404}"

print_header "Contrôle du répartiteur HAProxy" "HAPROXY (10.0.10.2)"
require_cmd haproxy ss systemctl

log_step "Service"
if systemctl is-active --quiet haproxy; then
    log_ok "haproxy.service actif"
else
    log_fail "haproxy.service inactif (sudo systemctl status haproxy)"
fi

log_step "Configuration"
if output="$(as_root haproxy -c -f "$HAPROXY_CFG" 2>&1)"; then
    log_ok "Syntaxe valide : ${HAPROXY_CFG}"
else
    log_fail "Configuration invalide : ${HAPROXY_CFG}"
    printf '%s\n' "$output"
fi

log_step "Ports en écoute"
for port in "${PORTS[@]}"; do
    if ss -ltnH "sport = :${port}" | grep -q .; then
        log_ok "Port ${port} en écoute"
    else
        log_fail "Port ${port} non en écoute"
    fi
done

log_step "État des serveurs (backends)"
if ! command -v socat >/dev/null 2>&1; then
    log_warn "socat absent : état des backends non lisible (sudo apt install socat)"
elif ! as_root test -S "$HAPROXY_SOCKET"; then
    log_warn "Socket ${HAPROXY_SOCKET} absent (directive 'stats socket' dans global ?)"
else
    # show stat : CSV ; colonnes 1=proxy 2=serveur 18=statut
    while IFS=',' read -r proxy server status; do
        case "$status" in
            UP*)  log_ok   "${proxy}/${server} : ${status}" ;;
            MAINT*) log_warn "${proxy}/${server} : ${status} (maintenance)" ;;
            *)    log_fail "${proxy}/${server} : ${status}" ;;
        esac
    done < <(echo "show stat" | as_root socat stdio "$HAPROXY_SOCKET" \
             | awk -F',' '!/^#/ && $2 != "FRONTEND" && $2 != "BACKEND" && $1 != "stats" && NF > 18 {print $1","$2","$18}')
fi

print_summary
