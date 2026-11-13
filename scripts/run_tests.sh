#!/bin/bash
# =============================================================================
# run_tests.sh - run every shinyFiles test layer and write a test report
#
# Stages run simple -> complex, and stop at the first failing stage unless
# --continue is given:
#   1. R unit and server tests      (tests/testthat, no browser)
#   2. R browser tests (shinytest2) (tests/testthat/test-*-e2e.R, catalogue)
#   3. Playwright                   (tests/playwright, Chromium + Firefox)
#   4. Coverage                     (covr for R/, V8 for shinyFiles.js)
#
# Usage:
#   ./scripts/run_tests.sh              # stop on first failure
#   ./scripts/run_tests.sh --continue   # run every stage
#   ./scripts/run_tests.sh --help
#
# Environment:
#   RSCRIPT     Rscript to use (default: Rscript on PATH)
#   BROWSERS    Playwright browsers (default: "chromium firefox")
#
# Output: Documentation/.staging/TestReport.md and test_metadata.json
# (gitignored; overwritten on every run).
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

CONTINUE_ON_FAILURE=false
for arg in "$@"; do
    case $arg in
        --continue|-c) CONTINUE_ON_FAILURE=true ;;
        --help|-h)
            sed -n '3,23p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "Unknown option: $arg (see --help)"; exit 2 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT" || exit 1

RSCRIPT="${RSCRIPT:-Rscript}"
BROWSERS="${BROWSERS:-chromium firefox}"
# The browser tests are skipped on CRAN; this run is not CRAN.
export NOT_CRAN=true

STAGING_DIR="$PROJECT_ROOT/Documentation/.staging"
mkdir -p "$STAGING_DIR"
REPORT_FILE="$STAGING_DIR/TestReport.md"

# --- browser housekeeping ----------------------------------------------------

# A stage that dies hard never reaches its own cleanup. Kill only headless
# browsers that have been orphaned (parent is init), so a test run elsewhere on
# the machine is left alone.
reap_orphan_browsers() {
    local pids
    pids=$(ps -o pid=,ppid=,args= -u "$(id -u)" 2>/dev/null \
        | awk '$2 == 1 && /--headless/ && /([Cc]hrome|[Ff]irefox)/ { print $1 }')
    if [[ -n "$pids" ]]; then
        kill -TERM $pids 2>/dev/null; sleep 1; kill -KILL $pids 2>/dev/null
    fi
    true
}

# --- metadata ------------------------------------------------------------------

USER_NAME=$(whoami)
USER_FULL_NAME=$(git config user.name 2>/dev/null || echo "$USER_NAME")
USER_EMAIL=$(git config user.email 2>/dev/null || echo "")
GIT_HASH=$(git rev-parse HEAD)
GIT_HASH_SHORT=$(git rev-parse --short HEAD)
GIT_BRANCH=$(git branch --show-current)
GIT_DIRTY=$([ -n "$(git status --porcelain)" ] && echo "yes" || echo "no")
DATE=$(date +"%Y-%m-%d")
DATETIME=$(date +"%Y-%m-%d %H:%M:%S")
PKG_VERSION=$(grep '^Version:' DESCRIPTION | awk '{print $2}')
CURRENT_VERSION=$(git tag -l --sort=-v:refname | grep -E '^v?[0-9]+\.[0-9]+(\.[0-9]+)?$' | head -n1)
CURRENT_VERSION="${CURRENT_VERSION:-none}"

echo -e "${YELLOW}Collecting environment information...${NC}"
OS_INFO=$(uname -srm)
R_VERSION=$("$RSCRIPT" -e "cat(R.version.string)" 2>/dev/null || echo "R not found")
R_PACKAGES=$("$RSCRIPT" -e "
  pkgs <- c('shiny', 'testthat', 'shinytest2', 'chromote', 'covr', 'fs', 'later', 'pkgload')
  for (p in pkgs) {
    v <- tryCatch(as.character(packageVersion(p)), error = function(e) 'not installed')
    cat(sprintf('| %s | %s |\n', p, v))
  }
" 2>/dev/null || echo "| (unable to list) | |")
PY_PACKAGES=$(cd tests/playwright && uv run --frozen python -c "
from importlib.metadata import version
for p in ('pytest', 'pytest-playwright', 'playwright'):
    try: print(f'| {p} | {version(p)} |')
    except Exception: print(f'| {p} | not installed |')
" 2>/dev/null || echo "| (uv environment not set up) | |")

echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}shinyFiles test runner${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo -e "Date:     ${CYAN}$DATETIME${NC}"
echo -e "Run by:   ${CYAN}$USER_FULL_NAME${NC} ($USER_NAME)"
echo -e "Commit:   ${CYAN}$GIT_HASH_SHORT${NC} on $GIT_BRANCH (uncommitted changes: $GIT_DIRTY)"
echo -e "Package:  ${CYAN}$PKG_VERSION${NC}"
echo -e "Mode:     $([ "$CONTINUE_ON_FAILURE" = true ] && echo "${YELLOW}continue on failure${NC}" || echo "${BLUE}stop on failure${NC}")"
echo ""

cat > "$REPORT_FILE" << EOF
# shinyFiles Test Report

## Test Run Information

| Field | Value |
|-------|-------|
| Date | $DATETIME |
| Run By | $USER_FULL_NAME ($USER_NAME) |
| Email | $USER_EMAIL |
| Git Branch | $GIT_BRANCH |
| Git Hash | $GIT_HASH |
| Uncommitted Changes | $GIT_DIRTY |
| Package Version | $PKG_VERSION |
| Latest Release Tag | $CURRENT_VERSION |

## Environment

| Field | Value |
|-------|-------|
| OS | $OS_INFO |
| R Version | $R_VERSION |
| Playwright Browsers | $BROWSERS |

### R Packages

| Package | Version |
|---------|---------|
$R_PACKAGES

### Python Packages (tests/playwright)

| Package | Version |
|---------|---------|
$PY_PACKAGES

## Test Results
EOF

# --- stages --------------------------------------------------------------------

STAGES=(
    "unit|R unit and server tests|\"$RSCRIPT\" scripts/run-r-stage.R unit"
    "browser|R browser tests (shinytest2, input catalogue)|\"$RSCRIPT\" scripts/run-r-stage.R browser"
    "playwright|Playwright ($BROWSERS)|cd tests/playwright && RSCRIPT=\"$RSCRIPT\" uv run --frozen pytest -q -p no:warnings $(printf -- '--browser %s ' $BROWSERS)"
    "coverage|R coverage (covr)|\"$RSCRIPT\" scripts/run-r-stage.R coverage"
)

TOTAL=${#STAGES[@]}
PASSED=0
FAILED=0
SKIPPED=0
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0
R_COVERAGE=""
JS_COVERAGE=""

for i in "${!STAGES[@]}"; do
    IFS='|' read -r STAGE_ID STAGE_DESC STAGE_CMD <<< "${STAGES[$i]}"
    NUM=$((i + 1))
    echo -e "${BLUE}[$NUM/$TOTAL] RUNNING${NC} ${CYAN}$STAGE_DESC${NC}"

    START=$(date +%s)
    OUTPUT=$(bash -c "$STAGE_CMD" 2>&1)
    EXIT_CODE=$?
    DURATION=$(( $(date +%s) - START ))
    reap_orphan_browsers

    # Per-test counts, so the summary counts tests and not just stages.
    if [[ "$OUTPUT" =~ RESULT\ tests=([0-9]+)\ failed=([0-9]+)\ skipped=([0-9]+)\ errors=([0-9]+) ]]; then
        n=${BASH_REMATCH[1]}; f=$(( BASH_REMATCH[2] + BASH_REMATCH[4] )); s=${BASH_REMATCH[3]}
        TOTAL_TESTS=$((TOTAL_TESTS + n)); FAILED_TESTS=$((FAILED_TESTS + f))
        SKIPPED_TESTS=$((SKIPPED_TESTS + s)); PASSED_TESTS=$((PASSED_TESTS + n - f - s))
    fi
    if [[ "$STAGE_ID" == "playwright" ]]; then
        p=$(grep -oE '[0-9]+ passed' <<< "$OUTPUT" | tail -1 | grep -oE '[0-9]+'); p=${p:-0}
        f=$(grep -oE '[0-9]+ (failed|error)' <<< "$OUTPUT" | grep -oE '[0-9]+' | paste -sd+ | bc 2>/dev/null); f=${f:-0}
        s=$(grep -oE '[0-9]+ (skipped|xfailed)' <<< "$OUTPUT" | grep -oE '[0-9]+' | paste -sd+ | bc 2>/dev/null); s=${s:-0}
        TOTAL_TESTS=$((TOTAL_TESTS + p + f + s)); PASSED_TESTS=$((PASSED_TESTS + p))
        FAILED_TESTS=$((FAILED_TESTS + f)); SKIPPED_TESTS=$((SKIPPED_TESTS + s))
        [[ -f tests/playwright/coverage/summary.txt ]] && \
            JS_COVERAGE=$(grep -oE '[0-9.]+%' tests/playwright/coverage/summary.txt)
    fi
    if [[ "$OUTPUT" =~ RESULT\ r_coverage=([0-9.]+) ]]; then
        R_COVERAGE="${BASH_REMATCH[1]}%"
    fi

    {
        echo ""
        echo "### $NUM. $STAGE_DESC"
        echo ""
        echo '```'
        # testthat's progress dots make the report unreadable; keep the summary.
        grep -vE '^[a-z0-9-]+: [.SWE0-9]+$' <<< "$OUTPUT" | tail -n 120
        echo '```'
        echo "Duration: ${DURATION}s"
    } >> "$REPORT_FILE"

    if [[ $EXIT_CODE -eq 0 ]]; then
        echo -e "${GREEN}[$NUM/$TOTAL] PASS${NC} $STAGE_DESC (${DURATION}s)"
        echo "**Status: ✅ PASSED**" >> "$REPORT_FILE"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}[$NUM/$TOTAL] FAIL${NC} $STAGE_DESC (${DURATION}s, exit $EXIT_CODE)"
        echo "**Status: ❌ FAILED** (exit code $EXIT_CODE)" >> "$REPORT_FILE"
        FAILED=$((FAILED + 1))
        if [[ "$CONTINUE_ON_FAILURE" = false ]]; then
            SKIPPED=$((TOTAL - NUM))
            echo -e "${RED}Stopping. Use --continue to run every stage.${NC}"
            for j in $(seq $NUM $((TOTAL - 1))); do
                IFS='|' read -r _ D _ <<< "${STAGES[$j]}"
                echo -e "\n### $((j + 1)). $D\n\n**Status: ⚠️ NOT RUN** (an earlier stage failed)" >> "$REPORT_FILE"
            done
            break
        fi
    fi
    echo ""
done

TESTS_PASSED=$([ "$FAILED" -eq 0 ] && echo true || echo false)

cat >> "$REPORT_FILE" << EOF

---
## Summary

| Metric | Count |
|--------|-------|
| Stages | $TOTAL |
| Stages passed | $PASSED |
| Stages failed | $FAILED |
| Stages not run | $SKIPPED |
| Tests | $TOTAL_TESTS |
| Tests passed | $PASSED_TESTS |
| Tests failed | $FAILED_TESTS |
| Tests skipped | $SKIPPED_TESTS |
| R line coverage | ${R_COVERAGE:-not measured} |
| shinyFiles.js line coverage | ${JS_COVERAGE:-not measured} |

## Overall Status: $([ "$TESTS_PASSED" = true ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED")

---
*Report generated by scripts/run_tests.sh on $DATETIME*
*Run by: $USER_FULL_NAME ($USER_NAME)*
EOF

cat > "$STAGING_DIR/test_metadata.json" << EOF
{
    "date": "$DATE",
    "datetime": "$DATETIME",
    "run_by": "$USER_FULL_NAME",
    "run_by_username": "$USER_NAME",
    "run_by_email": "$USER_EMAIL",
    "git_hash": "$GIT_HASH",
    "git_hash_short": "$GIT_HASH_SHORT",
    "git_branch": "$GIT_BRANCH",
    "git_dirty": $([ "$GIT_DIRTY" = "yes" ] && echo true || echo false),
    "package_version": "$PKG_VERSION",
    "current_version": "$CURRENT_VERSION",
    "tests_passed": $TESTS_PASSED,
    "total_tests": $TOTAL_TESTS,
    "passed_tests": $PASSED_TESTS,
    "failed_tests": $FAILED_TESTS,
    "skipped_tests": $SKIPPED_TESTS,
    "r_coverage": "${R_COVERAGE}",
    "js_coverage": "${JS_COVERAGE}",
    "report_file": "TestReport.md"
}
EOF

echo -e "${GREEN}==============================================================================${NC}"
echo -e "Stages: $TOTAL  Passed: ${GREEN}$PASSED${NC}  Failed: ${RED}$FAILED${NC}  Not run: ${YELLOW}$SKIPPED${NC}"
echo -e "Tests: $TOTAL_TESTS  Passed: $PASSED_TESTS  Failed: $FAILED_TESTS  Skipped: $SKIPPED_TESTS"
echo -e "Coverage: R ${R_COVERAGE:-n/a}, shinyFiles.js ${JS_COVERAGE:-n/a}"
echo -e "${GREEN}Report: $REPORT_FILE${NC}"

[[ "$TESTS_PASSED" = true ]] || exit 1
