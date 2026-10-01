#!/usr/bin/env bash
# =============================================================================
# backup-wordpress.sh — Sauvegarde des fichiers WordPress
# -----------------------------------------------------------------------------
# Machine cible : WEB-01 (10.0.10.1) — serveur de référence des fichiers
# Actions       : archive /var/www/wordpress (code, thèmes, extensions, médias),
#                 sans le cache, avec empreinte SHA-256 et droits 600.
# Attention     : l'archive contient wp-config.php (mot de passe SQL, clés) :
#                 elle ne doit JAMAIS être versionnée ni publiée.
# Rétention     : aucune suppression par défaut ; --retention N (jours) explicite.
# Complément    : la base WordPress est sauvegardée par backup-mariadb.sh.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

WP_DIR="/var/www/wordpress"
DEST="/var/backups/wordpress"
RETENTION_DAYS=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --source)    WP_DIR="${2:?}"; shift 2 ;;
        --dest)      DEST="${2:?}"; shift 2 ;;
        --retention) RETENTION_DAYS="${2:?}"; shift 2 ;;
        -h|--help)   echo "Usage : sudo $(basename "$0") [--source DIR] [--dest DIR] [--retention JOURS]"; exit 0 ;;
        *)           die "Option inconnue : $1" ;;
    esac
done
[[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] || die "--retention doit être un nombre de jours"

print_header "Sauvegarde des fichiers WordPress" "WEB-01 (10.0.10.1)"
require_root
require_cmd tar sha256sum

[[ -f "${WP_DIR}/wp-config.php" ]] || die "${WP_DIR} ne ressemble pas à une installation WordPress"
log_ok "Installation détectée : ${WP_DIR}"

install -d -m 700 "$DEST"
umask 077
file="${DEST}/wordpress-$(hostname -s)-$(date +%Y%m%d-%H%M%S).tar.gz"

log_step "Archivage"
if tar --exclude='wp-content/cache' --exclude='wp-content/upgrade' \
       -czf "$file" -C "$(dirname "$WP_DIR")" "$(basename "$WP_DIR")"; then
    sha256sum "$file" > "${file}.sha256"
    log_ok "Archive : ${file} ($(du -h "$file" | cut -f1))"
else
    rm -f "$file"
    log_fail "Échec de l'archivage"
fi

if tar -tzf "$file" >/dev/null 2>&1; then
    log_ok "Archive lisible ($(tar -tzf "$file" | wc -l) entrées)"
else
    log_fail "Archive illisible"
fi

if (( RETENTION_DAYS > 0 )); then
    log_step "Rétention : ${RETENTION_DAYS} jours"
    while IFS= read -r -d '' old; do
        rm -f "$old" "${old}.sha256"
        log_info "Supprimé : ${old}"
    done < <(find "$DEST" -maxdepth 1 -type f -name 'wordpress-*.tar.gz' -mtime +"$RETENTION_DAYS" -print0)
fi

log_warn "L'archive contient wp-config.php (secrets) : stockage chiffré hors du lab, jamais dans Git."
print_summary
