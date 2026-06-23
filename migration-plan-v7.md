# marysmeals.sk → WordPress Migration Plan v7

## v7 Changes Summary

| Issue from v6 Review | Fix Applied |
|---------------------|-------------|
| Hand-authored inventory is stale/wrong | Crawl-first discovery; inventory generated from live site |
| `wp redirection add` may not exist | Redirect artifact file + bulk import; verify CLI in Phase -1 |
| `/%category%/%postname%/` is fragile | Switched to `/%postname%/` + archive page |
| Media import path broken (host vs container) | `wp media import URL` directly (sideload from source) |
| Importer not idempotent | `_legacy_url` meta + update-on-rerun logic |
| `((FAIL++))` breaks under `set -e` | Changed to `FAIL=$((FAIL + 1))` |
| Validation doesn't check Location header | Added exact target assertion |
| Crawler misses publish dates | Added date extraction from page content |
| Regex link rewriting dangerous | Inventory-based URL mapping |
| No package.json / Node 18 EOL | Added package.json, tsx, Node 22 LTS |
| One-redirect-per-CLI-call is slow | Bulk redirect map as reviewable artifact |
| News archive at `/novinky.php` not `/novinky/` | Fixed; archive URL from live crawl |
| Acceptance criteria hardcoded | Derived from inventory counts |
| No rollback/delta plan | Added to launch readiness |
| No production architecture | Noted as separate concern; local plan is for content migration |

---

## Architecture Overview

### Pipeline Phases

```
Phase -1: Redirect Strategy Investigation (BLOCKING)
Phase 0:  Infrastructure (Docker + Node project)
Phase 1:  Discovery & Audit → legacy_inventory.tsv
Phase 2:  Crawl → raw-export.json
Phase 3:  Media Import (sideload from URLs)
Phase 4:  Clean HTML (inventory-based link rewriting)
Phase 5:  Content Import (idempotent, with dates)
Phase 6:  Menus + Navigation
Phase 7:  Redirects (bulk artifact import)
Phase 8:  Validation (exact target checks)
Phase 9:  Launch Readiness
```

### Key Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Import mechanism | Node.js with stdin | Shell arguments break on long HTML |
| Permalink model | `/%postname%/` | Stable URLs; no category-slug coupling |
| News archive | `/novinky/` as posts page or category page | Decoupled from permalink structure |
| Media import | `wp media import <URL>` (sideload) | No host↔container path issues |
| Idempotency | `_legacy_url` post meta as unique key | Safe reruns; update instead of duplicate |
| Link rewriting | Inventory-based URL map | No regex guesses on `.php` → `/slug/` |
| Redirects | JSON artifact → bulk import | Reviewable, auditable, fast |
| Inventory source | Live crawl + manual audit | Not hand-authored guesses |

### Stack Versions (Pinned)

| Component | Version | Reason |
|-----------|---------|--------|
| WordPress | 6.7.2-php8.3-apache | Latest stable at time of writing |
| MySQL | 8.0.36 | UTF-8 with `utf8mb4_unicode_ci` |
| WP-CLI | 2.11.0-php8.3 | Verify `wp help redirection` in Phase -1 |
| Node.js | 22-bookworm-slim | Active LTS; Playwright compatible |
| Crawlee | 3.17.0 | Playwright integration |
| tsx | latest | TypeScript execution without compile step |

---

## Phase -1: Redirect Strategy Investigation (BLOCKING)

**Status:** IMPLEMENTED — scripts in repository at `migration/phase-1-redirect-test/`

**Goal:** Prove the redirect mechanism works BEFORE building the pipeline.

### Implementation

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Isolated test env (WP 6.7.2 + MySQL 8.0.36 + WP-CLI 2.11.0) |
| `setup-and-test.sh` | Automated: spins up WP, installs Redirection, tests 4 methods + edge cases |
| `teardown.sh` | Clean up containers and volumes |
| `README.md` | Usage instructions and decision criteria |

**Run:** `cd migration/phase-1-redirect-test && ./setup-and-test.sh`

### What is tested

The script automatically tests:

| Category | Tests |
|----------|-------|
| **Method A** | `wp redirection add` CLI command availability |
| **Method B** | `Red_Item::create` via `wp eval` (direct PHP API) |
| **Method C** | Bulk `Red_Item::create` in loop (scalable import) |
| **Method D** | `.htaccess` RewriteRule (server-level, NC flag) |
| **Edge: query strings** | `/page.php?b=1` must still redirect |
| **Edge: extensionless** | `/vyzvy` (no `.php`) → new slug |
| **Edge: trailing slash** | `/old-page/` → target |
| **Edge: case** | `/Page.PHP` vs `/page.php` (plugin + htaccess NC) |
| **Edge: root redirect** | `/index.php` → `/` |
| **Encoding** | Slovak characters (ľščťžýáí) survive through redirect |

### Output

The script generates `test-results.txt` with:
- Which methods are available
- Pass/fail for each test with expected vs actual values
- Summary counts

### Decision Matrix

| Method | Pros | Cons | Use when |
|--------|------|------|----------|
| Redirection plugin (B/C) | UI for editors, 404 monitoring | PHP overhead per request | <200 redirects, need monitoring |
| .htaccess (D) | Fast, no PHP, case-insensitive | No UI, harder to audit | Static map, performance critical |
| Hybrid | Best of both | More complex | 404 monitoring + fast redirects |

**Do NOT proceed until the chosen method is proven and documented.**

---

## Phase 0: Infrastructure

### Node.js Project Setup

```json
{
  "name": "marysmeals-migration",
  "private": true,
  "type": "module",
  "engines": { "node": ">=22" },
  "scripts": {
    "discover": "tsx scripts/discover.ts",
    "crawl": "tsx scripts/crawl.ts",
    "clean": "tsx scripts/clean-html.ts",
    "import": "tsx scripts/import-content.ts",
    "validate": "tsx scripts/validate.ts"
  },
  "dependencies": {
    "crawlee": "^3.17.0",
    "playwright": "^1.48.0",
    "cheerio": "^1.0.0"
  },
  "devDependencies": {
    "tsx": "^4.19.0",
    "typescript": "^5.6.0",
    "@types/node": "^22.0.0"
  }
}
```

```json
// tsconfig.json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "esModuleInterop": true,
    "strict": true,
    "outDir": "dist",
    "rootDir": "scripts"
  },
  "include": ["scripts/**/*.ts"]
}
```

### Directory Structure

```
sites/marysmeals-sk/
├── docker-compose.yml
├── package.json
├── tsconfig.json
├── scripts/
│   ├── discover.ts          # Phase 1: Generate inventory
│   ├── crawl.ts             # Phase 2: Content extraction
│   ├── clean-html.ts        # Phase 4: HTML cleaning
│   ├── import-content.ts    # Phase 5: WP import
│   ├── create-menus.sh      # Phase 6
│   ├── import-redirects.sh  # Phase 7
│   └── validate.ts          # Phase 8
├── data/
│   ├── legacy_inventory.tsv # Generated, then manually reviewed
│   ├── raw-export.json
│   ├── url-map.json         # old URL → new URL mapping
│   ├── redirect-map.json    # Reviewable redirect artifact
│   └── final-import.json
└── reports/
    └── import-report.json   # Created/updated/skipped/failed
```

### Preflight Check

```bash
#!/bin/bash
# scripts/preflight.sh
set -e

echo "Checking Docker images..."
docker pull wordpress:6.7.2-php8.3-apache
docker pull mysql:8.0.36
docker pull wordpress:cli-2.11.0-php8.3

echo "Checking Node.js version..."
node --version | grep -qE "^v(22|24)" || { echo "ERROR: Node >= 22 required"; exit 1; }

echo "Installing dependencies..."
npm ci

echo "Installing Playwright browsers..."
npx playwright install chromium

echo "Preflight complete"
```

**Note:** This plan covers the content migration pipeline only. Production hosting architecture (SSL, CDN, reverse proxy, email, monitoring, backups) is a separate concern to be defined with the hosting provider.

---

## Phase 1: Discovery & Audit

### Approach

Do NOT hand-author the inventory. Generate it from the live site:

1. Crawl the full live site (follow all internal links)
2. Check for sitemap.xml
3. Cross-reference with known business-critical URLs
4. Manually review and annotate the generated inventory

### Discovery Script

```typescript
// scripts/discover.ts
import { PlaywrightCrawler } from 'crawlee';
import * as fs from 'fs';

interface DiscoveredUrl {
  url: string;
  status: number;
  content_type: string;
  canonical?: string;
  title?: string;
  found_via: 'crawl' | 'sitemap' | 'manual';
  links_to: string[];
}

const BASE = 'https://marysmeals.sk';
const discovered = new Map<string, DiscoveredUrl>();

const crawler = new PlaywrightCrawler({
  maxRequestsPerCrawl: 500,
  requestHandlerTimeoutSecs: 30,

  async requestHandler({ page, request, enqueueLinks }) {
    const url = request.url;
    const status = (await page.evaluate(() => 
      (performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming)?.responseStatus
    )) || 200;

    const title = await page.title();
    const canonical = await page.$eval(
      'link[rel="canonical"]', el => el.getAttribute('href')
    ).catch(() => undefined);

    // Find all internal links
    const links = await page.$$eval('a[href]', (anchors, base) => {
      return anchors
        .map(a => {
          try { return new URL(a.getAttribute('href') || '', base).href; }
          catch { return null; }
        })
        .filter((href): href is string => 
          href !== null && href.startsWith(base)
        );
    }, BASE);

    discovered.set(url, {
      url,
      status,
      content_type: 'text/html',
      canonical: canonical || undefined,
      title,
      found_via: 'crawl',
      links_to: [...new Set(links)],
    });

    // Enqueue discovered links
    await enqueueLinks({
      strategy: 'same-domain',
      transformRequestFunction: (req) => {
        // Skip obvious non-content URLs
        if (req.url.match(/\.(css|js|woff|woff2|ttf|eot)$/i)) return false;
        return req;
      },
    });

    console.log(`[${status}] ${url} (${links.length} links)`);
  },
});

async function checkSitemap() {
  try {
    const resp = await fetch(`${BASE}/sitemap.xml`);
    if (resp.ok) {
      const text = await resp.text();
      const urls = [...text.matchAll(/<loc>([^<]+)<\/loc>/g)].map(m => m[1]);
      console.log(`Sitemap: found ${urls.length} URLs`);
      return urls;
    }
  } catch {}
  console.log('No sitemap found');
  return [];
}

async function main() {
  // Check sitemap first
  const sitemapUrls = await checkSitemap();

  // Crawl from homepage
  await crawler.run([BASE]);

  // Add sitemap URLs not found by crawl
  for (const url of sitemapUrls) {
    if (!discovered.has(url)) {
      discovered.set(url, {
        url,
        status: 0, // unknown until crawled
        content_type: 'text/html',
        found_via: 'sitemap',
        links_to: [],
      });
    }
  }

  // Generate TSV inventory for manual review
  const header = [
    'url', 'status', 'title', 'content_type', 'found_via',
    'migration_action', 'new_slug', 'post_type', 'category',
    'priority', 'notes'
  ].join('\t');

  const rows = [...discovered.values()].map(d => {
    // Pre-classify based on URL patterns
    let action = 'import';
    let post_type = 'page';
    let category = '';
    let slug = '';

    const path = new URL(d.url).pathname;

    if (path.match(/\.(pdf|doc|docx|xls|xlsx)$/i)) {
      action = 'media';
      post_type = '';
    } else if (path.match(/\.(jpg|jpeg|png|gif|webp|svg)$/i)) {
      action = 'media';
      post_type = '';
    } else if (d.url.includes('novinky') && path !== '/novinky.php' && path !== '/novinky/') {
      post_type = 'post';
      category = 'novinky';
    }

    // Generate slug suggestion from filename
    slug = path.replace(/^\//, '').replace(/\.php$/, '').replace(/\//g, '') || 'front-page';

    return [
      d.url, d.status, d.title || '', d.content_type, d.found_via,
      action, slug, post_type, category, '2', ''
    ].join('\t');
  });

  const tsv = [header, ...rows].join('\n');
  fs.writeFileSync('data/legacy_inventory.tsv', tsv);

  // Also save full discovery data for reference
  fs.writeFileSync(
    'data/discovery-raw.json',
    JSON.stringify([...discovered.values()], null, 2)
  );

  console.log(`\nDiscovered ${discovered.size} URLs`);
  console.log('Written to: data/legacy_inventory.tsv');
  console.log('');
  console.log('NEXT STEPS:');
  console.log('1. Review data/legacy_inventory.tsv manually');
  console.log('2. Set migration_action for each URL: import | redirect-only | media | ignore');
  console.log('3. Verify new_slug values');
  console.log('4. Mark business-critical pages as priority=1');
  console.log('5. Commit the reviewed inventory before proceeding');
}

main().catch(console.error);
```

### Inventory Format

| Column | Description |
|--------|-------------|
| `url` | Full original URL |
| `status` | HTTP status from crawl |
| `title` | Page title from crawl |
| `content_type` | MIME type |
| `found_via` | crawl / sitemap / manual |
| `migration_action` | import / redirect-only / media / ignore / manual |
| `new_slug` | Target slug in WordPress |
| `post_type` | page / post / (empty for media/ignore) |
| `category` | Category slug (for posts) |
| `priority` | 1=critical, 2=normal, 3=low |
| `notes` | Manual annotation |

### Manual Review Checklist

After running discovery:

- [ ] Compare with live site navigation (visible menu items)
- [ ] Identify all news articles and confirm count
- [ ] Flag extensionless URLs (e.g., `/vyzvy`, `/nasytte-skolu`)
- [ ] Flag URLs with query strings that need preservation
- [ ] Mark PDFs and downloadable files
- [ ] Confirm donation page marked as `ignore` (out-of-scope)
- [ ] Set correct `new_slug` for every importable page
- [ ] Commit reviewed inventory to source control

---

## Phase 2: Crawl

### Content Extraction

```typescript
// scripts/crawl.ts
import { PlaywrightCrawler, Dataset } from 'crawlee';
import * as cheerio from 'cheerio';
import * as fs from 'fs';

interface PageData {
  url: string;
  title: string;
  content: string;
  images: string[];
  publish_date?: string;
  meta: {
    description?: string;
    og_image?: string;
  };
  extractedFrom: 'main' | 'article' | 'body';
}

// Load reviewed inventory
const inventory = fs.readFileSync('data/legacy_inventory.tsv', 'utf-8')
  .split('\n')
  .slice(1)
  .filter(line => line.trim())
  .map(line => {
    const parts = line.split('\t');
    return {
      url: parts[0],
      action: parts[5],
      slug: parts[6],
      post_type: parts[7],
      category: parts[8],
    };
  })
  .filter(item => item.action === 'import');

const crawler = new PlaywrightCrawler({
  maxRequestsPerCrawl: 500,
  requestHandlerTimeoutSecs: 60,

  async requestHandler({ page, request }) {
    const url = request.url;
    const html = await page.content();
    const $ = cheerio.load(html);

    const title = $('title').text().trim() ||
                  $('h1').first().text().trim() ||
                  'Untitled';

    // Extract content - try semantic selectors
    let content = '';
    let extractedFrom: 'main' | 'article' | 'body' = 'body';

    if ($('main').length) {
      content = $('main').html() || '';
      extractedFrom = 'main';
    } else if ($('article').length) {
      content = $('article').html() || '';
      extractedFrom = 'article';
    } else if ($('.content, #content, .page-content').length) {
      content = $('.content, #content, .page-content').first().html() || '';
      extractedFrom = 'body';
    } else {
      const $body = $('body').clone();
      $body.find('nav, header, footer, script, style, .menu, .sidebar, .cookie').remove();
      content = $body.html() || '';
      extractedFrom = 'body';
    }

    // Extract images - resolve relative URLs
    const images = await page.$$eval('img[src], img[data-src]', (imgs, pageUrl) => {
      return imgs.map(img => {
        const src = img.getAttribute('src') || img.getAttribute('data-src') || '';
        try { return new URL(src, pageUrl).toString(); }
        catch { return ''; }
      }).filter(Boolean);
    }, url);

    // Extract publish date (critical for news articles)
    let publish_date: string | undefined;

    // Try meta tags first
    const dateSelectors = [
      'meta[property="article:published_time"]',
      'meta[name="date"]',
      'meta[name="DC.date"]',
      'time[datetime]',
    ];

    for (const sel of dateSelectors) {
      const el = $(sel).first();
      const val = el.attr('content') || el.attr('datetime');
      if (val) { publish_date = val; break; }
    }

    // Try visible date patterns in content
    if (!publish_date) {
      const datePattern = /(\d{1,2})\.\s*(\d{1,2})\.\s*(\d{4})/; // Slovak: DD.MM.YYYY
      const text = $('body').text();
      const match = text.match(datePattern);
      if (match) {
        const [, day, month, year] = match;
        publish_date = `${year}-${month.padStart(2, '0')}-${day.padStart(2, '0')}`;
      }
    }

    // Meta
    const meta = {
      description: $('meta[name="description"]').attr('content'),
      og_image: $('meta[property="og:image"]').attr('content'),
    };

    const pageData: PageData = {
      url,
      title,
      content,
      images: [...new Set(images)],
      publish_date,
      meta,
      extractedFrom,
    };

    await Dataset.pushData(pageData);
    console.log(`Crawled: ${url} [${extractedFrom}]${publish_date ? ` date=${publish_date}` : ''}`);
  },
});

async function main() {
  const urls = inventory.map(item => item.url);
  console.log(`Crawling ${urls.length} URLs from reviewed inventory...`);

  await crawler.run(urls);

  const dataset = await Dataset.open();
  const data = await dataset.getData();

  fs.writeFileSync('data/raw-export.json', JSON.stringify(data.items, null, 2));
  console.log(`Exported ${data.items.length} pages to raw-export.json`);

  // Report pages extracted from body (need manual review)
  const bodyPages = data.items.filter((p: any) => p.extractedFrom === 'body');
  if (bodyPages.length > 0) {
    console.warn(`\n⚠ ${bodyPages.length} pages extracted from <body> - review manually`);
  }

  // Report pages without dates (news articles should have dates)
  const newsWithoutDate = data.items.filter((p: any) => {
    const inv = inventory.find(i => i.url === p.url);
    return inv?.post_type === 'post' && !p.publish_date;
  });
  if (newsWithoutDate.length > 0) {
    console.warn(`\n⚠ ${newsWithoutDate.length} news posts without detected date - set manually`);
  }
}

main().catch(console.error);
```

---

## Phase 3: Media Import (Sideload from URLs)

Media is sideloaded directly from source URLs. No host→container path mapping needed.

```bash
#!/bin/bash
# scripts/import-media.sh
# Sideloads media from original URLs directly into WordPress

set -e
WPCLI="docker compose run --rm wpcli"
OUTPUT="data/attachment-mapping.json"

echo "Extracting image URLs from raw-export.json..."
jq -r '.[].images[]' data/raw-export.json | sort -u > data/media-urls.txt

TOTAL=$(wc -l < data/media-urls.txt)
echo "Found $TOTAL unique media URLs"

echo "{" > "$OUTPUT"
first=true
imported=0
failed=0

while read -r url; do
  # Skip empty
  [[ -z "$url" ]] && continue

  # Sideload directly from URL - WP-CLI handles download
  result=$($WPCLI media import "$url" --porcelain 2>/dev/null || echo "")

  if [[ -n "$result" && "$result" =~ ^[0-9]+$ ]]; then
    attachment_id=$result
    attachment_url=$($WPCLI post list --post_type=attachment \
      --post__in="$attachment_id" --field=guid 2>/dev/null || echo "")

    [[ "$first" != "true" ]] && echo "," >> "$OUTPUT"
    first=false

    # Map by SOURCE URL (not filename) for reliable matching
    # Escape URL for JSON
    escaped_url=$(echo "$url" | sed 's/"/\\"/g')
    echo "  \"$escaped_url\": {\"id\": $attachment_id, \"url\": \"$attachment_url\"}" >> "$OUTPUT"

    imported=$((imported + 1))
    echo "  [$imported/$TOTAL] $url → ID $attachment_id"
  else
    failed=$((failed + 1))
    echo "  FAILED: $url" >&2
  fi

done < data/media-urls.txt

echo "}" >> "$OUTPUT"

echo ""
echo "Media import complete: $imported imported, $failed failed"
echo "Mapping saved to: $OUTPUT"
```

**Key differences from v6:**
- Maps by **source URL** (not filename) — handles duplicate filenames from different directories
- Uses `wp media import <URL>` — WP-CLI downloads directly, no host/container path mismatch
- Counters use `$((x + 1))` — safe under `set -e`

---

## Phase 4: Clean HTML (Inventory-Based Link Rewriting)

```typescript
// scripts/clean-html.ts
import * as fs from 'fs';
import * as cheerio from 'cheerio';

interface RawPage {
  url: string;
  title: string;
  content: string;
  images: string[];
  publish_date?: string;
  meta: { description?: string; og_image?: string };
  extractedFrom: string;
}

interface AttachmentMapping {
  [sourceUrl: string]: { id: number; url: string };
}

interface CleanedPage {
  url: string;
  title: string;
  content: string;
  excerpt: string;
  type: 'page' | 'post';
  slug: string;
  category?: string;
  publish_date?: string;
  meta_description?: string;
  featured_image_id?: number;
  extractedFrom: string;
}

// Build URL map from inventory (old URL → new path)
const urlMap = new Map<string, string>();
const inventoryLines = fs.readFileSync('data/legacy_inventory.tsv', 'utf-8')
  .split('\n').slice(1).filter(l => l.trim());

const inventoryEntries = new Map<string, {
  action: string; slug: string; post_type: string; category: string;
}>();

for (const line of inventoryLines) {
  const [url, , , , , action, slug, post_type, category] = line.split('\t');
  inventoryEntries.set(url, { action, slug, post_type, category });

  // Build URL map for link rewriting
  if (action === 'import' && slug) {
    const oldPath = new URL(url).pathname;
    const newPath = `/${slug}/`;
    urlMap.set(url, newPath);
    urlMap.set(oldPath, newPath);
    // Also map without trailing slash
    urlMap.set(oldPath.replace(/\/$/, ''), newPath);
  }
}

// Load attachment mapping (keyed by source URL)
const attachmentMapping: AttachmentMapping = JSON.parse(
  fs.readFileSync('data/attachment-mapping.json', 'utf-8')
);

function cleanHtml(html: string, pageUrl: string): { content: string; featuredImageId?: number } {
  const $ = cheerio.load(html, { xmlMode: false });

  // Remove unwanted elements
  $('script, style, iframe, .advertisement, .social-share, .cookie-banner').remove();

  // Sanitize attributes (keep safe set)
  const safeAttrs = new Set([
    'href', 'src', 'alt', 'title', 'class', 'id',
    'width', 'height', 'colspan', 'rowspan', 'scope',
    'target', 'rel', 'type', 'lang', 'dir',
    'aria-label', 'aria-describedby', 'role',
  ]);

  $('*').each((_, el) => {
    if (!('attribs' in el)) return;
    const attrs = Object.keys(el.attribs || {});
    for (const attr of attrs) {
      if (!safeAttrs.has(attr) && !attr.startsWith('data-')) {
        $(el).removeAttr(attr);
      }
    }
  });

  // Sanitize links - remove javascript: and other unsafe protocols
  $('a[href]').each((_, el) => {
    const href = $(el).attr('href') || '';
    if (href.match(/^(javascript|data|vbscript):/i)) {
      $(el).removeAttr('href');
    }
  });

  // REWRITE INTERNAL LINKS using inventory-based URL map (not regex)
  $('a[href]').each((_, el) => {
    const $a = $(el);
    const href = $a.attr('href');
    if (!href) return;

    // Resolve to absolute URL
    let absoluteUrl: string;
    try {
      absoluteUrl = new URL(href, pageUrl).toString();
    } catch { return; }

    // Only rewrite internal links
    if (!absoluteUrl.includes('marysmeals.sk')) return;

    const absolutePath = new URL(absoluteUrl).pathname;

    // Look up in URL map
    const newPath = urlMap.get(absoluteUrl) || urlMap.get(absolutePath);
    if (newPath) {
      $a.attr('href', newPath);
    }
    // If not in map, leave as-is (redirect will handle it)
  });

  // Rewrite image URLs to WordPress attachment URLs
  let featuredImageId: number | undefined;

  $('img').each((i, el) => {
    const $img = $(el);
    const src = $img.attr('src') || $img.attr('data-src');
    if (!src) return;

    // Resolve to absolute URL
    let absoluteSrc: string;
    try {
      absoluteSrc = new URL(src, pageUrl).toString();
    } catch { return; }

    // Look up in attachment mapping (by source URL)
    const attachment = attachmentMapping[absoluteSrc];
    if (attachment) {
      $img.attr('src', attachment.url);
      $img.removeAttr('data-src');
      if (i === 0 && !featuredImageId) {
        featuredImageId = attachment.id;
      }
    }
  });

  // Return only the body content fragment (not full HTML document)
  const bodyContent = $('body').html() || $.html();

  return { content: bodyContent, featuredImageId };
}

function generateExcerpt(html: string, maxLength = 160): string {
  const $ = cheerio.load(html);
  const text = $.text().replace(/\s+/g, ' ').trim();
  if (text.length <= maxLength) return text;
  return text.substring(0, maxLength).replace(/\s+\S*$/, '') + '...';
}

// Main
const rawData: RawPage[] = JSON.parse(fs.readFileSync('data/raw-export.json', 'utf-8'));

const cleanedData: CleanedPage[] = rawData
  .map(page => {
    const entry = inventoryEntries.get(page.url);
    if (!entry || entry.action !== 'import') return null;

    const { content, featuredImageId } = cleanHtml(page.content, page.url);

    return {
      url: page.url,
      title: page.title,
      content,
      excerpt: generateExcerpt(content),
      type: entry.post_type as 'page' | 'post',
      slug: entry.slug,
      category: entry.category || undefined,
      publish_date: page.publish_date,
      meta_description: page.meta.description,
      featured_image_id: featuredImageId,
      extractedFrom: page.extractedFrom,
    };
  })
  .filter((p): p is CleanedPage => p !== null);

fs.writeFileSync('data/final-import.json', JSON.stringify(cleanedData, null, 2));

// Also generate the URL map as a reviewable artifact
fs.writeFileSync('data/url-map.json', JSON.stringify(
  Object.fromEntries(urlMap), null, 2
));

console.log(`Cleaned ${cleanedData.length} pages → final-import.json`);
console.log(`URL map: ${urlMap.size} entries → url-map.json`);

// Warnings
const bodyExtracted = cleanedData.filter(p => p.extractedFrom === 'body');
if (bodyExtracted.length > 0) {
  console.warn(`⚠ ${bodyExtracted.length} pages from <body> fallback - review content quality`);
}
```

**Key differences from v6:**
- Link rewriting uses **inventory-based URL map**, not `.php` → `/` regex
- Attribute sanitization keeps accessibility/table/responsive attrs
- Sanitizes `javascript:` links
- Returns body fragment only (no `<html><head>` wrapper)
- Generates reviewable `url-map.json` artifact

---

## Phase 5: Content Import (Idempotent)

```typescript
// scripts/import-content.ts
import { spawnSync } from 'child_process';
import * as fs from 'fs';

interface ImportPage {
  url: string;
  title: string;
  content: string;
  excerpt: string;
  type: 'page' | 'post';
  slug: string;
  category?: string;
  publish_date?: string;
  meta_description?: string;
  featured_image_id?: number;
}

interface ImportReport {
  created: string[];
  updated: string[];
  skipped: string[];
  failed: { url: string; error: string }[];
  run_date: string;
}

function runWpCli(args: string[], stdin?: string): string {
  const result = spawnSync(
    'docker', ['compose', 'run', '--rm', '-i', 'wpcli', ...args],
    { input: stdin, encoding: 'utf-8', maxBuffer: 50 * 1024 * 1024 }
  );
  if (result.error) throw new Error(`WP-CLI error: ${result.error.message}`);
  if (result.status !== 0) throw new Error(`WP-CLI failed: ${result.stderr}`);
  return result.stdout.trim();
}

function findExistingByLegacyUrl(legacyUrl: string): string | null {
  try {
    const result = runWpCli([
      'post', 'list',
      '--post_type=page,post',
      '--meta_key=_legacy_url',
      `--meta_value=${legacyUrl}`,
      '--field=ID',
      '--post_status=any',
    ]);
    return result || null;
  } catch { return null; }
}

function createCategory(slug: string, name?: string): void {
  try {
    const existing = runWpCli(['term', 'list', 'category', `--slug=${slug}`, '--field=term_id']);
    if (existing) return;
  } catch {}
  // Use proper display name (capitalized)
  const displayName = name || slug.charAt(0).toUpperCase() + slug.slice(1);
  runWpCli(['term', 'create', 'category', displayName, `--slug=${slug}`, '--porcelain']);
}

function importPage(page: ImportPage, report: ImportReport): void {
  // Check if already imported (idempotency)
  const existingId = findExistingByLegacyUrl(page.url);

  if (existingId) {
    // UPDATE existing post
    console.log(`  Updating: ${page.slug} (ID ${existingId})`);
    try {
      const args = [
        'post', 'update', existingId, '-',
        `--post_title=${page.title}`,
        `--post_name=${page.slug}`,
        `--post_excerpt=${page.excerpt}`,
      ];
      if (page.publish_date) args.push(`--post_date=${page.publish_date}`);
      runWpCli(args, page.content);
      report.updated.push(page.url);
    } catch (e: any) {
      report.failed.push({ url: page.url, error: e.message });
    }
    return;
  }

  // CREATE new post
  console.log(`  Creating: ${page.slug} (${page.type})`);
  try {
    const args = [
      'post', 'create', '-',
      `--post_type=${page.type}`,
      `--post_title=${page.title}`,
      `--post_name=${page.slug}`,
      `--post_status=publish`,
      `--post_excerpt=${page.excerpt}`,
      '--porcelain',
    ];
    if (page.publish_date) args.push(`--post_date=${page.publish_date}`);

    const postId = runWpCli(args, page.content);
    if (!postId) {
      report.failed.push({ url: page.url, error: 'No post ID returned' });
      return;
    }

    // Store legacy URL for idempotency
    runWpCli(['post', 'meta', 'update', postId, '_legacy_url', page.url]);

    // Set category
    if (page.type === 'post' && page.category) {
      createCategory(page.category, page.category === 'novinky' ? 'Novinky' : undefined);
      runWpCli(['post', 'term', 'set', postId, 'category', page.category]);
    }

    // Set featured image
    if (page.featured_image_id) {
      runWpCli(['post', 'meta', 'update', postId, '_thumbnail_id', String(page.featured_image_id)]);
    }

    // Set SEO meta (only if SEO plugin is active)
    if (page.meta_description) {
      runWpCli(['post', 'meta', 'update', postId, '_legacy_meta_description', page.meta_description]);
    }

    report.created.push(page.url);
  } catch (e: any) {
    report.failed.push({ url: page.url, error: e.message });
  }
}

// Main
const data: ImportPage[] = JSON.parse(fs.readFileSync('data/final-import.json', 'utf-8'));
const report: ImportReport = { created: [], updated: [], skipped: [], failed: [], run_date: new Date().toISOString() };

console.log(`Importing ${data.length} items (idempotent - safe to rerun)...`);

const pages = data.filter(p => p.type === 'page');
const posts = data.filter(p => p.type === 'post');

console.log(`\n=== Pages (${pages.length}) ===`);
for (const page of pages) importPage(page, report);

console.log(`\n=== Posts (${posts.length}) ===`);
for (const post of posts) importPage(post, report);

// Set homepage
console.log('\n=== Configuring homepage ===');
const homepageId = findExistingByLegacyUrl(data.find(p => p.slug === 'front-page')?.url || '');
if (homepageId) {
  runWpCli(['option', 'update', 'show_on_front', 'page']);
  runWpCli(['option', 'update', 'page_on_front', homepageId]);
  console.log(`Homepage set to ID ${homepageId}`);
}

// Save report
fs.writeFileSync('reports/import-report.json', JSON.stringify(report, null, 2));

console.log('\n=== Import Report ===');
console.log(`Created: ${report.created.length}`);
console.log(`Updated: ${report.updated.length}`);
console.log(`Skipped: ${report.skipped.length}`);
console.log(`Failed:  ${report.failed.length}`);
if (report.failed.length > 0) {
  console.error('\nFailed items:');
  report.failed.forEach(f => console.error(`  ${f.url}: ${f.error}`));
}
```

**Key differences from v6:**
- **Idempotent**: checks `_legacy_url` meta before creating; updates if exists
- **Preserves dates**: passes `--post_date` from crawled publish dates
- **Import report**: machine-readable JSON with created/updated/skipped/failed
- **Category name**: Uses proper display name, not raw slug
- **SEO meta**: stored as `_legacy_meta_description` (plugin-agnostic)

---

## Phase 6: Menus + Navigation

**Note:** Menu items must match the actual live site navigation, which is determined by the reviewed inventory in Phase 1. The script below is a template — update menu items based on the inventory before running.

```bash
#!/bin/bash
# scripts/create-menus.sh
# UPDATE MENU ITEMS based on reviewed inventory before running!

set -e
WPCLI="docker compose run --rm wpcli"

echo "=== Creating menus ==="

# Delete existing menus (idempotent)
$WPCLI menu delete "Hlavné menu" 2>/dev/null || true
$WPCLI menu delete "Pätičkové menu" 2>/dev/null || true

# Create primary menu
$WPCLI menu create "Hlavné menu"

# Menu items - MUST be updated from reviewed inventory
# These are placeholders based on discovery output
add_page_item() {
  local title="$1"
  local slug="$2"
  local position="$3"

  page_id=$($WPCLI post list --post_type=page --name="$slug" --field=ID 2>/dev/null || echo "")
  if [[ -n "$page_id" ]]; then
    $WPCLI menu item add-post "Hlavné menu" "$page_id" --position="$position"
  else
    echo "  ⚠ Page not found: $slug (adding as custom link)"
    $WPCLI menu item add-custom "Hlavné menu" "$title" "/$slug/" --position="$position"
  fi
}

# TODO: Update these from actual live site navigation after Phase 1 review
add_page_item "Domov" "front-page" 1
add_page_item "Čo je Mary's Meals" "co-je-marys-meals" 2
add_page_item "Kde pomáhame" "kde-pomahame" 3
add_page_item "O nás" "o-nas" 4
add_page_item "Novinky" "novinky" 5
add_page_item "Kontakt" "kontakt" 6

# Assign to theme location (theme-dependent — verify first)
LOCATIONS=$($WPCLI menu location list --format=csv 2>/dev/null || echo "")
if echo "$LOCATIONS" | grep -qi "primary"; then
  $WPCLI menu location assign "Hlavné menu" primary
  echo "Assigned to 'primary' location"
elif echo "$LOCATIONS" | grep -qi "navigation"; then
  $WPCLI menu location assign "Hlavné menu" navigation
  echo "Assigned to 'navigation' location"
else
  echo "⚠ No known menu location found. Assign manually in WP admin."
  echo "Available locations:"
  $WPCLI menu location list
fi

echo "Primary menu created"
```

---

## Phase 7: Redirects (Bulk Artifact)

### Generate Redirect Map (Reviewable Artifact)

```typescript
// scripts/generate-redirects.ts
import * as fs from 'fs';

interface Redirect {
  source: string;
  target: string;
  code: number;
  note: string;
}

const inventory = fs.readFileSync('data/legacy_inventory.tsv', 'utf-8')
  .split('\n').slice(1).filter(l => l.trim());

const redirects: Redirect[] = [];

for (const line of inventory) {
  const [url, , , , , action, slug, post_type, category] = line.split('\t');

  if (action === 'ignore') continue;
  if (!url || !slug) continue;

  const oldPath = new URL(url).pathname;

  // Build target path
  let targetPath: string;
  if (slug === 'front-page') {
    targetPath = '/';
  } else {
    targetPath = `/${slug}/`;
  }

  // Skip if old path equals new path (no redirect needed)
  if (oldPath === targetPath) continue;

  redirects.push({
    source: oldPath,
    target: targetPath,
    code: 301,
    note: `${action}: ${url}`,
  });
}

// Add common legacy patterns
redirects.push(
  { source: '/index.php', target: '/', code: 301, note: 'Legacy index' },
  { source: '/index.html', target: '/', code: 301, note: 'Legacy index' },
);

// Save as reviewable artifact
fs.writeFileSync('data/redirect-map.json', JSON.stringify(redirects, null, 2));

console.log(`Generated ${redirects.length} redirects → data/redirect-map.json`);
console.log('');
console.log('NEXT STEPS:');
console.log('1. Review data/redirect-map.json');
console.log('2. Commit to source control');
console.log('3. Run scripts/import-redirects.sh to apply');
```

### Import Redirects (Bulk)

```bash
#!/bin/bash
# scripts/import-redirects.sh
# Imports reviewed redirect-map.json into WordPress

set -e
WPCLI="docker compose run --rm wpcli"

REDIRECT_MAP="data/redirect-map.json"

if [[ ! -f "$REDIRECT_MAP" ]]; then
  echo "ERROR: $REDIRECT_MAP not found. Run 'npm run generate-redirects' first."
  exit 1
fi

echo "=== Importing redirects from $REDIRECT_MAP ==="

# Verify Redirection plugin
$WPCLI plugin is-active redirection || {
  echo "ERROR: Redirection plugin not active"
  exit 1
}

# Determine import method based on Phase -1 findings
# Method: Use wp eval to call Redirection API directly (bulk)
TOTAL=$(jq length "$REDIRECT_MAP")
echo "Total redirects: $TOTAL"

imported=0
failed=0

jq -c '.[]' "$REDIRECT_MAP" | while read -r item; do
  source=$(echo "$item" | jq -r '.source')
  target=$(echo "$item" | jq -r '.target')
  code=$(echo "$item" | jq -r '.code')

  # Use WP-CLI eval for reliable bulk creation
  result=$($WPCLI eval "
    if (class_exists('Red_Item')) {
      \$result = Red_Item::create([
        'url' => '$source',
        'action_data' => ['url' => '$target'],
        'action_type' => 'url',
        'action_code' => $code,
        'match_type' => 'url',
        'group_id' => 1,
      ]);
      if (is_wp_error(\$result)) {
        echo 'ERROR:' . \$result->get_error_message();
      } else {
        echo 'OK';
      }
    } else {
      echo 'ERROR:Red_Item not found';
    }
  " 2>/dev/null || echo "ERROR:cli-failed")

  if [[ "$result" == "OK" ]]; then
    imported=$((imported + 1))
  else
    failed=$((failed + 1))
    echo "  FAILED: $source → $target ($result)"
  fi
done

echo ""
echo "=== Redirect import complete ==="
echo "Imported: $imported"
echo "Failed: $failed"
```

---

## Phase 8: Validation

```typescript
// scripts/validate.ts
import * as fs from 'fs';
import { spawnSync } from 'child_process';

const BASE_URL = process.argv[2] || 'http://localhost:8080';

interface ValidationResult {
  test: string;
  url: string;
  passed: boolean;
  expected: string;
  actual: string;
}

const results: ValidationResult[] = [];
let pass = 0;
let fail = 0;

function check(test: string, url: string, passed: boolean, expected: string, actual: string) {
  results.push({ test, url, passed, expected, actual });
  if (passed) { pass++; } else { fail++; }
}

async function httpHead(url: string): Promise<{ status: number; location?: string; headers: Record<string, string> }> {
  const resp = await fetch(url, { redirect: 'manual' });
  return {
    status: resp.status,
    location: resp.headers.get('location') || undefined,
    headers: Object.fromEntries(resp.headers.entries()),
  };
}

async function httpFinalStatus(url: string): Promise<{ status: number; finalUrl: string; hops: number }> {
  let hops = 0;
  let current = url;

  while (hops < 10) {
    const resp = await fetch(current, { redirect: 'manual' });
    if (resp.status >= 300 && resp.status < 400) {
      const loc = resp.headers.get('location');
      if (!loc) break;
      current = new URL(loc, current).toString();
      hops++;
    } else {
      return { status: resp.status, finalUrl: current, hops };
    }
  }

  return { status: 0, finalUrl: current, hops };
}

async function main() {
  console.log(`=== Migration Validation ===`);
  console.log(`Target: ${BASE_URL}`);
  console.log(`Date: ${new Date().toISOString()}\n`);

  // Load redirect map
  const redirectMap: Array<{ source: string; target: string; code: number }> =
    JSON.parse(fs.readFileSync('data/redirect-map.json', 'utf-8'));

  // Test 1: Redirect validation (exact target check)
  console.log('1. Redirects (first response + exact target + final 200)...');

  for (const redir of redirectMap) {
    const url = `${BASE_URL}${redir.source}`;
    const expectedTarget = redir.target;

    const first = await httpHead(url);

    // Check first response is redirect
    if (first.status !== redir.code) {
      check('redirect-first-status', redir.source, false,
        String(redir.code), String(first.status));
      continue;
    }

    // Check Location header matches expected target EXACTLY
    const locationPath = first.location
      ? new URL(first.location, url).pathname
      : '';

    if (locationPath !== expectedTarget && locationPath !== expectedTarget.replace(/\/$/, '')) {
      check('redirect-target', redir.source, false,
        expectedTarget, locationPath);
      continue;
    }

    // Check final response is 200
    const final = await httpFinalStatus(url);
    if (final.status !== 200) {
      check('redirect-final-200', redir.source, false,
        '200', String(final.status));
      continue;
    }

    // Check chain length
    if (final.hops > 2) {
      check('redirect-chain', redir.source, false,
        '≤2 hops', `${final.hops} hops`);
      continue;
    }

    check('redirect', redir.source, true, `${redir.code}→${expectedTarget}→200`, 'OK');
  }

  // Test 2: All imported pages return 200
  console.log('\n2. Imported content availability...');

  const importedPages: Array<{ url: string; slug: string; type: string }> =
    JSON.parse(fs.readFileSync('data/final-import.json', 'utf-8'))
      .map((p: any) => ({ url: p.url, slug: p.slug, type: p.type }));

  for (const page of importedPages) {
    const newUrl = `${BASE_URL}/${page.slug}/`;
    const resp = await httpHead(newUrl);
    check('content-available', `/${page.slug}/`,
      resp.status === 200, '200', String(resp.status));
  }

  // Test 3: Slovak encoding
  console.log('\n3. Slovak encoding...');
  const homeResp = await fetch(BASE_URL);
  const homeHtml = await homeResp.text();

  if (/[ľščťžýáíéôúäňĺŕď]/.test(homeHtml)) {
    check('encoding', '/', true, 'Slovak chars present', 'OK');
  } else if (/Ã¡|Ã©|Äˇ|Å¾/.test(homeHtml)) {
    check('encoding', '/', false, 'UTF-8', 'Mojibake detected');
  } else {
    check('encoding', '/', false, 'Slovak chars', 'None found');
  }

  // Test 4: Key structural pages
  console.log('\n4. Key pages...');
  const keyPages = ['/', '/novinky/'];
  for (const page of keyPages) {
    const resp = await httpHead(`${BASE_URL}${page}`);
    check('key-page', page, resp.status === 200, '200', String(resp.status));
  }

  // Test 5: Content counts match inventory
  console.log('\n5. Content counts...');
  const expectedPosts = importedPages.filter(p => p.type === 'post').length;
  const expectedPages = importedPages.filter(p => p.type === 'page').length;

  function wpCliCount(postType: string): number {
    const r = spawnSync('docker', [
      'compose', 'run', '--rm', 'wpcli',
      'post', 'list', `--post_type=${postType}`, '--format=count'
    ], { encoding: 'utf-8' });
    return parseInt(r.stdout.trim(), 10) || 0;
  }

  const actualPosts = wpCliCount('post');
  const actualPages = wpCliCount('page');

  check('count-posts', 'posts', actualPosts >= expectedPosts,
    `≥${expectedPosts}`, String(actualPosts));
  check('count-pages', 'pages', actualPages >= expectedPages,
    `≥${expectedPages}`, String(actualPages));

  // Summary
  console.log('\n=== Validation Summary ===');
  console.log(`Passed: ${pass}`);
  console.log(`Failed: ${fail}`);

  if (fail > 0) {
    console.log('\nFailures:');
    results.filter(r => !r.passed).forEach(r =>
      console.log(`  ✗ [${r.test}] ${r.url}: expected ${r.expected}, got ${r.actual}`)
    );
  }

  // Save full report
  fs.writeFileSync('reports/validation-report.json', JSON.stringify({
    date: new Date().toISOString(),
    base_url: BASE_URL,
    pass,
    fail,
    results,
  }, null, 2));

  process.exit(fail > 0 ? 1 : 0);
}

main().catch(e => { console.error(e); process.exit(1); });
```

**Key differences from v6:**
- Checks **exact Location header** against expected target (not just status codes)
- TypeScript (not bash) — no `set -e` + `((FAIL++))` bug
- Acceptance counts **derived from inventory**, not hardcoded thresholds
- Validates all imported content URLs return 200
- Saves machine-readable report

---

## Phase 9: Launch Readiness

### Pre-Launch Checklist

| Category | Item | Status |
|----------|------|--------|
| **Content** | All pages imported (per inventory) | [ ] |
| **Content** | All posts imported with correct dates | [ ] |
| **Content** | Media attachments loading | [ ] |
| **Content** | Menus match live site navigation | [ ] |
| **SEO** | All redirects validated (exact targets) | [ ] |
| **SEO** | Sitemap submitted to Search Console | [ ] |
| **SEO** | No `noindex` on production | [ ] |
| **Encoding** | Slovak characters display | [ ] |
| **Links** | No broken internal links | [ ] |
| **Security** | WP_DEBUG = false | [ ] |
| **Security** | Admin password changed | [ ] |

### Rollback Plan

| Step | Action | Time |
|------|--------|------|
| 1 | DNS revert to old hosting | < 5 min (if TTL was lowered) |
| 2 | Restore database from pre-launch backup | < 15 min |
| 3 | Restore uploads from backup | < 15 min |
| 4 | Notify stakeholders | Immediately |

**Before launch:**
- [ ] Reduce DNS TTL to 300s (at least 48h before launch)
- [ ] Take full database backup
- [ ] Take full uploads/media backup
- [ ] Test backup restore procedure
- [ ] Document emergency contacts

### Delta Migration Plan

If content is published on the old site between freeze and launch:

1. Content freeze: Announce freeze date to editors (ideally 48h before launch)
2. Delta window: If content added during freeze, re-run Phases 2–5 (idempotent import will update)
3. Verification: Re-run Phase 8 validation after delta import

### Post-Launch Monitoring (First 7 Days)

- [ ] Monitor 404 log via Redirection plugin dashboard
- [ ] Check Search Console for crawl errors
- [ ] Verify Googlebot is indexing new URLs
- [ ] Check analytics for traffic anomalies
- [ ] Review any missing redirects found via 404 monitoring

### Acceptance Criteria

Derived from inventory (not hardcoded):

| Metric | Source | Threshold |
|--------|--------|-----------|
| Posts imported | Inventory count where `post_type=post` | 100% |
| Pages imported | Inventory count where `post_type=page` | 100% |
| Redirects working | `redirect-map.json` count | 100% first=301, target=exact, final=200 |
| Redirect chain | All | ≤2 hops |
| Broken links | Crawl | 0 internal broken links |
| Encoding | Homepage + sample pages | No mojibake |

---

## Open Decisions

| # | Decision | Options | Recommendation |
|---|----------|---------|----------------|
| 1 | Redirect method | Plugin / .htaccess / Edge | Decide in Phase -1 |
| 2 | Old domain policy | Redirect / Let expire | Depends on ownership |
| 3 | Theme | Twenty Twenty-Four / GeneratePress | Theme-dependent menu setup |
| 4 | PDF handling | Sideload / Keep on old server | Sideload if ≤50 files |
| 5 | News archive URL | `/novinky/` as page or posts-page | Posts page simpler |
| 6 | Production hosting | Managed WP / VPS / Current provider | Separate decision |

---

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Stale inventory | High | High | Crawl-first discovery + manual review |
| Redirect failures | Medium | High | Phase -1 proof + exact-target validation |
| Encoding corruption | Medium | High | UTF-8 at every layer |
| SEO ranking drop | Medium | High | 301 redirects + sitemap + Search Console |
| Duplicate content on rerun | Low (fixed) | Medium | `_legacy_url` idempotency |
| Date loss on news articles | Medium | Medium | Date extraction + manual review |

---

## Out-of-scope

The following items are explicitly **out of scope** for this migration project:

### Donation Page (`/podpora.php`)

The donation page is **not included** in this migration. Reasons:

1. **JavaScript-dependent form** — Cannot be scraped or imported automatically
2. **Payment gateway integration** — Requires separate security review and PCI compliance
3. **Separate project timeline** — Donation functionality rebuild requires dedicated planning with payment provider and stakeholder approval

**Implications:**
- No redirect will be created for `/podpora.php`
- The donation page remains on the legacy infrastructure until a separate project addresses it
- Menu items do not include a link to the donation page
- The "CHCEM DAROVAŤ" CTA visible on the current homepage is not migrated

### Production Hosting Architecture

This plan covers the **content migration pipeline** (local Docker environment for data extraction, transformation, and import). Production hosting topology — SSL, CDN, reverse proxy, email delivery, cron, monitoring, and backups — is a separate concern to be addressed with the hosting provider.

### Block Editor Conversion

Imported content uses classic HTML in `post_content`. Conversion to Gutenberg blocks is optional and post-launch.

### Forms (Contact, Newsletter)

Any forms on the legacy site beyond the donation page need separate evaluation. Contact forms should be rebuilt with a WordPress form plugin after content migration.

---

**Status: BLOCKED**

Complete before implementation:
1. [ ] Run Phase -1 redirect investigation
2. [ ] Choose and prove redirect method
3. [ ] Run discovery crawl and review inventory
4. [ ] Decide production hosting target
5. [ ] Confirm content freeze window with stakeholders
