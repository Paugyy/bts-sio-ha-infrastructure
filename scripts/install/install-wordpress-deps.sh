#!/usr/bin/env bash
# =============================================================================
# install-wordpress-deps.sh — Dépendances d'un serveur WordPress
# -----------------------------------------------------------------------------
# Machine cible : WEB-01 (10.0.10.1) et WEB-02 (10.0.10.4) — Debian 12
# Actions       : installe Apache, PHP et extensions, rsync, client MariaDB ;
#                 active mod_rewrite et mod_remoteip ;
#                 option --download : télécharge WordPress dans /var/www/wordpress
#                 (empreinte SHA-1 vérifiée) SI le dossier n'existe pas.
# NE FAIT PAS   : créer wp-config.php, toucher à la base de données.
# Sécurité      : mode SIMULATION par défaut ; --apply pour exécuter.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

DRY_RUN=1
DOWNLOAD=0
WP_DIR="/var/www/wordpress"
WP_URL="https://wordpress.org/latest.tar.gz"

for arg in "$@"; do
    case "$arg" in
        --apply)    DRY_RUN=0 ;;
        --download) DOWNLOAD=1 ;;
        -h|--help)  echo "Usage : sudo $(basename "$0") [--apply] [--download]"; exit 0 ;;
        *)          die "Option inconnue : $arg" ;;
    esac
done

PACKAGES=(
    apache2 libapache2-mod-php php php-mysql php-curl php-gd php-mbstring
    php-xml php-zip php-intl php-imagick mariadb-client rsync curl
)

print_header "Dépendances WordPress (Apache + PHP)" "WEB-01 (10.0.10.1) / WEB-02 (10.0.10.4)"
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

if [[ "$DOWNLOAD" == "1" ]]; then
    log_step "Téléchargement de WordPress"
    if [[ -d "$WP_DIR" ]]; then
        log_ok "${WP_DIR} existe déjà : aucun téléchargement (non destructif)"
    else
        tmp="$(mktemp -d)"
        TMP_FILES+=("${tmp}/latest.tar.gz")
        run_cmd curl -fsSL -o "${tmp}/latest.tar.gz" "$WP_URL"
        if [[ "$DRY_RUN" == "0" ]]; then
            expected="$(curl -fsSL "${WP_URL}.sha1")"
            actual="$(sha1sum "${tmp}/latest.tar.gz" | awk '{print $1}')"
            [[ "$expected" == "$actual" ]] || die "Empreinte SHA-1 invalide : archive corrompue ou altérée"
            log_ok "Empreinte SHA-1 vérifiée"
        fi
        run_cmd tar -xzf "${tmp}/latest.tar.gz" -C /var/www
        run_cmd chown -R www-data:www-data "$WP_DIR"
    fi
fi

if [[ "$DRY_RUN" == "0" ]] && command -v apachectl >/dev/null 2>&1; then
    if apachectl configtest >/dev/null 2>&1; then
        log_ok "apachectl configtest : Syntax OK"
    else
        log_fail "apachectl configtest en échec"
    fi
fi

log_step "Étapes suivantes"
cat <<EOF
  1. vhost   : sudo cp configs/apache/wordpress.conf.example /etc/apache2/sites-available/wordpress.conf
               sudo a2ensite wordpress && sudo a2dissite 000-default && sudo systemctl reload apache2
  2. config  : sudo cp configs/wordpress/wp-config.php.example ${WP_DIR}/wp-config.php (remplacer <SECRET>)
  3. base    : DB_HOST = 10.0.10.2:3306 (HAProxy) — compte 'wordpress'@'10.0.10.2'
  4. WEB-02  : synchroniser les fichiers depuis WEB-01 (docs/05-wordpress/synchronization.md)
EOF

print_summary
