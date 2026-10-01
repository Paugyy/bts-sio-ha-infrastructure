#!/usr/bin/env bash
# =============================================================================
# test-web01-failure.sh — Test de bascule : panne de WEB-01
# -----------------------------------------------------------------------------
# Machine cible : ADM-01 (pilote le test) ; WEB-01 (10.0.10.1) est arrêté
# Attendu       : pendant l'arrêt d'Apache sur WEB-01, toutes les requêtes vers
#                 HAProxy (10.0.10.2) sont servies par WEB-02 sans erreur ;
#                 au redémarrage, WEB-01 est réintégré automatiquement.
# Non destructif : mode guidé par défaut (l'opérateur arrête Apache lui-même) ;
#                 --auto agit via SSH après confirmation, et relance Apache si interruption.
# Procédure     : docs/08-tests/wordpress-failover.md (tests T14 et T16)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"
# shellcheck source=../lib/failover.sh
source "${SCRIPT_DIR}/../lib/failover.sh"

failover_parse_args "$@"
run_web_failover "WEB-01" "web01" "WEB-02"
