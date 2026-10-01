#!/usr/bin/env bash
# =============================================================================
# check-glpi.sh — Disponibilité de GLPI en direct et via HAProxy
# -----------------------------------------------------------------------------
# Machine cible : ADM-01 (10.0.30.1)
# Contrôles     : GLPI-01 répond sur :80, HAProxy publie GLPI sur :8080,
#                 la page contient bien GLPI (et pas une page Apache par défaut).
# Non destructif : requêtes HTTP GET uniquement.
# Code retour   : 0 = OK, 1 = échec
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

GLPI_DIRECT_URL="${GLPI_DIRECT_URL:-http://10.0.10.3/}"
GLPI_PROXY_URL="${GLPI_PROXY_URL:-http://10.0.10.2:8080/}"

print_header "Disponibilité GLPI" "ADM-01"
require_cmd curl

check_glpi() {
    local label="$1" url="$2" code body
    IFS=$'\t' read -r code _ < <(http_probe "$url")
    if http_is_up "$code"; then
        log_ok "${label} ${url} UP (HTTP ${code})"
    else
        log_fail "${label} ${url} DOWN (HTTP ${code})"
        return 0
    fi
    # Suivre les redirections et vérifier le contenu
    body="$(curl -s -L --max-time 10 "$url" || true)"
    if grep -qi 'glpi' <<< "$body"; then
        log_ok "${label} : la page servie est bien GLPI"
    elif grep -qi 'Apache2 Debian Default Page' <<< "$body"; then
        log_fail "${label} : page Apache par défaut (vhost glpi non activé ? a2ensite glpi / a2dissite 000-default)"
    else
        log_warn "${label} : contenu inattendu (vérifier DocumentRoot /var/www/glpi/public)"
    fi
}

log_info "Checking GLPI direct access..."
check_glpi "GLPI-01" "$GLPI_DIRECT_URL"

log_info "Checking GLPI through HAProxy..."
check_glpi "HAProxy" "$GLPI_PROXY_URL"

print_summary
