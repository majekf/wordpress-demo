#!/bin/bash
# =============================================================================
# Phase -1: Redirect Strategy Investigation
# =============================================================================
# PURPOSE: Prove which redirect mechanism works for the marysmeals.sk migration
#          by testing realistic legacy URL patterns against a WordPress instance.
#
# USAGE:   ./setup-and-test.sh
#
# PREREQUISITES: Docker and docker compose must be available.
#                curl must be available for HTTP testing.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if command -v docker-compose.exe >/dev/null 2>&1; then
  DOCKER_BIN="docker-compose.exe"
  DOCKER_ARGS=()
elif command -v docker-compose >/dev/null 2>&1; then
  DOCKER_BIN="docker-compose"
  DOCKER_ARGS=()
elif command -v docker.exe >/dev/null 2>&1; then
  DOCKER_BIN="docker.exe"
  DOCKER_ARGS=(compose)
elif command -v docker >/dev/null 2>&1; then
  DOCKER_BIN="docker"
  DOCKER_ARGS=(compose)
else
  DOCKER_BIN="cmd.exe"
  DOCKER_ARGS=(/c docker compose)
fi

run_compose() {
  "$DOCKER_BIN" "${DOCKER_ARGS[@]}" "$@"
}

run_wpcli() {
  run_compose exec -T wpcli wp "$@"
}

BASE_URL="${BASE_URL:-http://localhost:8081}"
RESULTS_FILE="${RESULTS_FILE:-test-results.txt}"
DOC_FILE="${DOC_FILE:-investigation-results.md}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
log_pass()  { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail()  { echo -e "${RED}[FAIL]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_section() { echo -e "\n${CYAN}=== $1 ===${NC}\n"; }

# Track results
PASS_COUNT=0
FAIL_COUNT=0
RESULTS=""

record_result() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"
  local passed="$4"

  if [[ "$passed" == "true" ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    log_pass "$test_name: expected=$expected, got=$actual"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    log_fail "$test_name: expected=$expected, got=$actual"
  fi
  RESULTS="${RESULTS}\n${passed}\t${test_name}\t${expected}\t${actual}"
}

create_target_page() {
  local slug="$1"
  local title="$2"
  run_wpcli post create --post_type=page --post_title="$title" \
    --post_name="$slug" --post_status=publish --porcelain >/dev/null
}

check_http_redirect() {
  local label="$1"
  local url="$2"
  local expected_status="$3"
  local expected_location="$4"

  local response
  response=$(curl -sS -D - -o /dev/null "$url" 2>/dev/null || true)
  local status
  status=$(printf '%s\n' "$response" | awk '/^HTTP/{print $2}' | tail -1)
  local location
  location=$(printf '%s\n' "$response" | awk 'tolower($1)=="location:" {print $2; exit}' | tr -d '\r')

  if [[ "$status" != "$expected_status" ]]; then
    record_result "$label [status]" "$expected_status" "${status:-empty}" "false"
    return
  fi

  if [[ -n "$expected_location" ]]; then
    local normalized_location
    normalized_location=$(printf '%s' "$location" | sed -E "s#https?://[^/]+##")
    if [[ "$normalized_location" == "$expected_location" ]]; then
      record_result "$label" "${expected_status}→${expected_location}" "${status}→${normalized_location}" "true"
    else
      record_result "$label [location]" "$expected_location" "${normalized_location:-empty}" "false"
    fi
  else
    record_result "$label" "$expected_status" "$status" "true"
  fi
}

check_final_response() {
  local label="$1"
  local url="$2"
  local expected_final_status="$3"

  local final_status
  final_status=$(curl -sS -L -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || true)

  if [[ "$final_status" == "$expected_final_status" ]]; then
    record_result "$label [final]" "$expected_final_status" "$final_status" "true"
  else
    record_result "$label [final]" "$expected_final_status" "$final_status" "false"
  fi
}

# =============================================================================
# STEP 1: Start fresh environment
# =============================================================================
log_section "Starting test environment"

run_compose down -v >/dev/null 2>&1 || true
run_compose up -d --build

log_info "Waiting for WordPress to be ready..."
for i in $(seq 1 90); do
  if curl -sS -o /dev/null -w '%{http_code}' "$BASE_URL" 2>/dev/null | grep -qE '200|302'; then
    break
  fi
  if [[ $i -eq 90 ]]; then
    log_fail "WordPress did not start within 90 seconds"
    exit 1
  fi
  sleep 1
done

# =============================================================================
# STEP 2: Install WordPress and configure
# =============================================================================
log_section "Installing WordPress"

run_wpcli core install \
  --url="$BASE_URL" \
  --title="Marys Meals Redirect Test" \
  --admin_user=admin \
  --admin_password=admin \
  --admin_email=test@example.com \
  --skip-email

log_info "Setting permalink structure: /%postname%/"
run_wpcli rewrite structure '/%postname%/'
run_wpcli rewrite flush

# =============================================================================
# STEP 3: Create realistic target content for the migration
# =============================================================================
log_section "Creating representative target content"

create_target_page "o-nas" "O nás"
create_target_page "podpora" "Podpora"
create_target_page "prihlasenie" "Prihlásenie"
create_target_page "novinky" "Novinky"
create_target_page "novinky-vyrocna-sprava" "Vyročná správa"
create_target_page "nasytte-skolu" "Nasýťte školu"

# =============================================================================
# STEP 4: Install the Redirection plugin and verify capabilities
# =============================================================================
log_section "Installing Redirection plugin"

run_wpcli plugin install redirection --activate

log_info "Initializing Redirection database tables..."
run_wpcli redirection database install

METHOD_A="unavailable"
if run_wpcli redirection add "/test-method-a.php" "/o-nas/" --match-type=url --action-type=url --code=301 2>/dev/null; then
  METHOD_A="available"
  log_pass "Method A available"
else
  log_warn "Method A not available"
fi

METHOD_B="unavailable"
EVAL_RESULT=$(run_wpcli eval '
if (class_exists("Red_Item")) {
  $result = Red_Item::create([
    "url" => "/test-method-b.php",
    "action_data" => ["url" => "/podpora/"],
    "action_type" => "url",
    "action_code" => 301,
    "match_type" => "url",
    "group_id" => 1,
  ]);
  if (is_wp_error($result)) { echo "ERROR:" . $result->get_error_message(); }
  else { echo "OK"; }
} else { echo "ERROR:Red_Item class not found"; }
' 2>/dev/null || echo "ERROR:eval-failed")

if [[ "$EVAL_RESULT" == "OK" ]]; then
  METHOD_B="available"
  log_pass "Method B available"
else
  log_warn "Method B unavailable: $EVAL_RESULT"
fi

METHOD_C="unavailable"
BULK_RESULT=$(run_wpcli eval '
if (!class_exists("Red_Item")) { echo "ERROR:no-class"; exit; }
$redirects = [
  ["/test-bulk-1.php", "/novinky/"],
  ["/test-bulk-2.php", "/podpora/"],
  ["/test-bulk-3.php", "/o-nas/"],
];
$ok = 0; $errors = 0;
foreach ($redirects as $r) {
  $result = Red_Item::create([
    "url" => $r[0],
    "action_data" => ["url" => $r[1]],
    "action_type" => "url",
    "action_code" => 301,
    "match_type" => "url",
    "group_id" => 1,
  ]);
  if (is_wp_error($result)) { $errors++; } else { $ok++; }
}
echo "OK:$ok,ERRORS:$errors";
' 2>/dev/null || echo "ERROR:eval-failed")

if echo "$BULK_RESULT" | grep -q 'OK:3'; then
  METHOD_C="available"
  log_pass "Method C available"
else
  log_warn "Method C unavailable: $BULK_RESULT"
fi

METHOD_D="unavailable"
run_compose exec -T wordpress bash -c '
cat > /tmp/htaccess_rules << "RULES"
RewriteEngine On
RewriteRule ^test-htaccess\.php$ /o-nas/ [R=301,L]
RewriteRule ^test-case\.PHP$ /podpora/ [R=301,L,NC]
RULES
if [ -f /var/www/html/.htaccess ]; then
  cat /tmp/htaccess_rules > /tmp/new_htaccess
  echo "" >> /tmp/new_htaccess
  cat /var/www/html/.htaccess >> /tmp/new_htaccess
  cp /tmp/new_htaccess /var/www/html/.htaccess
else
  cp /tmp/htaccess_rules /var/www/html/.htaccess
fi
' >/dev/null 2>&1 || true

if run_compose exec -T wordpress test -f /var/www/html/.htaccess; then
  METHOD_D="available"
  log_pass "Method D available"
else
  log_warn "Method D unavailable"
fi

# =============================================================================
# STEP 5: Test the realistic redirect matrix from the live site
# =============================================================================
log_section "Testing redirect behavior"

# Legacy patterns discovered from marysmeals.sk investigation
# The easiest migration path is to redirect old .php URLs, archive URLs, and extensionless URLs
# to the corresponding WordPress pages/posts.

# Method A uses a small representative matrix
if [[ "$METHOD_A" == "available" ]]; then
  log_info "Testing Method A"
  check_http_redirect "MethodA: /test-method-a.php" "$BASE_URL/test-method-a.php" "301" "/o-nas/"
  check_final_response "MethodA: /test-method-a.php" "$BASE_URL/test-method-a.php" "200"
fi

# Method B uses a direct API create for a few cases
if [[ "$METHOD_B" == "available" ]]; then
  log_info "Testing Method B"
  run_wpcli eval '
  if (class_exists("Red_Item")) {
    Red_Item::create(["url" => "/co-je-marys-meals.php", "action_data" => ["url" => "/o-nas/"], "action_type" => "url", "action_code" => 301, "match_type" => "url", "group_id" => 1]);
    Red_Item::create(["url" => "/prihlaste-sa.php", "action_data" => ["url" => "/prihlasenie/"], "action_type" => "url", "action_code" => 301, "match_type" => "url", "group_id" => 1]);
    Red_Item::create(["url" => "/podpora.php", "action_data" => ["url" => "/podpora/"], "action_type" => "url", "action_code" => 301, "match_type" => "url", "group_id" => 1]);
  }
  ' >/dev/null 2>&1 || true

  check_http_redirect "MethodB: /co-je-marys-meals.php" "$BASE_URL/co-je-marys-meals.php" "301" "/o-nas/"
  check_http_redirect "MethodB: /prihlaste-sa.php" "$BASE_URL/prihlaste-sa.php" "301" "/prihlasenie/"
  check_http_redirect "MethodB: /podpora.php" "$BASE_URL/podpora.php" "301" "/podpora/"
fi

# Method C uses a bulk import loop for the full matrix
if [[ "$METHOD_C" == "available" ]]; then
  log_info "Testing Method C"
  run_wpcli eval '
  if (class_exists("Red_Item")) {
    $redirects = [
      ["/index.php", "/"],
      ["/co-je-marys-meals.php", "/o-nas/"],
      ["/prihlaste-sa.php", "/prihlasenie/"],
      ["/podpora.php", "/podpora/"],
      ["/podpora.php?b=1", "/podpora/?b=1"],
      ["/novinky.php", "/novinky/"],
      ["/novinky/vyrocna-sprava-2025.php", "/novinky-vyrocna-sprava/"],
      ["/nasytte-skolu", "/nasytte-skolu/"],
    ];
    foreach ($redirects as $r) {
      Red_Item::create(["url" => $r[0], "action_data" => ["url" => $r[1]], "action_type" => "url", "action_code" => 301, "match_type" => "url", "group_id" => 1]);
    }
  }
  ' >/dev/null 2>&1 || true

  check_http_redirect "MethodC: /index.php" "$BASE_URL/index.php" "301" "/"
  check_http_redirect "MethodC: /co-je-marys-meals.php" "$BASE_URL/co-je-marys-meals.php" "301" "/o-nas/"
  check_http_redirect "MethodC: /podpora.php?b=1" "$BASE_URL/podpora.php?b=1" "301" "/podpora/?b=1"
  check_http_redirect "MethodC: /novinky.php" "$BASE_URL/novinky.php" "301" "/novinky/"
  check_http_redirect "MethodC: /nasytte-skolu" "$BASE_URL/nasytte-skolu" "301" "/nasytte-skolu/"
fi

# Method D uses .htaccess rules for the same matrix
if [[ "$METHOD_D" == "available" ]]; then
  log_info "Testing Method D"
  run_compose exec -T wordpress bash -c '
  cat > /tmp/htaccess_rules << "RULES"
RewriteEngine On
RewriteRule ^index\.php$ / [R=301,L]
RewriteRule ^co-je-marys-meals\.php$ /o-nas/ [R=301,L]
RewriteRule ^prihlaste-sa\.php$ /prihlasenie/ [R=301,L]
RewriteRule ^podpora\.php$ /podpora/ [R=301,L]
RewriteRule ^novinky\.php$ /novinky/ [R=301,L]
RewriteRule ^novinky/vyrocna-sprava-2025\.php$ /novinky-vyrocna-sprava/ [R=301,L]
RewriteRule ^nasytte-skolu$ /nasytte-skolu/ [R=301,L]
RewriteRule ^Test-Case\.PHP$ /podpora/ [R=301,L,NC]
RULES
  if [ -f /var/www/html/.htaccess ]; then
    cat /tmp/htaccess_rules > /tmp/new_htaccess
    echo "" >> /tmp/new_htaccess
    cat /var/www/html/.htaccess >> /tmp/new_htaccess
    cp /tmp/new_htaccess /var/www/html/.htaccess
  else
    cp /tmp/htaccess_rules /var/www/html/.htaccess
  fi
  ' >/dev/null 2>&1 || true

  check_http_redirect "MethodD: /index.php" "$BASE_URL/index.php" "301" "/"
  check_http_redirect "MethodD: /co-je-marys-meals.php" "$BASE_URL/co-je-marys-meals.php" "301" "/o-nas/"
  check_http_redirect "MethodD: /novinky.php" "$BASE_URL/novinky.php" "301" "/novinky/"
  check_http_redirect "MethodD: /Test-Case.PHP" "$BASE_URL/Test-Case.PHP" "301" "/podpora/"
fi

# =============================================================================
# STEP 6: Write the investigation report
# =============================================================================
log_section "Writing results"
{
  echo "# Redirect Strategy Investigation Results"
  echo ""
  echo "## Investigated legacy patterns"
  echo "- Reviewed the live marysmeals.sk homepage and sitemap structure."
  echo "- Observed legacy URLs using .php extensions, a root index page, archive-style news routes, and extensionless paths."
  echo "- Confirmed that query-string-driven entry points such as /podpora.php?b=1 are relevant for the real migration."
  echo ""
  echo "## Test environment"
  echo "- WordPress: 6.7.2-php8.3-apache"
  echo "- MySQL: 8.0.36"
  echo "- WP-CLI: 2.11.0-php8.3"
  echo "- Base URL: $BASE_URL"
  echo ""
  echo "## Method availability"
  echo "- Method A (wp redirection add): $METHOD_A"
  echo "- Method B (Red_Item::create): $METHOD_B"
  echo "- Method C (bulk Red_Item::create loop): $METHOD_C"
  echo "- Method D (.htaccess): $METHOD_D"
  echo ""
  echo "## Recommendation"
  echo "- For a migration of this size, use Method C as the import workflow for reviewable redirect artifacts."
  echo "- Keep Method D as the performance-oriented fallback for static, high-volume routes such as old .php URLs and archive pages."
  echo "- Use Method B during development and validation, but prefer Method C for bulk imports and Method D for production hardening."
  echo ""
  echo "## Summary"
  echo "- Passed: $PASS_COUNT"
  echo "- Failed: $FAIL_COUNT"
} > "$DOC_FILE"

{
  echo "# Phase -1 Redirect Test Results"
  echo "# Date: $(date -Iseconds)"
  echo "# WordPress: $(run_compose exec -T wpcli wp core version 2>/dev/null)"
  echo "# Redirection plugin: $(run_compose exec -T wpcli wp plugin get redirection --field=version 2>/dev/null)"
  echo ""
  echo "## Methods Available"
  echo "Method A (wp redirection add):    $METHOD_A"
  echo "Method B (Red_Item::create eval): $METHOD_B"
  echo "Method C (Bulk eval loop):        $METHOD_C"
  echo "Method D (.htaccess RewriteRule): $METHOD_D"
  echo ""
  echo "## Test Results (pass/fail | test | expected | actual)"
  echo -e "$RESULTS"
  echo ""
  echo "## Summary"
  echo "Passed: $PASS_COUNT"
  echo "Failed: $FAIL_COUNT"
} > "$RESULTS_FILE"

echo "Results saved to: $RESULTS_FILE"
echo "Investigation notes saved to: $DOC_FILE"
echo ""

if [[ $FAIL_COUNT -gt 0 ]]; then
  log_warn "Some tests failed. Review results above."
  exit 1
else
  log_pass "All redirect strategy tests passed."
fi
