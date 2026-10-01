#!/usr/bin/env bash
# =============================================================================
# install-haproxy.sh — Installe HAProxy et les outils de diagnostic
# -----------------------------------------------------------------------------
# Machine cible : HAPROXY (10.0.10.2) — Debian 12
# Actions       : installe haproxy, mariadb-client, socat, curl ;
#                 vérifie le compte système "haproxy" (incident INC-08) ;
#                 vérifie la syntaxe de la configuration en place.
# NE FAIT PAS   : écraser /etc/haproxy/haproxy.cfg (copie manuelle depuis configs/).
# Sécurité      : mode SIMULATION par défaut ; --apply pour exécuter.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

DRY_RUN=1
[[ "${1:-}" == "--apply" ]] && DRY_RUN=0
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { echo "Usage : sudo $(basename "$0") [--apply]"; exit 0; }

PACKAGES=(haproxy mariadb-client socat curl)
HAPROXY_CFG="/etc/haproxy/haproxy.cfg"

print_header "Installation de HAProxy" "HAPROXY (10.0.10.2) — VLAN 301 vWEB"
[[ "$DRY_RUN" == "1" ]] || require_root

log_step "Compte système haproxy"
if getent passwd haproxy >/dev/null; then
    uid="$(getent passwd haproxy | cut -d: -f3)"
    shell="$(getent passwd haproxy | cut -d: -f7)"
    if (( uid >= 1000 )); then
        log_fail "Le compte 'haproxy' est un compte HUMAIN (uid=${uid}, shell=${shell})."
        log_info "Il entrera en conflit avec le compte système du paquet. Voir INC-08 :"
        log_info "créer 'haproxyadmin' pour l'administration, puis supprimer/renommer ce compte AVANT l'installation."
        print_summary
        exit 1
    fi
    log_ok "Compte système haproxy (uid=${uid}, shell=${shell})"
else
    log_info "Compte haproxy absent : il sera créé par le paquet"
fi

log_step "Paquets : ${PACKAGES[*]}"
missing_pkgs=()
for p in "${PACKAGES[@]}"; do
    dpkg -s "$p" >/dev/null 2>&1 || missing_pkgs+=("$p")
done
if [[ ${#missing_pkgs[@]} -eq 0 ]]; then
    log_ok "Tous les paquets sont déjà installés"
else
    run_cmd apt-get update
    run_cmd env DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing_pkgs[@]}"
fi

if command -v haproxy >/dev/null 2>&1; then
    log_ok "$(haproxy -v | head -n1)"
fi

log_step "Configuration en place"
if [[ -f "$HAPROXY_CFG" ]]; then
    if grep -q 'fe_wordpress' "$HAPROXY_CFG"; then
        log_ok "Configuration du projet détectée dans ${HAPROXY_CFG}"
        if grep -q '<PASSWORD>' "$HAPROXY_CFG"; then
            log_warn "Placeholder <PASSWORD> encore présent : le remplacer"
        fi
    else
        log_info "Configuration par défaut du paquet. Pour appliquer celle du projet :"
        log_info "  sudo cp configs/haproxy/haproxy.cfg.example ${HAPROXY_CFG} && sudo nano ${HAPROXY_CFG}"
    fi
    if [[ "$DRY_RUN" == "0" ]]; then
        if haproxy -c -f "$HAPROXY_CFG" >/dev/null 2>&1; then
            log_ok "haproxy -c : configuration valide"
        else
            log_fail "haproxy -c : configuration invalide (sudo haproxy -c -f ${HAPROXY_CFG})"
        fi
    fi
fi

log_step "Étapes suivantes"
cat <<EOF
  1. Créer le compte de health-check SUR MYSQL-01 :  CREATE USER 'haproxy_check'@'10.0.10.2';
  2. Copier la configuration, remplacer <PASSWORD>, vérifier : sudo haproxy -c -f ${HAPROXY_CFG}
  3. Activer : sudo systemctl enable --now haproxy && sudo systemctl reload haproxy
  4. Contrôler : ./scripts/validation/check-haproxy.sh
EOF

print_summary
