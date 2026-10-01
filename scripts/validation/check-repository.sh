#!/usr/bin/env bash
# =============================================================================
# check-repository.sh — Contrôle qualité et sécurité du dépôt
# -----------------------------------------------------------------------------
# Machine cible : poste de développement (make check) et GitHub Actions (--ci)
# Contrôles     : dossiers et fichiers obligatoires, README des dossiers,
#                 absence de fichiers sensibles et de motifs de secrets,
#                 bit exécutable des scripts, syntaxe bash, configs .example.
# Non destructif : lecture seule.
# Code retour   : 0 = conforme, 1 = non conforme
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

CI_MODE=0
[[ "${1:-}" == "--ci" ]] && CI_MODE=1

cd "$REPO_ROOT"
print_header "Contrôle qualité et sécurité du dépôt" "Poste de développement / GitHub Actions"

# Annotation GitHub en mode CI (affichée sur la PR)
annotate() {
    [[ "$CI_MODE" == "1" ]] && printf '::error::%s\n' "$1"
    return 0
}
fail() { log_fail "$1"; annotate "$1"; }

# --- 1. Dossiers obligatoires --------------------------------------------------
log_step "Dossiers obligatoires"
REQUIRED_DIRS=(
    .github/ISSUE_TEMPLATE .github/workflows
    docs/00-overview docs/01-architecture docs/02-pfsense docs/03-galera docs/04-haproxy
    docs/05-wordpress docs/06-glpi docs/07-security docs/08-tests docs/09-troubleshooting
    docs/10-backup-recovery docs/11-bts-sio
    configs/haproxy configs/galera/mysql01 configs/galera/mysql02 configs/galera/mysql03
    configs/apache configs/wordpress configs/ssh configs/pfsense
    scripts/install scripts/validation scripts/failover scripts/backup scripts/utilities scripts/lib
    generator/css generator/js generator/examples
    diagrams evidence/screenshots evidence/test-results deliverables/html deliverables/pdf examples
)
missing=0
for d in "${REQUIRED_DIRS[@]}"; do
    [[ -d "$d" ]] || { fail "Dossier manquant : $d"; missing=1; }
done
[[ "$missing" == "0" ]] && log_ok "${#REQUIRED_DIRS[@]} dossiers présents"

# --- 2. Fichiers obligatoires --------------------------------------------------
log_step "Fichiers obligatoires"
REQUIRED_FILES=(
    README.md LICENSE SECURITY.md CONTRIBUTING.md CHANGELOG.md CODE_OF_CONDUCT.md
    .gitignore .editorconfig
    .github/PULL_REQUEST_TEMPLATE.md
    .github/ISSUE_TEMPLATE/bug_report.yml .github/ISSUE_TEMPLATE/documentation.yml
    .github/ISSUE_TEMPLATE/infrastructure_issue.yml
    .github/workflows/markdown-lint.yml .github/workflows/shellcheck.yml
    .github/workflows/validate-configs.yml .github/workflows/links-check.yml
    docs/08-tests/validation-matrix.md docs/09-troubleshooting/incidents.md
    docs/01-architecture/spof-analysis.md docs/00-overview/deployment-order.md
    docs/11-bts-sio/pre-publish-checklist.md
    generator/index.html generator/examples/reference-infrastructure.json
    diagrams/architecture.svg
)
missing=0
for f in "${REQUIRED_FILES[@]}"; do
    [[ -s "$f" ]] || { fail "Fichier manquant ou vide : $f"; missing=1; }
done
[[ "$missing" == "0" ]] && log_ok "${#REQUIRED_FILES[@]} fichiers présents et non vides"

# --- 3. README des dossiers importants -------------------------------------------
log_step "README des dossiers"
README_DIRS=(docs configs configs/haproxy configs/pfsense scripts generator diagrams evidence deliverables examples)
missing=0
for d in "${README_DIRS[@]}"; do
    [[ -s "$d/README.md" ]] || { fail "README manquant : $d/README.md"; missing=1; }
done
[[ "$missing" == "0" ]] && log_ok "README présent dans ${#README_DIRS[@]} dossiers"

# --- 4. Configurations d'exemple -------------------------------------------------
log_step "Configurations .example"
EXAMPLES=(
    configs/haproxy/haproxy.cfg.example
    configs/galera/mysql01/50-server.cnf.example configs/galera/mysql01/60-galera.cnf.example
    configs/galera/mysql02/50-server.cnf.example configs/galera/mysql02/60-galera.cnf.example
    configs/galera/mysql03/50-server.cnf.example configs/galera/mysql03/60-galera.cnf.example
    configs/apache/wordpress.conf.example configs/apache/glpi.conf.example
    configs/wordpress/wp-config.php.example
    configs/ssh/windows-ssh-config.example configs/ssh/linux-ssh-config.example
)
missing=0
for f in "${EXAMPLES[@]}"; do
    [[ -s "$f" ]] || { fail "Configuration d'exemple manquante ou vide : $f"; missing=1; }
done
[[ "$missing" == "0" ]] && log_ok "${#EXAMPLES[@]} configurations d'exemple présentes"

# Toute configuration publiée dans configs/ doit être un .example, un .md ou un README
while IFS= read -r -d '' f; do
    fail "Fichier non-.example dans configs/ : $f (risque de configuration réelle publiée)"
done < <(find configs -type f ! -name '*.example' ! -name '*.md' -print0)

# --- 5. Fichiers sensibles ---------------------------------------------------------
log_step "Fichiers sensibles"
found=0
while IFS= read -r -d '' f; do
    fail "Fichier sensible détecté : $f"
    found=1
done < <(find . -path ./.git -prune -o -path ./node_modules -prune -o -type f \( \
    -name 'id_rsa' -o -name 'id_dsa' -o -name 'id_ecdsa' -o -name 'id_ed25519' \
    -o -name '*.pem' -o -name '*.key' -o -name '*.p12' -o -name '*.pfx' -o -name '*.ppk' \
    -o -name '.env' -o -name '*.env' -o -name '.my.cnf' -o -name 'config-*.xml' \
    -o -name '*.sql' -o -name '*.sql.gz' -o -name '*.vma*' -o -name 'wp-config.php' \
    \) -print0)
[[ "$found" == "0" ]] && log_ok "Aucun fichier sensible"

# --- 6. Motifs de secrets dans le contenu ------------------------------------------
log_step "Motifs de secrets"
# Une valeur commençant par "<" (placeholder), "*" (masquée) ou "$" (variable) est acceptée.
SECRET_PATTERNS=(
    '-----BEGIN ([A-Z]+ )?PRIVATE KEY-----'
    "DB_PASSWORD'[[:space:]]*,[[:space:]]*'[^<'*]"
    "IDENTIFIED BY '[^<'*\$]"
    'stats auth [^:[:space:]]+:[^<[:space:]]'
    "^[[:space:]]*(password|passwd)[[:space:]]*=[[:space:]]*[\"']?[^<*\$\"'[:space:]]"
    'AKIA[0-9A-Z]{16}'
    'gh[pousr]_[A-Za-z0-9]{36}'
    'xox[baprs]-[A-Za-z0-9-]{10,}'
)
found=0
for pattern in "${SECRET_PATTERNS[@]}"; do
    while IFS= read -r match; do
        [[ -z "$match" ]] && continue
        fail "Secret potentiel : ${match}"
        found=1
    # Ce script contient les motifs eux-mêmes : il est exclu de la recherche
    done < <(grep -rInE --exclude-dir=.git --exclude-dir=node_modules \
        --exclude=check-repository.sh -e "$pattern" . 2>/dev/null || true)
done
[[ "$found" == "0" ]] && log_ok "Aucun motif de secret détecté"

# --- 7. Scripts : bit exécutable et syntaxe ------------------------------------------
log_step "Scripts shell"
mapfile -t SCRIPTS < <(find scripts -type f -name '*.sh' ! -path 'scripts/lib/*' | sort)
not_exec=0
for s in "${SCRIPTS[@]}"; do
    mode=""
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        mode="$(git ls-files -s -- "$s" | awk '{print $1}')"
    fi
    if [[ -n "$mode" ]]; then
        # Fichier suivi par Git : le mode enregistré fait foi (y compris sous Windows)
        [[ "$mode" == "100755" ]] || { fail "Script non exécutable dans Git : $s (git update-index --chmod=+x $s)"; not_exec=1; }
    elif [[ ! -x "$s" ]]; then
        log_warn "Script non exécutable localement : $s (chmod +x)"
    fi
done
[[ "$not_exec" == "0" ]] && log_ok "Bit exécutable vérifié sur ${#SCRIPTS[@]} scripts"

syntax_errors=0
while IFS= read -r -d '' s; do
    if ! out="$(bash -n "$s" 2>&1)"; then
        fail "Erreur de syntaxe : $s — $out"
        syntax_errors=1
    fi
    head -n1 "$s" | grep -q '^#!/usr/bin/env bash' || log_warn "Shebang inattendu : $s"
done < <(find scripts -type f -name '*.sh' -print0)
[[ "$syntax_errors" == "0" ]] && log_ok "Syntaxe bash valide (bash -n)"

# Les scripts exécutables doivent activer le mode strict
for s in "${SCRIPTS[@]}"; do
    grep -q '^set -euo pipefail' "$s" || log_warn "Pas de 'set -euo pipefail' : $s"
done

# --- 8. Preuves : uniquement des fichiers réels -----------------------------------------
log_step "Dossier evidence/"
count="$(find evidence/screenshots -type f ! -name '.gitkeep' | wc -l | tr -d ' ')"
log_info "${count} capture(s) dans evidence/screenshots (ajoutées manuellement, jamais générées)"

print_summary
