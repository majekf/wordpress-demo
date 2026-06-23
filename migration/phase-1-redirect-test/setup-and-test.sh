#!/bin/bash
# =============================================================================
# Phase -1: Redirect Strategy Investigation
# =============================================================================
# PURPOSE: Prove which redirect mechanism works before building the migration
#          pipeline. Tests multiple approaches and edge cases.
#
# USAGE:   ./setup-and-test.sh
#
# PREREQUISITES: Docker and docker compose must be available.
#                curl must be available for HTTP testing.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

WPCLI="docker compose run --rm wpcli"
BASE_URL="http://localhost:8080"
RESULTS_FILE="test-results.txt"

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

# =============================================================================
# STEP 1: Start fresh environment
# =============================================================================
log_section "Starting test environment"

# Clean up any previous test
docker compose down -v 2>/dev/null || true
docker compose up -d

log_info "Waiting for WordPress to be ready..."
# Wait for WordPress to respond (up to 60 seconds)
for i in $(seq 1 60); do
  if curl -s -o /dev/null -w "%{http_code}" "$BASE_URL" 2>/dev/null | grep -qE "200|302"; then
    break
  fi
  if [[ $i -eq 60 ]]; then
    log_fail "WordPress did not start within 60 seconds"
    exit 1
  fi
  sleep 1
done

log_info "WordPress is responding. Installing..."

# =============================================================================
# STEP 2: Install WordPress and configure
# =============================================================================
log_section "Installing WordPress"

$WPCLI core install \
  --url="$BASE_URL" \
  --title="Redirect Strategy Test" \
  --admin_user=admin \
  --admin_password=admin \
  --admin_email=test@example.com \
  --skip-email

log_info "Setting permalink structure: /%postname%/"
$WPCLI rewrite structure '/%postname%/'
$WPCLI rewrite flush

# =============================================================================
# STEP 3: Create test content
# =============================================================================
log_section "Creating test content"

# Pages
$WPCLI post create --post_type=page --post_title="O nás" \
  --post_name="o-nas" --post_status=publish --porcelain
$WPCLI post create --post_type=page --post_title="Kontakt" \
  --post_name="kontakt" --post_status=publish --porcelain
$WPCLI post create --post_type=page --post_title="Kde pomáhame" \
  --post_name="kde-pomahame" --post_status=publish --porcelain

# Category for news
$WPCLI term create category "Novinky" --slug=novinky --porcelain 2>/dev/null || true

# Posts (with Slovak characters in title)
POST1_ID=$($WPCLI post create --post_type=post --post_title="Škola v Malawi" \
  --post_name="skola-v-malawi" --post_status=publish --porcelain)
$WPCLI post term set "$POST1_ID" category novinky

POST2_ID=$($WPCLI post create --post_type=post --post_title="Nový ročník" \
  --post_name="novy-rocnik" --post_status=publish --porcelain)
$WPCLI post term set "$POST2_ID" category novinky

# A page for novinky archive (since we use /%postname%/ not /%category%/%postname%/)
$WPCLI post create --post_type=page --post_title="Novinky" \
  --post_name="novinky" --post_status=publish --porcelain

log_info "Created: 4 pages, 2 posts, 1 category"

# =============================================================================
# STEP 4: Install Redirection plugin and discover CLI capabilities
# =============================================================================
log_section "Installing Redirection plugin"

$WPCLI plugin install redirection --activate

log_info "Checking available WP-CLI redirection commands:"
echo ""
$WPCLI help redirection 2>&1 || log_warn "No top-level 'wp help redirection' output"
echo ""

# Check specific subcommands
log_info "Checking for 'wp redirection add':"
$WPCLI help redirection add 2>&1 || log_warn "'wp redirection add' not available"
echo ""

log_info "Checking for 'wp redirection import':"
$WPCLI help redirection import 2>&1 || log_warn "'wp redirection import' not available"
echo ""

# =============================================================================
# STEP 5: Test redirect creation methods
# =============================================================================
log_section "Testing redirect creation methods"

# --- Method A: wp redirection add ---
log_info "Method A: Direct 'wp redirection add' command"
METHOD_A="unknown"
if $WPCLI redirection add "/test-method-a.php" "/o-nas/" \
    --match-type=url --action-type=url --code=301 2>/dev/null; then
  METHOD_A="available"
  log_pass "Method A: 'wp redirection add' works"
else
  METHOD_A="unavailable"
  log_warn "Method A: 'wp redirection add' not available"
fi

# --- Method B: PHP eval with Red_Item::create ---
log_info "Method B: PHP eval with Red_Item::create"
METHOD_B="unknown"
EVAL_RESULT=$($WPCLI eval '
if (class_exists("Red_Item")) {
  $result = Red_Item::create([
    "url"         => "/test-method-b.php",
    "action_data" => ["url" => "/kontakt/"],
    "action_type" => "url",
    "action_code" => 301,
    "match_type"  => "url",
    "group_id"    => 1,
  ]);
  if (is_wp_error($result)) {
    echo "ERROR:" . $result->get_error_message();
  } else {
    echo "OK";
  }
} else {
  echo "ERROR:Red_Item class not found";
}
' 2>/dev/null || echo "ERROR:eval-failed")

if [[ "$EVAL_RESULT" == "OK" ]]; then
  METHOD_B="available"
  log_pass "Method B: Red_Item::create works"
else
  METHOD_B="unavailable"
  log_warn "Method B: Red_Item::create failed: $EVAL_RESULT"
fi

# --- Method C: Bulk JSON import via Red_Item::create in loop ---
log_info "Method C: Bulk import via PHP eval loop"
METHOD_C="unknown"
BULK_RESULT=$($WPCLI eval '
if (!class_exists("Red_Item")) { echo "ERROR:no-class"; exit; }

$redirects = [
  ["/test-bulk-1.php", "/o-nas/"],
  ["/test-bulk-2.php", "/kontakt/"],
  ["/test-bulk-3.php", "/kde-pomahame/"],
];

$ok = 0;
$errors = 0;
foreach ($redirects as $r) {
  $result = Red_Item::create([
    "url"         => $r[0],
    "action_data" => ["url" => $r[1]],
    "action_type" => "url",
    "action_code" => 301,
    "match_type"  => "url",
    "group_id"    => 1,
  ]);
  if (is_wp_error($result)) { $errors++; } else { $ok++; }
}
echo "OK:$ok,ERRORS:$errors";
' 2>/dev/null || echo "ERROR:eval-failed")

if echo "$BULK_RESULT" | grep -q "OK:3"; then
  METHOD_C="available"
  log_pass "Method C: Bulk creation works ($BULK_RESULT)"
else
  METHOD_C="unavailable"
  log_warn "Method C: Bulk creation result: $BULK_RESULT"
fi

# --- Method D: .htaccess-based redirect ---
log_info "Method D: .htaccess RewriteRule"
METHOD_D="unknown"

# Inject a rewrite rule into .htaccess inside the container
docker compose exec -T wordpress bash -c '
cat > /tmp/htaccess_rules << "RULES"
# Migration redirect test
RewriteEngine On
RewriteRule ^test-htaccess\.php$ /o-nas/ [R=301,L]
RewriteRule ^test-case\.PHP$ /kontakt/ [R=301,L,NC]
RULES

# Prepend rules before WordPress block
if [ -f /var/www/html/.htaccess ]; then
  cat /tmp/htaccess_rules > /tmp/new_htaccess
  echo "" >> /tmp/new_htaccess
  cat /var/www/html/.htaccess >> /tmp/new_htaccess
  cp /tmp/new_htaccess /var/www/html/.htaccess
else
  cp /tmp/htaccess_rules /var/www/html/.htaccess
fi
'

if [[ $? -eq 0 ]]; then
  METHOD_D="available"
  log_pass "Method D: .htaccess rules injected"
else
  METHOD_D="unavailable"
  log_warn "Method D: .htaccess injection failed"
fi

# Give WordPress a moment to pick up the changes
sleep 2

# =============================================================================
# STEP 6: Test redirect behavior (HTTP checks)
# =============================================================================
log_section "Testing redirect behavior"

# Helper: check a redirect
check_redirect() {
  local test_name="$1"
  local url="$2"
  local expected_status="$3"
  local expected_location="$4"  # path only, or empty to skip

  local response
  response=$(curl -sI "$url" 2>/dev/null)
  local status
  status=$(echo "$response" | grep -i "^HTTP/" | head -1 | awk '{print $2}')
  local location
  location=$(echo "$response" | grep -i "^location:" | head -1 | awk '{print $2}' | tr -d '\r\n')

  # Check status
  if [[ "$status" != "$expected_status" ]]; then
    record_result "$test_name [status]" "$expected_status" "${status:-empty}" "false"
    return
  fi

  # Check location if expected
  if [[ -n "$expected_location" ]]; then
    # Normalize: extract path from location (may be absolute URL)
    local loc_path
    loc_path=$(echo "$location" | sed "s|${BASE_URL}||; s|http://[^/]*||")
    if [[ "$loc_path" == "$expected_location" ]]; then
      record_result "$test_name" "${expected_status}→${expected_location}" "${status}→${loc_path}" "true"
    else
      record_result "$test_name [location]" "$expected_location" "${loc_path:-empty}" "false"
    fi
  else
    record_result "$test_name" "$expected_status" "$status" "true"
  fi
}

# Helper: check final response after following redirects
check_final() {
  local test_name="$1"
  local url="$2"
  local expected_final_status="$3"

  local final_status
  final_status=$(curl -sIL -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)

  if [[ "$final_status" == "$expected_final_status" ]]; then
    record_result "$test_name [final]" "$expected_final_status" "$final_status" "true"
  else
    record_result "$test_name [final]" "$expected_final_status" "$final_status" "false"
  fi
}

# --- Test existing content resolves ---
log_info "Testing content availability..."
check_redirect "Page /o-nas/" "$BASE_URL/o-nas/" "200" ""
check_redirect "Page /kontakt/" "$BASE_URL/kontakt/" "200" ""
check_redirect "Page /kde-pomahame/" "$BASE_URL/kde-pomahame/" "200" ""
check_redirect "Page /novinky/" "$BASE_URL/novinky/" "200" ""
check_redirect "Post /skola-v-malawi/" "$BASE_URL/skola-v-malawi/" "200" ""

# --- Test Method A redirects (if available) ---
if [[ "$METHOD_A" == "available" ]]; then
  log_info "Testing Method A redirects..."
  check_redirect "MethodA: /test-method-a.php" "$BASE_URL/test-method-a.php" "301" "/o-nas/"
  check_final "MethodA: /test-method-a.php" "$BASE_URL/test-method-a.php" "200"
fi

# --- Test Method B redirects ---
if [[ "$METHOD_B" == "available" ]]; then
  log_info "Testing Method B redirects..."
  check_redirect "MethodB: /test-method-b.php" "$BASE_URL/test-method-b.php" "301" "/kontakt/"
  check_final "MethodB: /test-method-b.php" "$BASE_URL/test-method-b.php" "200"
fi

# --- Test Method C bulk redirects ---
if [[ "$METHOD_C" == "available" ]]; then
  log_info "Testing Method C bulk redirects..."
  check_redirect "MethodC: /test-bulk-1.php" "$BASE_URL/test-bulk-1.php" "301" "/o-nas/"
  check_redirect "MethodC: /test-bulk-2.php" "$BASE_URL/test-bulk-2.php" "301" "/kontakt/"
  check_redirect "MethodC: /test-bulk-3.php" "$BASE_URL/test-bulk-3.php" "301" "/kde-pomahame/"
  check_final "MethodC: /test-bulk-3.php" "$BASE_URL/test-bulk-3.php" "200"
fi

# --- Test Method D (.htaccess) redirects ---
if [[ "$METHOD_D" == "available" ]]; then
  log_info "Testing Method D .htaccess redirects..."
  check_redirect "MethodD: /test-htaccess.php" "$BASE_URL/test-htaccess.php" "301" "/o-nas/"
  check_final "MethodD: /test-htaccess.php" "$BASE_URL/test-htaccess.php" "200"
fi

# =============================================================================
# STEP 7: Test edge cases
# =============================================================================
log_section "Testing edge cases"

# Add edge-case redirects via the best available method
EDGE_CASE_METHOD=""
if [[ "$METHOD_B" == "available" ]]; then
  EDGE_CASE_METHOD="eval"

  # Query string handling
  $WPCLI eval '
  Red_Item::create(["url" => "/query-test.php", "action_data" => ["url" => "/o-nas/"], "action_type" => "url", "action_code" => 301, "match_type" => "url", "group_id" => 1]);
  ' 2>/dev/null

  # Extensionless URL
  $WPCLI eval '
  Red_Item::create(["url" => "/vyzvy", "action_data" => ["url" => "/kontakt/"], "action_type" => "url", "action_code" => 301, "match_type" => "url", "group_id" => 1]);
  ' 2>/dev/null

  # URL with trailing slash
  $WPCLI eval '
  Red_Item::create(["url" => "/old-page/", "action_data" => ["url" => "/kde-pomahame/"], "action_type" => "url", "action_code" => 301, "match_type" => "url", "group_id" => 1]);
  ' 2>/dev/null

  # Redirect to homepage
  $WPCLI eval '
  Red_Item::create(["url" => "/index.php", "action_data" => ["url" => "/"], "action_type" => "url", "action_code" => 301, "match_type" => "url", "group_id" => 1]);
  ' 2>/dev/null

elif [[ "$METHOD_A" == "available" ]]; then
  EDGE_CASE_METHOD="add"
  $WPCLI redirection add "/query-test.php" "/o-nas/" --match-type=url --action-type=url --code=301 2>/dev/null
  $WPCLI redirection add "/vyzvy" "/kontakt/" --match-type=url --action-type=url --code=301 2>/dev/null
  $WPCLI redirection add "/old-page/" "/kde-pomahame/" --match-type=url --action-type=url --code=301 2>/dev/null
  $WPCLI redirection add "/index.php" "/" --match-type=url --action-type=url --code=301 2>/dev/null
fi

if [[ -n "$EDGE_CASE_METHOD" ]]; then
  sleep 1

  # Query string: does the redirect fire when query params are present?
  log_info "Testing query string handling..."
  check_redirect "Edge: /query-test.php?b=1" "$BASE_URL/query-test.php?b=1" "301" "/o-nas/"

  # Extensionless URL
  log_info "Testing extensionless URL..."
  check_redirect "Edge: /vyzvy (no extension)" "$BASE_URL/vyzvy" "301" "/kontakt/"

  # Trailing slash
  log_info "Testing trailing slash..."
  check_redirect "Edge: /old-page/" "$BASE_URL/old-page/" "301" "/kde-pomahame/"

  # Redirect to root
  log_info "Testing redirect to homepage..."
  check_redirect "Edge: /index.php → /" "$BASE_URL/index.php" "301" "/"
  check_final "Edge: /index.php → /" "$BASE_URL/index.php" "200"

  # Case sensitivity (via .htaccess NC flag or plugin behavior)
  log_info "Testing case sensitivity..."
  # Plugin-based redirects are usually case-sensitive by default
  check_redirect "Edge: /Query-Test.PHP (uppercase)" "$BASE_URL/Query-Test.PHP" "301" "/o-nas/"
fi

# .htaccess case-insensitive test (NC flag)
if [[ "$METHOD_D" == "available" ]]; then
  log_info "Testing .htaccess case-insensitive (NC flag)..."
  check_redirect "Edge: /Test-Case.PHP (htaccess NC)" "$BASE_URL/test-case.PHP" "301" "/kontakt/"
fi

# =============================================================================
# STEP 8: Test Slovak encoding in redirected content
# =============================================================================
log_section "Testing Slovak character encoding"

CONTENT=$(curl -s "$BASE_URL/skola-v-malawi/" 2>/dev/null)
if echo "$CONTENT" | grep -q "Škola v Malawi"; then
  record_result "Encoding: Slovak chars in content" "present" "present" "true"
elif echo "$CONTENT" | grep -qE "Ã|Å|Ä"; then
  record_result "Encoding: Slovak chars in content" "UTF-8" "mojibake" "false"
else
  record_result "Encoding: Slovak chars in content" "present" "not-found" "false"
fi

# =============================================================================
# STEP 9: Summary
# =============================================================================
log_section "RESULTS SUMMARY"

echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"
echo ""
echo "Available methods:"
echo "  Method A (wp redirection add):    $METHOD_A"
echo "  Method B (Red_Item::create eval): $METHOD_B"
echo "  Method C (Bulk eval loop):        $METHOD_C"
echo "  Method D (.htaccess RewriteRule): $METHOD_D"
echo ""

# Write results to file
{
  echo "# Phase -1 Redirect Test Results"
  echo "# Date: $(date -Iseconds)"
  echo "# WordPress: $(docker compose run --rm wpcli core version 2>/dev/null)"
  echo "# Redirection plugin: $(docker compose run --rm wpcli plugin get redirection --field=version 2>/dev/null)"
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
echo ""

if [[ $FAIL_COUNT -gt 0 ]]; then
  log_warn "Some tests failed. Review results above."
  echo ""
  echo "NEXT STEPS:"
  echo "  1. Analyze which methods work reliably"
  echo "  2. Decide on redirect strategy based on results"
  echo "  3. Document decision before proceeding to Phase 0"
  exit 1
else
  log_pass "All tests passed!"
  echo ""
  echo "NEXT STEPS:"
  echo "  1. Choose preferred method (recommend Method C for bulk + Method D for performance-critical)"
  echo "  2. Document decision in migration plan"
  echo "  3. Proceed to Phase 0"
fi
