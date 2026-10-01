#!/usr/bin/env bash
# =============================================================================
# test-web02-failure.sh — Test de bascule : panne de WEB-02
# -----------------------------------------------------------------------------
# Machine cible : ADM-01 (pilote le test) ; WEB-02 (10.0.10.4) est arrêté
# Attendu       : pendant l'arrêt d'Apache sur WEB-02, toutes les requêtes vers
#                 HAProxy (10.0.10.2) sont servies par WEB-01 sans erreur ;
#                 au redémarrage, WEB-02 est réintégré automatiquement.
# Non destructif : mode guidé par défaut ; --auto agit via SSH après confirmation.
# Procédure     : docs/08-tests/wordpress-failover.md (tests T15 et T16)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"
# shellcheck source=../lib/failover.sh
source "${SCRIPT_DIR}/../lib/failover.sh"

failover_parse_args "$@"
run_web_failover "WEB-02" "web02" "WEB-01"
