#!/usr/bin/env bash
# =============================================================================
# install-galera.sh — Prépare un nœud MariaDB Galera
# -----------------------------------------------------------------------------
# Machine cible : MYSQL-01, MYSQL-02 ou MYSQL-03 (Debian 12)
# Actions       : installe mariadb-server, galera-4, rsync ; règle bind-address ;
#                 écrit /etc/mysql/mariadb.conf.d/60-galera.cnf pour ce nœud.
# NE FAIT PAS   : démarrer le cluster, bootstrapper, redémarrer MariaDB.
#                 Le bootstrap est une décision humaine (docs/03-galera/bootstrap.md).
# Sécurité      : mode SIMULATION par défaut ; --apply pour exécuter.
#                 Un fichier existant différent n'est remplacé qu'avec --force
#                 (et il est sauvegardé en .bak-<date> au préalable).
#
# Exemple :
#   SUR MYSQL-01 : sudo ./install-galera.sh --node-name MYSQL-01 --node-ip 10.0.20.1 --apply
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

NODE_NAME=""
NODE_IP=""
CLUSTER_NAME="mon_cluster_galera"
CLUSTER_ADDRESS="gcomm://10.0.20.1,10.0.20.2,10.0.20.3"
SST_METHOD="rsync"
FORCE=0
DRY_RUN=1

SERVER_CNF="/etc/mysql/mariadb.conf.d/50-server.cnf"
GALERA_CNF="/etc/mysql/mariadb.conf.d/60-galera.cnf"
PACKAGES=(mariadb-server mariadb-client galera-4 rsync)

usage() {
    cat <<EOF
Usage : sudo $(basename "$0") --node-name NOM --node-ip IP [options]
  --node-name NOM          Nom du nœud (ex. MYSQL-01)
  --node-ip IP             IP du nœud dans le VLAN vBDD (ex. 10.0.20.1)
  --cluster-name NOM       Défaut : ${CLUSTER_NAME}
  --cluster-address URL    Défaut : ${CLUSTER_ADDRESS}
  --apply                  Exécuter réellement (sinon simulation)
  --force                  Remplacer un 60-galera.cnf existant différent
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --node-name)       NODE_NAME="${2:?}"; shift 2 ;;
        --node-ip)         NODE_IP="${2:?}"; shift 2 ;;
        --cluster-name)    CLUSTER_NAME="${2:?}"; shift 2 ;;
        --cluster-address) CLUSTER_ADDRESS="${2:?}"; shift 2 ;;
        --apply)           DRY_RUN=0; shift ;;
        --force)           FORCE=1; shift ;;
        -h|--help)         usage; exit 0 ;;
        *)                 usage; die "Option inconnue : $1" ;;
    esac
done

[[ -n "$NODE_NAME" && -n "$NODE_IP" ]] || { usage; die "--node-name et --node-ip sont obligatoires."; }
[[ "$NODE_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || die "IP invalide : $NODE_IP"
[[ "$CLUSTER_ADDRESS" == *"$NODE_IP"* ]] || die "L'IP ${NODE_IP} n'apparaît pas dans ${CLUSTER_ADDRESS}"

print_header "Préparation d'un nœud MariaDB Galera" "${NODE_NAME} (${NODE_IP}) — VLAN 302 vBDD"
[[ "$DRY_RUN" == "1" ]] || require_root

# --- Système --------------------------------------------------------------------
log_step "Vérification du système"
if grep -q 'ID=debian' /etc/os-release 2>/dev/null; then
    # shellcheck disable=SC1091
    log_ok "Debian détecté : $(. /etc/os-release && echo "$PRETTY_NAME")"
else
    log_warn "Système non Debian : les chemins et paquets peuvent différer"
fi
if ip -4 addr show 2>/dev/null | grep -q "inet ${NODE_IP}/"; then
    log_ok "L'IP ${NODE_IP} est bien configurée sur cette machine"
else
    log_warn "L'IP ${NODE_IP} n'est pas configurée sur cette machine : mauvais nœud ?"
fi

# --- Paquets --------------------------------------------------------------------
log_step "Paquets : ${PACKAGES[*]}"
missing_pkgs=()
for p in "${PACKAGES[@]}"; do
    dpkg -s "$p" >/dev/null 2>&1 || missing_pkgs+=("$p")
done
if [[ ${#missing_pkgs[@]} -eq 0 ]]; then
    log_ok "Tous les paquets sont déjà installés (idempotent : rien à faire)"
else
    log_info "À installer : ${missing_pkgs[*]}"
    run_cmd apt-get update
    run_cmd env DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing_pkgs[@]}"
fi

# --- bind-address ------------------------------------------------------------------
log_step "bind-address dans ${SERVER_CNF}"
if [[ -f "$SERVER_CNF" ]] && grep -Eq "^[[:space:]]*bind-address[[:space:]]*=[[:space:]]*${NODE_IP//./\\.}[[:space:]]*$" "$SERVER_CNF"; then
    log_ok "bind-address = ${NODE_IP} (déjà correct)"
else
    current="$(grep -E '^[[:space:]]*bind-address' "$SERVER_CNF" 2>/dev/null || echo 'absent')"
    log_info "Valeur actuelle : ${current} -> nouvelle valeur : ${NODE_IP}"
    run_cmd cp -a "$SERVER_CNF" "${SERVER_CNF}.bak-$(date +%Y%m%d%H%M%S)"
    run_cmd sed -i -E "s|^[[:space:]]*#?[[:space:]]*bind-address[[:space:]]*=.*|bind-address            = ${NODE_IP}|" "$SERVER_CNF"
fi

# --- 60-galera.cnf ------------------------------------------------------------------
log_step "Configuration Galera : ${GALERA_CNF}"
desired="$(cat <<EOF
# Généré par scripts/install/install-galera.sh pour ${NODE_NAME}
# Référence : configs/galera/ — docs/03-galera/concepts.md
[galera]
wsrep_on                 = ON
wsrep_provider           = /usr/lib/galera/libgalera_smm.so
wsrep_cluster_name       = "${CLUSTER_NAME}"
wsrep_cluster_address    = "${CLUSTER_ADDRESS}"
wsrep_node_address       = "${NODE_IP}"
wsrep_node_name          = "${NODE_NAME}"
wsrep_sst_method         = ${SST_METHOD}
binlog_format            = ROW
default_storage_engine   = InnoDB
innodb_autoinc_lock_mode = 2
wsrep_slave_threads      = 1
EOF
)"

if [[ -f "$GALERA_CNF" ]] && [[ "$(cat "$GALERA_CNF")" == "$desired" ]]; then
    log_ok "${GALERA_CNF} déjà à jour (idempotent : rien à faire)"
elif [[ -f "$GALERA_CNF" ]] && grep -Eq '^[[:space:]]*wsrep_on[[:space:]]*=[[:space:]]*ON' "$GALERA_CNF" && [[ "$FORCE" != "1" ]]; then
    log_warn "${GALERA_CNF} existe déjà avec Galera actif et diffère : non modifié (utiliser --force)"
    diff <(cat "$GALERA_CNF") <(printf '%s\n' "$desired") || true
else
    if [[ -f "$GALERA_CNF" ]]; then
        run_cmd cp -a "$GALERA_CNF" "${GALERA_CNF}.bak-$(date +%Y%m%d%H%M%S)"
    fi
    if [[ "$DRY_RUN" == "1" ]]; then
        printf '%s[DRY-RUN]%s écriture de %s :\n%s\n' "$C_YELLOW" "$C_RESET" "$GALERA_CNF" "$desired"
    else
        printf '%s\n' "$desired" > "$GALERA_CNF"
        chmod 644 "$GALERA_CNF"
        log_ok "${GALERA_CNF} écrit"
    fi
fi

# --- Suite --------------------------------------------------------------------------
log_step "Étapes suivantes (manuelles)"
cat <<EOF
  Ce script n'a NI démarré NI bootstrappé le cluster.

  1. Sur les 3 nœuds, arrêter MariaDB :          sudo systemctl stop mariadb
  2. Sur UN SEUL nœud (MYSQL-01), bootstrap :     sudo galera_new_cluster
  3. Sur les 2 autres nœuds, l'un après l'autre : sudo systemctl start mariadb
  4. Vérifier :                                   ./scripts/validation/check-galera.sh

  Procédure complète : docs/03-galera/bootstrap.md
EOF

print_summary
