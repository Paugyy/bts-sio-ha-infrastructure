#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# failover.sh — procédure guidée de test de bascule d'un serveur web
# -----------------------------------------------------------------------------
# Chargé par scripts/failover/test-web0X-failure.sh (ne pas exécuter directement).
# Nécessite common.sh. Utilise l'en-tête X-Served-By ajouté par HAProxy.
#
# Déroulé :
#   1. état initial : les deux serveurs répondent via HAProxy
#   2. arrêt d'Apache sur le serveur testé (manuel guidé, ou --auto via SSH)
#   3. toutes les requêtes doivent réussir et être servies par l'autre serveur
#   4. redémarrage d'Apache, puis attente de la réintégration par HAProxy
# =============================================================================

HAPROXY_URL="${HAPROXY_URL:-http://10.0.10.2/}"
REQUESTS="${REQUESTS:-10}"
AUTO=0
SAVE_LOG=0
_FAILOVER_STOPPED_ALIAS=""

failover_usage() {
    cat <<EOF
Usage : $(basename "$0") [--auto] [--requests N] [--save]
  (défaut)    Mode guidé : le script indique la commande à lancer sur le serveur et attend.
  --auto      Arrête/redémarre Apache via SSH (alias de ~/.ssh/config, sudo requis sur la cible).
  --requests  Nombre de requêtes par phase (défaut : ${REQUESTS}).
  --save      Enregistre la sortie dans evidence/test-results/.
Variable : HAPROXY_URL (défaut : ${HAPROXY_URL})
EOF
}

failover_parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --auto)     AUTO=1; shift ;;
            --requests) REQUESTS="${2:?}"; shift 2 ;;
            --save)     SAVE_LOG=1; shift ;;
            -h|--help)  failover_usage; exit 0 ;;
            *)          failover_usage; die "Option inconnue : $1" ;;
        esac
    done
}

# Envoie N requêtes et remplit les variables globales :
#   PHASE_ERRORS (nb de réponses en erreur) et PHASE_BACKENDS (backends vus, ex. "WEB-01 WEB-02")
sample_requests() {
    local n="$1" i code backend
    declare -A seen=()
    PHASE_ERRORS=0
    for (( i = 1; i <= n; i++ )); do
        IFS=$'\t' read -r code backend < <(http_probe "$HAPROXY_URL")
        if http_is_up "$code"; then
            seen["$backend"]=$(( ${seen["$backend"]:-0} + 1 ))
        else
            PHASE_ERRORS=$((PHASE_ERRORS + 1))
        fi
    done
    PHASE_BACKENDS=""
    for backend in "${!seen[@]}"; do
        PHASE_BACKENDS+="${backend}(${seen[$backend]}) "
    done
    log_info "Requêtes : ${n} — erreurs : ${PHASE_ERRORS} — réparties sur : ${PHASE_BACKENDS:-aucun}"
}

# Action sur Apache du serveur testé : stop | start
apache_action() {
    local action="$1" label="$2" alias="$3"
    if [[ "$AUTO" == "1" ]]; then
        confirm "Exécuter 'sudo systemctl ${action} apache2' sur ${label} via ssh ${alias} ?" \
            || die "Annulé par l'opérateur."
        ssh -t "$alias" "sudo systemctl ${action} apache2"
    else
        printf '\n    %sSUR %s%s\n\n    sudo systemctl %s apache2\n\n' "$C_BOLD" "$label" "$C_RESET" "$action"
        pause_for_operator "Lancer la commande ci-dessus sur ${label}"
    fi
    if [[ "$action" == "stop" ]]; then _FAILOVER_STOPPED_ALIAS="$alias"; else _FAILOVER_STOPPED_ALIAS=""; fi
}

# En mode --auto, si le script est interrompu après l'arrêt, Apache est relancé
failover_safety_net() {
    if [[ "$AUTO" == "1" && -n "$_FAILOVER_STOPPED_ALIAS" ]]; then
        log_warn "Interruption : redémarrage d'Apache sur ${_FAILOVER_STOPPED_ALIAS}"
        ssh "$_FAILOVER_STOPPED_ALIAS" "sudo systemctl start apache2" || true
    fi
    cleanup_tmp_files
}

# Usage : run_web_failover <serveur testé> <alias SSH> <serveur survivant>
run_web_failover() {
    local down_label="$1" down_alias="$2" up_label="$3" waited=0

    trap failover_safety_net EXIT
    trap 'exit 130' INT TERM

    if [[ "$SAVE_LOG" == "1" ]]; then
        local repo_root log_file
        repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
        log_file="${repo_root}/evidence/test-results/$(date +%Y%m%d-%H%M%S)-failover-${down_alias}.log"
        exec > >(tee -a "$log_file") 2>&1
        log_info "Sortie enregistrée dans ${log_file}"
    fi

    print_header "Test de bascule : panne de ${down_label}" "ADM-01 (pilote) — ${down_label} (serveur arrêté)"
    require_cmd curl
    log_info "Point d'entrée testé : ${HAPROXY_URL}"

    log_step "1/4 État initial"
    sample_requests "$REQUESTS"
    if (( PHASE_ERRORS == 0 )) && [[ "$PHASE_BACKENDS" == *"$down_label"* && "$PHASE_BACKENDS" == *"$up_label"* ]]; then
        log_ok "Les deux serveurs répondent via HAProxy"
    else
        log_fail "État initial non nominal : corriger avant de tester la bascule"
        print_summary || true
        return 1
    fi

    log_step "2/4 Arrêt d'Apache sur ${down_label}"
    apache_action stop "$down_label" "$down_alias"

    log_step "3/4 Service pendant la panne"
    sample_requests "$REQUESTS"
    if (( PHASE_ERRORS == 0 )); then
        log_ok "Aucune erreur côté client pendant la panne"
    else
        log_fail "${PHASE_ERRORS} requête(s) en erreur pendant la panne"
    fi
    if [[ "$PHASE_BACKENDS" == *"$up_label"* && "$PHASE_BACKENDS" != *"$down_label"* ]]; then
        log_ok "Toutes les réponses proviennent de ${up_label}"
    else
        log_fail "Réponses inattendues : ${PHASE_BACKENDS}"
    fi

    log_step "4/4 Redémarrage et réintégration de ${down_label}"
    apache_action start "$down_label" "$down_alias"
    # rise 2 x inter 3s : réintégration attendue en ~6 s ; on attend jusqu'à 30 s
    while (( waited < 30 )); do
        sample_requests 4 >/dev/null
        [[ "$PHASE_BACKENDS" == *"$down_label"* ]] && break
        sleep 3
        waited=$((waited + 3))
    done
    if [[ "$PHASE_BACKENDS" == *"$down_label"* ]]; then
        log_ok "${down_label} réintégré automatiquement par HAProxy (~${waited} s)"
    else
        log_fail "${down_label} non réintégré après 30 s (vérifier check-haproxy.sh)"
    fi

    print_summary
}
