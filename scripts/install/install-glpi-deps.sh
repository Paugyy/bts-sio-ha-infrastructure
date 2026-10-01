#!/usr/bin/env bash
# =============================================================================
# install-glpi-deps.sh — Dépendances d'un serveur GLPI 10
# -----------------------------------------------------------------------------
# Machine cible : GLPI-01 (10.0.10.3) — Debian 12
# Actions       : installe Apache, PHP et les extensions requises par GLPI 10 ;
#                 active mod_rewrite (indispensable, incident INC-05) et mod_remoteip.
# NE FAIT PAS   : télécharger GLPI (version à choisir sur github.com/glpi-project/glpi/releases),
#                 créer la base, lancer l'assistant d'installation.
# Sécurité      : mode SIMULATION par défaut ; --apply pour exécuter.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

DRY_RUN=1
[[ "${1:-}" == "--apply" ]] && DRY_RUN=0
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { echo "Usage : sudo $(basename "$0") [--apply]"; exit 0; }

PACKAGES=(
    apache2 libapache2-mod-php php php-mysql php-curl php-gd php-intl php-ldap
    php-mbstring php-xml php-zip php-bz2 php-bcmath php-apcu mariadb-client curl
)

print_header "Dépendances GLPI (Apache + PHP)" "GLPI-01 (10.0.10.3) — VLAN 301 vWEB"
[[ "$DRY_RUN" == "1" ]] || require_root

log_step "Paquets"
missing_pkgs=()
for p in "${PACKAGES[@]}"; do
    dpkg -s "$p" >/dev/null 2>&1 || missing_pkgs+=("$p")
done
if [[ ${#missing_pkgs[@]} -eq 0 ]]; then
    log_ok "Tous les paquets sont déjà installés"
else
    log_info "À installer : ${missing_pkgs[*]}"
    run_cmd apt-get update
    run_cmd env DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing_pkgs[@]}"
fi

log_step "Modules Apache"
for mod in rewrite remoteip; do
    if [[ -e "/etc/apache2/mods-enabled/${mod}.load" ]]; then
        log_ok "mod_${mod} déjà actif"
    else
        run_cmd a2enmod "$mod"
    fi
done

log_step "Réglages PHP recommandés par GLPI"
php_ini="$(find /etc/php -path '*/apache2/php.ini' 2>/dev/null | head -n1 || true)"
if [[ -n "$php_ini" ]]; then
    if grep -Eq '^[[:space:]]*session\.cookie_httponly[[:space:]]*=[[:space:]]*(On|1)' "$php_ini"; then
        log_ok "session.cookie_httponly = On (${php_ini})"
    else
        log_warn "session.cookie_httponly n'est pas activé dans ${php_ini} (contrôle de sécurité GLPI)"
    fi
else
    log_info "php.ini Apache introuvable (PHP pas encore installé ?)"
fi

log_step "Étapes suivantes"
cat <<EOF
  1. Télécharger GLPI (release officielle), extraire dans /var/www/glpi, chown -R www-data:www-data
  2. vhost  : sudo cp configs/apache/glpi.conf.example /etc/apache2/sites-available/glpi.conf
              sudo a2ensite glpi && sudo a2dissite 000-default && sudo systemctl reload apache2
  3. Base   : créer la base 'glpi' et le compte 'glpi'@'10.0.10.2' (docs/06-glpi/database.md)
  4. Assistant web : http://10.0.10.3/ — serveur SQL : 10.0.10.2 (HAProxy), port 3306
EOF

print_summary
