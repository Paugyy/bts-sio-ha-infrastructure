#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# common.sh — fonctions partagées par les scripts du dépôt
# -----------------------------------------------------------------------------
# Ce fichier n'est pas exécuté directement : il est chargé par "source".
# Fournit : affichage normalisé ([INFO] [OK] [WARN] [FAIL]), compteurs,
# mode simulation (DRY_RUN), gestion des fichiers temporaires, accès MariaDB.
# =============================================================================

# --- Couleurs (désactivées si la sortie n'est pas un terminal ou si NO_COLOR) -
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_BLUE=$'\033[34m'
    C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'
else
    C_RESET=""; C_BOLD=""; C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""
fi

# --- Compteurs de résultats ---------------------------------------------------
OK_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

# Mode simulation : 1 = affiche les actions sans les exécuter (défaut des scripts d'installation)
DRY_RUN="${DRY_RUN:-0}"

# --- Affichage ----------------------------------------------------------------
log_info()  { printf '%s[INFO]%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
log_ok()    { printf '%s[OK]%s   %s\n' "$C_GREEN" "$C_RESET" "$*"; OK_COUNT=$((OK_COUNT + 1)); }
log_warn()  { printf '%s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; WARN_COUNT=$((WARN_COUNT + 1)); }
log_fail()  { printf '%s[FAIL]%s %s\n' "$C_RED" "$C_RESET" "$*"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
log_step()  { printf '\n%s==> %s%s\n' "$C_BOLD" "$*" "$C_RESET"; }
die()       { printf '%s[ERROR]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 2; }

# Bandeau de début : rôle du script et machine sur laquelle il doit tourner
# Usage : print_header "Rôle" "Machine cible"
print_header() {
    local role="$1" target="$2"
    printf '%s\n' "============================================================"
    printf '%s %s\n' "${C_BOLD}Script        :${C_RESET}" "$(basename "$0")"
    printf '%s %s\n' "${C_BOLD}Rôle          :${C_RESET}" "$role"
    printf '%s %s\n' "${C_BOLD}Machine cible :${C_RESET}" "$target"
    printf '%s %s\n' "${C_BOLD}Exécuté sur   :${C_RESET}" "$(hostname 2>/dev/null || echo inconnu)"
    printf '%s %s\n' "${C_BOLD}Date          :${C_RESET}" "$(date '+%Y-%m-%d %H:%M:%S')"
    if [[ "$DRY_RUN" == "1" ]]; then
        printf '%s\n' "${C_YELLOW}Mode          : SIMULATION (aucune modification, ajouter --apply pour exécuter)${C_RESET}"
    fi
    printf '%s\n' "============================================================"
}

# Bilan final et code de sortie : 0 si aucun échec, 1 sinon
print_summary() {
    printf '\n%s\n' "------------------------------------------------------------"
    printf 'Résultat : %s%d OK%s, %s%d avertissement(s)%s, %s%d échec(s)%s\n' \
        "$C_GREEN" "$OK_COUNT" "$C_RESET" "$C_YELLOW" "$WARN_COUNT" "$C_RESET" "$C_RED" "$FAIL_COUNT" "$C_RESET"
    printf '%s\n' "------------------------------------------------------------"
    if (( FAIL_COUNT > 0 )); then
        return 1
    fi
    return 0
}

# --- Prérequis ------------------------------------------------------------------
require_cmd() {
    local cmd
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || die "Commande requise absente : $cmd"
    done
}

require_root() {
    [[ "${EUID}" -eq 0 ]] || die "Ce script doit être lancé avec sudo (root)."
}

# Exécute une commande, ou l'affiche seulement en mode simulation
run_cmd() {
    if [[ "$DRY_RUN" == "1" ]]; then
        printf '%s[DRY-RUN]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"
    else
        log_info "Exécution : $*"
        "$@"
    fi
}

# Exécute avec sudo si l'utilisateur n'est pas root
as_root() {
    if [[ "${EUID}" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

# Demande une confirmation (o/N). Retourne 1 si non interactif.
confirm() {
    local answer
    [[ -t 0 ]] || return 1
    read -r -p "$1 [o/N] " answer
    [[ "$answer" =~ ^[oOyY]$ ]]
}

# Attend que l'opérateur appuie sur Entrée (étapes manuelles guidées)
pause_for_operator() {
    [[ -t 0 ]] || die "Étape manuelle requise mais aucun terminal interactif."
    read -r -p "$1 — appuyer sur Entrée une fois fait... " _
}

# --- Fichiers temporaires (supprimés à la sortie) ---------------------------------
TMP_FILES=()
cleanup_tmp_files() {
    local f
    for f in "${TMP_FILES[@]}"; do
        [[ -n "$f" && -f "$f" ]] && rm -f "$f"
    done
    return 0
}
trap cleanup_tmp_files EXIT

# --- MariaDB --------------------------------------------------------------------
# Crée un fichier d'options client temporaire (droits 600) contenant l'identifiant
# et, si nécessaire, le mot de passe. Évite de passer le mot de passe en argument
# (visible dans "ps") ou de l'écrire dans l'historique du shell.
# Usage : create_mysql_defaults <utilisateur> <demander_mot_de_passe:0|1>
# Résultat : variable globale MYSQL_DEFAULTS (chemin du fichier)
MYSQL_DEFAULTS=""
create_mysql_defaults() {
    local user="$1" ask_password="${2:-0}" password=""
    MYSQL_DEFAULTS="$(mktemp)"
    TMP_FILES+=("$MYSQL_DEFAULTS")
    chmod 600 "$MYSQL_DEFAULTS"
    if [[ "$ask_password" == "1" ]]; then
        if [[ -n "${MYSQL_PASSWORD:-}" ]]; then
            password="$MYSQL_PASSWORD"
        else
            [[ -t 0 ]] || die "Mot de passe requis : terminal interactif ou variable MYSQL_PASSWORD."
            read -r -s -p "Mot de passe MariaDB pour '${user}' : " password
            printf '\n'
        fi
    fi
    {
        printf '[client]\n'
        printf 'user=%s\n' "$user"
        if [[ -n "$password" ]]; then
            printf 'password=%s\n' "$password"
        fi
        printf 'connect-timeout=5\n'
    } > "$MYSQL_DEFAULTS"
}

# Valeurs d'une ou plusieurs variables wsrep d'un nœud, au format "nom<TAB>valeur"
# Usage : galera_status <hôte> [port]   (nécessite MYSQL_DEFAULTS)
galera_status() {
    local host="$1" port="${2:-3306}"
    mariadb --defaults-extra-file="$MYSQL_DEFAULTS" -h "$host" -P "$port" -N -B -e \
        "SHOW GLOBAL STATUS WHERE Variable_name IN ('wsrep_cluster_size','wsrep_cluster_status','wsrep_local_state_comment','wsrep_ready','wsrep_connected')" 2>/dev/null
}

# --- HTTP -----------------------------------------------------------------------
# Effectue une requête HEAD/GET et renvoie "code_http<TAB>backend" (backend = X-Served-By)
# Usage : http_probe <url>
http_probe() {
    local url="$1" headers code backend
    headers="$(curl -s -o /dev/null -D - --max-time 5 "$url" 2>/dev/null || true)"
    code="$(printf '%s\n' "$headers" | awk 'toupper($1) ~ /^HTTP\// {c=$2} END {print (c=="" ? "000" : c)}')"
    backend="$(printf '%s\n' "$headers" | awk -F': *' 'tolower($1)=="x-served-by" {gsub(/\r/,"",$2); print $2}' | tail -n1)"
    printf '%s\t%s\n' "$code" "${backend:--}"
}

# Code HTTP considéré comme "service disponible" : 2xx ou 3xx
http_is_up() {
    [[ "$1" =~ ^[23][0-9][0-9]$ ]]
}
