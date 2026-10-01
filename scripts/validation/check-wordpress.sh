#!/usr/bin/env bash
# =============================================================================
# check-wordpress.sh — Disponibilité HTTP de WEB-01, WEB-02 et de HAProxy
# -----------------------------------------------------------------------------
# Machine cible : ADM-01 (10.0.30.1) ou HAPROXY — toute machine autorisée
#                 à joindre les serveurs web sur le port 80.
# Affiche       : UP / DOWN, code HTTP, backend ayant répondu (X-Served-By).
# Non destructif : requêtes HTTP GET uniquement.
# Variables     : WEB01_URL, WEB02_URL, HAPROXY_URL pour d'autres adresses.
# Code retour   : 0 = HAProxy répond, 1 = HAProxy ne répond pas
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

WEB01_URL="${WEB01_URL:-http://10.0.10.1/}"
WEB02_URL="${WEB02_URL:-http://10.0.10.4/}"
HAPROXY_URL="${HAPROXY_URL:-http://10.0.10.2/}"

print_header "Disponibilité WordPress (backends et point d'entrée)" "ADM-01 (ou toute VM autorisée sur :80)"
require_cmd curl

backends_up=0

probe() {
    local label="$1" url="$2" is_entry="$3" code backend
    IFS=$'\t' read -r code backend < <(http_probe "$url")
    if http_is_up "$code"; then
        if [[ "$is_entry" == "1" ]]; then
            log_ok "$(printf '%-8s %-24s UP    HTTP %s  servi par %s' "$label" "$url" "$code" "$backend")"
        else
            log_ok "$(printf '%-8s %-24s UP    HTTP %s' "$label" "$url" "$code")"
            backends_up=$((backends_up + 1))
        fi
    elif [[ "$is_entry" == "1" ]]; then
        log_fail "$(printf '%-8s %-24s DOWN  HTTP %s' "$label" "$url" "$code")"
    else
        # Un backend DOWN est un avertissement : le service reste rendu par l'autre
        log_warn "$(printf '%-8s %-24s DOWN  HTTP %s' "$label" "$url" "$code")"
    fi
}

log_info "Checking WordPress backends..."
probe "WEB-01" "$WEB01_URL" 0
probe "WEB-02" "$WEB02_URL" 0

log_info "Checking HAProxy entry point..."
probe "HAProxy" "$HAPROXY_URL" 1

case "$backends_up" in
    2) log_info "Redondance complète : 2/2 serveurs web disponibles" ;;
    1) log_warn "Redondance perdue : 1/2 serveur web disponible (service maintenu)" ;;
    0) log_info "Aucun backend joignable directement (vérifier aussi les règles pfSense)" ;;
esac

print_summary
