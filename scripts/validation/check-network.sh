#!/usr/bin/env bash
# =============================================================================
# check-network.sh — Connectivité réseau du lab
# -----------------------------------------------------------------------------
# Machine cible : ADM-01 (10.0.30.1) — VLAN 303 vADMIN
# Contrôles     : passerelles pfSense des 4 VLAN, hôtes (ICMP),
#                 ports de service autorisés depuis vADMIN (TCP).
# Non destructif : ping et ouverture de connexion TCP sans envoi de données.
# Remarque      : un ping en échec n'est qu'un avertissement (ICMP peut être filtré) ;
#                 un port TCP fermé est un échec.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

GATEWAYS=(
    "vWEB|10.0.10.254"
    "vBDD|10.0.20.254"
    "vADMIN|10.0.30.254"
    "vUSER|10.0.40.254"
)

HOSTS=(
    "WEB-01|10.0.10.1"
    "HAProxy|10.0.10.2"
    "GLPI-01|10.0.10.3"
    "WEB-02|10.0.10.4"
    "MYSQL-01|10.0.20.1"
    "MYSQL-02|10.0.20.2"
    "MYSQL-03|10.0.20.3"
    "Guacamole|10.0.30.2"
)

# Ports attendus OUVERTS depuis ADM-01 (cf. configs/pfsense/firewall-rules.md)
TCP_CHECKS=(
    "HAProxy HTTP WordPress|10.0.10.2|80"
    "HAProxy HTTP GLPI|10.0.10.2|8080"
    "HAProxy SQL|10.0.10.2|3306"
    "HAProxy stats|10.0.10.2|8404"
    "WEB-01 HTTP|10.0.10.1|80"
    "WEB-02 HTTP|10.0.10.4|80"
    "GLPI-01 HTTP|10.0.10.3|80"
    "WEB-01 SSH|10.0.10.1|22"
    "HAProxy SSH|10.0.10.2|22"
    "GLPI-01 SSH|10.0.10.3|22"
    "WEB-02 SSH|10.0.10.4|22"
    "MYSQL-01 SSH|10.0.20.1|22"
    "MYSQL-02 SSH|10.0.20.2|22"
    "MYSQL-03 SSH|10.0.20.3|22"
)

print_header "Connectivité réseau (passerelles, hôtes, ports)" "ADM-01 (10.0.30.1)"
require_cmd ping timeout

ping_check() {
    local label="$1" ip="$2"
    if ping -c 2 -W 2 "$ip" >/dev/null 2>&1; then
        log_ok "$(printf '%-10s %-12s répond au ping' "$label" "$ip")"
    else
        log_warn "$(printf '%-10s %-12s ne répond pas au ping (filtré ou éteint)' "$label" "$ip")"
    fi
}

# Test d'ouverture TCP via /dev/tcp (pas besoin de nc)
tcp_check() {
    local label="$1" ip="$2" port="$3"
    if timeout 3 bash -c "exec 3<>/dev/tcp/${ip}/${port}" 2>/dev/null; then
        log_ok "$(printf '%-24s %s:%s ouvert' "$label" "$ip" "$port")"
    else
        log_fail "$(printf '%-24s %s:%s fermé ou filtré' "$label" "$ip" "$port")"
    fi
}

log_step "Passerelles pfSense"
for entry in "${GATEWAYS[@]}"; do
    IFS='|' read -r label ip <<< "$entry"
    ping_check "$label" "$ip"
done

log_step "Hôtes"
for entry in "${HOSTS[@]}"; do
    IFS='|' read -r label ip <<< "$entry"
    ping_check "$label" "$ip"
done

log_step "Ports TCP autorisés depuis vADMIN"
for entry in "${TCP_CHECKS[@]}"; do
    IFS='|' read -r label ip port <<< "$entry"
    tcp_check "$label" "$ip" "$port"
done

print_summary
