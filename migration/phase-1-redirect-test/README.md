# Phase -1: Redirect Strategy Investigation

## Purpose

Before building the full migration pipeline for marysmeals.sk, we need to **prove** which redirect mechanism works reliably with our WordPress + Redirection plugin stack.

This test environment creates a minimal WordPress instance, installs the Redirection plugin, and tests **four different redirect creation methods** plus edge cases.

## Quick Start

```bash
# Run the full test suite (starts Docker, tests, reports)
./setup-and-test.sh

# When done, clean up
./teardown.sh
```

## What Gets Tested

### Redirect Creation Methods

| Method | How | Use case |
|--------|-----|----------|
| A | `wp redirection add` CLI command | Simple, if available |
| B | `wp eval` with `Red_Item::create` | Direct PHP API |
| C | Bulk `Red_Item::create` in loop | Scalable import |
| D | `.htaccess` RewriteRule | Server-level, fastest |

### Edge Cases

| Test | Why it matters |
|------|----------------|
| Query string passthrough | `/page.php?b=1` must still redirect |
| Extensionless URLs | `/vyzvy` (no `.php`) must work |
| Trailing slash | `/old-page/` behavior |
| Redirect to root | `/index.php` → `/` |
| Case sensitivity | `/Page.PHP` vs `/page.php` |
| Slovak encoding | Characters like ľščťžýáí must survive |

## Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Test environment (WP 6.7.2 + MySQL 8.0.36 + WP-CLI) |
| `setup-and-test.sh` | Main test script — runs everything |
| `teardown.sh` | Clean up containers and volumes |
| `test-results.txt` | Generated after test run — commit this |

## Decision Criteria

After running the tests, choose a redirect strategy:

| Criteria | Plugin (B/C) | .htaccess (D) | Hybrid |
|----------|--------------|----------------|--------|
| Speed | Slower (PHP bootstrap) | Fast (Apache) | Best of both |
| Manageability | UI + 404 monitoring | Manual file | UI for monitoring |
| Bulk import | Yes (eval loop) | Generate file | Both |
| Case handling | Configurable | NC flag | Both |
| Query strings | Plugin handles | Must configure | Both |

**Recommendation:** Use Method C (bulk eval) for import, keep plugin active for 404 monitoring. Use .htaccess only if performance testing shows PHP-level redirects are too slow.

## Prerequisites

- Docker and docker compose
- curl
- bash
- Port 8080 available
