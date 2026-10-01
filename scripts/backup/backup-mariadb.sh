#!/usr/bin/env bash
# =============================================================================
# backup-mariadb.sh — Sauvegarde logique de toutes les bases du cluster
# -----------------------------------------------------------------------------
# Machine cible : UN nœud Galera, de préférence MYSQL-03 (10.0.20.3).
#                 Un seul nœud suffit : les données sont identiques sur les trois.
# Actions       : vérifie que le nœud est Synced, exporte toutes les bases avec
#                 mariadb-dump --single-transaction (pas de verrou global),
#                 compresse, calcule l'empreinte SHA-256, droits 600.
# Rétention     : AUCUNE suppression par défaut. --retention N supprime uniquement
#                 les fichiers mariadb-*.sql.gz de plus de N jours du dossier cible.
# Restauration  : docs/10-backup-recovery/mariadb.md
#
# Exemple (cron, tous les jours à 02:30) :
#   30 2 * * * root /opt/bts-sio-ha-infrastructure/scripts/backup/backup-mariadb.sh --retention 14
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

DEST="/var/backups/mariadb"
RETENTION_DAYS=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dest)      DEST="${2:?}"; shift 2 ;;
        --retention) RETENTION_DAYS="${2:?}"; shift 2 ;;
        -h|--help)   echo "Usage : sudo $(basename "$0") [--dest DOSSIER] [--retention JOURS]"; exit 0 ;;
        *)           die "Option inconnue : $1" ;;
    esac
done
[[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] || die "--retention doit être un nombre de jours"

print_header "Sauvegarde logique MariaDB" "Un nœud Galera (recommandé : MYSQL-03)"
require_root
require_cmd mariadb mariadb-dump gzip sha256sum

log_step "État du nœud"
state="$(mariadb -N -B -e "SHOW GLOBAL STATUS LIKE 'wsrep_local_state_comment'" 2>/dev/null | awk '{print $2}')"
if [[ "$state" == "Synced" ]]; then
    log_ok "wsrep_local_state_comment = Synced"
else
    log_fail "Nœud non synchronisé (${state:-inconnu}) : la sauvegarde pourrait être incohérente. Abandon."
    print_summary || true
    exit 1
fi

log_step "Export"
install -d -m 700 "$DEST"
file="${DEST}/mariadb-$(hostname -s)-$(date +%Y%m%d-%H%M%S).sql.gz"
umask 077
# --single-transaction : instantané InnoDB cohérent sans bloquer les écritures du cluster
if mariadb-dump --all-databases --single-transaction --routines --events --triggers \
        --hex-blob --default-character-set=utf8mb4 | gzip -c > "$file"; then
    sha256sum "$file" > "${file}.sha256"
    log_ok "Sauvegarde : ${file} ($(du -h "$file" | cut -f1))"
    log_ok "Empreinte  : ${file}.sha256"
else
    rm -f "$file"
    log_fail "Échec de mariadb-dump"
fi

log_step "Contrôle d'intégrité"
if gzip -t "$file" 2>/dev/null; then
    log_ok "Archive gzip valide"
else
    log_fail "Archive gzip corrompue"
fi

if (( RETENTION_DAYS > 0 )); then
    log_step "Rétention : ${RETENTION_DAYS} jours"
    while IFS= read -r -d '' old; do
        rm -f "$old" "${old}.sha256"
        log_info "Supprimé : ${old}"
    done < <(find "$DEST" -maxdepth 1 -type f -name 'mariadb-*.sql.gz' -mtime +"$RETENTION_DAYS" -print0)
fi

log_warn "Une sauvegarde sur le même hôte Proxmox n'est pas une sauvegarde : copier ${DEST} hors du lab (règle 3-2-1)."
print_summary
