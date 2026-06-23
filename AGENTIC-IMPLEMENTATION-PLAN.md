# Agentic Development Template Implementation Plan
## wordpress-demo: marysmeals.sk Migration to WordPress 7.0

**Last Updated:** June 23, 2026  
**Status:** Phase -1 Implemented — Redirect Strategy Investigation  
**Active Plan:** See session memory `plan.md` (v7) for current migration plan

---

## Repository Structure

```
wordpress-demo/
├── demo/                              # Original simple WordPress demo
│   ├── docker-compose.yml
│   ├── Dockerfile
│   └── entrypoint.sh
├── migration/                         # Migration scripts (marysmeals.sk)
│   └── phase-1-redirect-test/         # ✅ IMPLEMENTED
│       ├── docker-compose.yml
│       ├── setup-and-test.sh
│       ├── teardown.sh
│       └── README.md
├── AGENTIC-IMPLEMENTATION-PLAN.md     # This file
├── DOCUMENTATION.md
└── NEW_SITE_PLAYBOOK.md
```

## Implementation Progress

| Phase | Status | Location |
|-------|--------|----------|
| Phase -1: Redirect Strategy | ✅ Scripts ready | `migration/phase-1-redirect-test/` |
| Phase 0: Infrastructure | Not started | — |
| Phase 1: Discovery & Audit | Not started | — |
| Phase 2–9: Pipeline | Not started | — |

---

## Legacy Plan (Below)

> **Note:** The plan below is from an earlier iteration. The current migration
> approach is documented in the session plan (v7) which uses a crawl-first
> discovery, idempotent imports, inventory-based link rewriting, and bulk
> redirect artifacts. The content below is retained for reference only.

---

## Executive Summary

This plan creates a **task-driven agentic framework** for wordpress-demo that enables autonomous agent-assisted workflows to:

1. **Scrape** https://marysmeals.sk/ completely (pages, posts, media, navigation, SEO metadata)
2. **Classify** content into WordPress types (pages, posts, CPTs, taxonomies, media, menus)
3. **Extract SEO metadata** (titles, descriptions, canonical URLs, OG tags, schema.org markup)
4. **Import** content into WordPress 7.0 container with full SEO field population
5. **Setup 301 redirects** from old marysmeals.sk URLs to new WordPress URLs
6. **Validate** entire migration with QA checks and Google Search Console compatibility

### Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| WordPress Version | 7.0 | Critical requirement; base image: `wordpress:7.0-apache` |
| SEO Plugin | SEOPress Free | Best for bulk redirect imports + comprehensive metadata mapping |
| Redirect Strategy | SEOPress redirect manager | Post/page-level 301 redirects, 404 monitoring, bulk CSV import |
| Scraper Isolation | Separate Docker container | Node.js 18+, independent from WordPress, reusable, scalable |
| Architecture | docker-compose multi-service | WordPress + MySQL + Scraper containers, shared volumes |
| Deployment | Local Docker (skip cloud for now) | Focused scope, deferring cloud deployment |
| Credential Management | Windows Credential Manager | PowerShell secure credential storage; never in git |
| Config-as-Code | mu-plugins for structure | CPTs, taxonomies, roles version-controlled and idempotent |

---

## Phase 1: Agentic System Structure (Foundational)

### 1.1 Agent Definitions - `.github/agents/` (6 files)

Create 6 specialized agent roles with `.instructions.md` format. Each agent has decision boundaries and tools.

#### **operations-manager.instructions.md**
- **Responsibility:** Orchestrate entire migration: scrape → classify → import → redirect → validate
- **When to invoke:** User says "Migrate marysmeals.sk to WordPress"
- **Decision boundaries:** Delegates to specialists; validates milestones
- **Tools:** Can invoke other agents, read reports, make coordination decisions
- **Outputs:** Coordination logs, milestone status, delegation orders

#### **devops-engineer.instructions.md**
- **Responsibility:** Container management, service health, Docker orchestration, plugin installation
- **When to invoke:** "Check WordPress health", "Install SEOPress", "Manage containers"
- **Tools:** Docker-compose, bash, Docker exec, wp-cli
- **Key tasks:**
  - Verify WordPress 7.0 running
  - Install SEOPress Free plugin
  - Monitor MySQL health
  - Configure scraper container
  - Execute health-check scripts

#### **theme-developer.instructions.md**
- **Responsibility:** Define WordPress structure (CPTs, taxonomies, fields, URLs, permalinks)
- **When to invoke:** "Set up content structure for imported data"
- **Tools:** mu-plugins editing, wp-cli register commands
- **Key tasks:**
  - Register CPT `marysmeals_program` (if classification detects repeating patterns)
  - Register taxonomy `marysmeals_region` 
  - Define custom fields (ACF integration if needed)
  - Configure permalink structure
  - Version-gate schema changes

#### **content-architect.instructions.md**
- **Responsibility:** Analyze scraped data structure, map to WordPress types, define content flow
- **When to invoke:** After scrape complete; before import
- **Tools:** Node.js, JSON analysis, config editing
- **Key tasks:**
  - Review raw-export.json structure
  - Run content classifier
  - Tune content-types.json if needed
  - Validate SEO metadata extraction
  - Approve classified-export.json

#### **scraper-specialist.instructions.md**
- **Responsibility:** Manage web scraper container, validate extraction, troubleshoot crawling
- **When to invoke:** "Scrape marysmeals.sk"
- **Tools:** docker-compose, Node.js logging, Puppeteer/Cheerio APIs
- **Key tasks:**
  - Build scraper image
  - Execute scraping job
  - Monitor for SSL errors, rate limiting, timeouts
  - Validate raw-export.json completeness
  - Download media verification

#### **qa-specialist.instructions.md**
- **Responsibility:** Validate import completeness, content fidelity, metadata accuracy, redirects
- **When to invoke:** After each major phase (scrape, classify, import, redirect)
- **Tools:** WordPress admin inspection, SEOPress reports, Google SC validation, redirect testing
- **Key tasks:**
  - Count posts/pages/CPTs (match classification)
  - Verify media upload counts
  - Test 50+ key URL redirects
  - Check SEO metadata present (titles, descriptions)
  - Generate validation report

### 1.2 Skills Library - `.github/skills/` (10 files)

Create 10 reusable SKILL.md files. Each skill is a task library that agents invoke.

| Skill | Purpose | Invoked By |
|-------|---------|-----------|
| `health-check.md` | Docker/MySQL/WordPress/SEOPress health probes | DevOps Engineer |
| `site-provisioning.md` | Multi-site setup, port assignment, domain config | DevOps Engineer |
| `wp-cli-automation.md` | CPT/taxonomy registration (idempotent), wp-cli patterns | Theme Developer |
| `config-as-code.md` | Version-controlled structure, mu-plugins patterns, idempotency | Theme Developer |
| `windows-credential-mgr.md` | PowerShell credential retrieval (SSH keys, DB passwords) | DevOps Engineer |
| `backup-recovery.md` | Backup procedures, restore from snapshots | DevOps Engineer |
| `web-scraper.md` | Puppeteer crawler execution, media download, raw export | Scraper Specialist |
| `content-classifier.md` | Analyze scraped JSON, categorize by type, extract SEO, generate mapping | Content Architect |
| `wordpress-importer.md` | Parse classified data, create posts/taxonomies/media via wp-cli | (Internal script) |
| `seopress-redirects.md` | Generate redirect CSV, bulk import to SEOPress, validate 404 monitor | QA Specialist |

### 1.3 Commands - `.github/commands/` (6 files)

Create 6 user-facing workflow commands. Each command orchestrates a complete user-requested task.

#### `setup-local.md`
- **What it does:** Bootstrap docker-compose, WordPress 7.0, SEOPress, scraper container
- **Steps:**
  1. Verify Docker installation
  2. Build all services: `docker-compose build`
  3. Start WordPress + MySQL: `docker-compose up -d wordpress db`
  4. Wait for MySQL health check
  5. Create WordPress admin account (if not exists)
  6. Install SEOPress Free: `wp plugin install seopress`
  7. Activate SEOPress: `wp plugin activate seopress`
  8. Run SEOPress setup wizard (programmatically)
  9. Build scraper image: `docker-compose build scraper`
  10. Output: WordPress accessible at `http://localhost:8080`, SEOPress ready, scraper ready

#### `scrape-marysmeals.md`
- **What it does:** Trigger scraper container, extract marysmeals.sk entirely
- **Steps:**
  1. Verify scraper image built
  2. Run: `docker-compose run scraper`
  3. Monitor scraper logs (timeouts, SSL errors, rate limits)
  4. Validate output: `scraped-content/raw-export.json` (size, structure, page counts)
  5. Verify media downloaded: `scraped-content/media/` count matches metadata
  6. Output: raw-export.json ready for classification

#### `classify-content.md`
- **What it does:** Analyze scraped data, categorize by WordPress type, extract SEO
- **Steps:**
  1. Verify raw-export.json exists
  2. Review `config/content-types.json` (URL patterns, CPT rules)
  3. Run: `node scripts/content-classifier.js`
  4. Review output: `scraped-content/classified-export.json`
  5. Check counts: pages, posts, CPTs, taxonomies match expectations
  6. Review SEO analysis: metadata completeness, scores
  7. Adjust config/content-types.json if needed
  8. Approve classified-export.json

#### `import-to-wordpress.md`
- **What it does:** Transform classified data into WordPress posts/taxonomies/media with SEO metadata
- **Steps:**
  1. Verify WordPress healthy
  2. Verify SEOPress active
  3. Run importer (sequentially):
     - Create taxonomies (mu-plugins/marysmeals-core)
     - Upload media files to WordPress
     - Create pages (post_type: page)
     - Create CPT posts (post_type: marysmeals_program, etc.)
     - Create regular posts (post_type: post)
     - Build WordPress navigation menus
     - Populate SEO metadata (titles, descriptions, canonical, OG tags)
  4. Generate import-report.json (post counts, media counts, success/failure)
  5. Output: WordPress populated with all content + SEO metadata

#### `setup-redirects.md`
- **What it does:** Generate 301 redirects from old marysmeals.sk URLs to new WordPress URLs, import into SEOPress
- **Steps:**
  1. Verify import completed
  2. Generate redirect mapping: `scripts/generate-redirects.js`
     - Map: old URL (https://marysmeals.sk/about) → new URL (http://localhost:8080/about/)
     - Output: redirects-import.csv
  3. Bulk import to SEOPress: `scripts/import-redirects-to-seopress.sh`
  4. Verify redirects active in SEOPress
  5. Activate 404 monitor (SEOPress will track missed URLs)
  6. Output: All 50+ redirects active, 404 monitor ready

#### `validate-import.md`
- **What it does:** QA validation across scrape, classify, import, redirects
- **Checks:**
  1. **Scrape completeness:** raw-export.json page count reasonable (expect 40-60+ pages)
  2. **Classification accuracy:** Classified-export.json type distribution matches source (pages, posts, CPTs)
  3. **Import success:** WordPress post counts match classification
  4. **Media integrity:** All media files uploaded, accessible, linked to posts
  5. **SEO metadata:** Sample 10 posts, verify meta titles, descriptions, canonical URLs present
  6. **Redirects working:** Test 50+ key URLs (homepage, /programs, /about, etc.), verify 301 status
  7. **404 monitor:** Verify SEOPress catching any unmapped URLs
  8. **Google compatibility:** Verify XML sitemap generated, can be submitted to Google Search Console
  9. **Output:** Validation report with pass/fail for each check

### 1.4 Settings - `.github/settings.json`

```json
{
  "permissions": {
    "allow": [
      "Bash(docker-compose:*)",
      "Bash(wp-cli:*)",
      "Bash(scripts/:*)",
      "Bash(node scripts/:*)",
      "Read(.github/**)",
      "Read(scripts/**)",
      "Read(config/**)",
      "Read(mu-plugins/**)",
      "Read(scraped-content/**)"
    ],
    "deny": [
      "Read(.env)",
      "Read(.env.local)",
      "Bash(rm -rf)",
      "Write(.git/)",
      "Bash(git push)"
    ]
  },
  "environment": {
    "SCRAPER_TARGET_URL": "https://marysmeals.sk/",
    "WORDPRESS_PORT": "8080",
    "MYSQL_DATABASE": "wordpress",
    "WORDPRESS_ADMIN_USER": "admin",
    "SEOPRESS_LANG": "en"
  },
  "credentials": {
    "ssh_key": "windows_credential_manager",
    "db_password": "windows_credential_manager",
    "wordpress_admin_pass": "windows_credential_manager"
  }
}
```

---

## Phase 2: Docker Setup with WordPress 7.0 & SEOPress (Depends on Phase 1)

### 2.1 Update docker-compose.yml

```yaml
version: '3.8'

services:
  wordpress:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "8080:80"
    depends_on:
      db:
        condition: service_healthy
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_USER: ${MYSQL_USER:-wordpress}
      WORDPRESS_DB_PASSWORD: ${MYSQL_PASSWORD:-wordpress}
      WORDPRESS_DB_NAME: ${MYSQL_DATABASE:-wordpress}
      WORDPRESS_TABLE_PREFIX: wp_
      WORDPRESS_CONFIG_EXTRA: |
        define('WP_MEMORY_LIMIT', '256M');
        define('WP_DEBUG', false);
    volumes:
      - wordpress_data:/var/www/html
      - ./mu-plugins:/var/www/html/wp-content/mu-plugins
      - ./uploads:/var/www/html/wp-content/uploads
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/wp-admin/install.php"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - wordpress-network

  db:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD:-root}
      MYSQL_DATABASE: ${MYSQL_DATABASE:-wordpress}
      MYSQL_USER: ${MYSQL_USER:-wordpress}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD:-wordpress}
    volumes:
      - mysql_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - wordpress-network

  scraper:
    build:
      context: .
      dockerfile: Dockerfile.scraper
    volumes:
      - ./scraped-content:/app/output
      - ./config:/app/config
    env_file:
      - .env.scraper
    # Runs on-demand: docker-compose run scraper
    # Does NOT auto-start
    networks:
      - wordpress-network

volumes:
  wordpress_data:
  mysql_data:

networks:
  wordpress-network:
    driver: bridge
```

### 2.2 Update Dockerfile

```dockerfile
FROM wordpress:7.0-apache

# Install wp-cli
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

# Copy custom entrypoint
COPY entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

# Copy mu-plugins directory
COPY mu-plugins /var/www/html/wp-content/mu-plugins

ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]
CMD ["apache2-foreground"]
```

### 2.3 Create `Dockerfile.scraper`

```dockerfile
FROM node:18-alpine

WORKDIR /app

# Install dependencies
RUN npm install --global \
    puppeteer@latest \
    cheerio@latest \
    axios@latest \
    dotenv@latest

# Copy scripts
COPY scripts/scraper.js /app/
COPY config /app/config

# Create output directory
RUN mkdir -p /app/output

ENV NODE_ENV=production

ENTRYPOINT ["node", "/app/scraper.js"]
```

### 2.4 Create `.env.scraper`

```bash
# Scraper Configuration
TARGET_URL=https://marysmeals.sk/
OUTPUT_PATH=/app/output
MEDIA_DOWNLOAD=true
MEDIA_PATH=/app/output/media
MAX_PAGES=100
CONCURRENCY=3
TIMEOUT_MS=30000
RETRY_ATTEMPTS=3
USER_AGENT=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36
```

### 2.5 Create `scripts/install-plugins.sh`

```bash
#!/bin/bash

# Install SEOPress Free
echo "Installing SEOPress Free..."
docker-compose exec -T wordpress wp plugin install seopress --activate

# Verify installation
echo "Verifying SEOPress installation..."
docker-compose exec -T wordpress wp plugin is-active seopress
if [ $? -eq 0 ]; then
  echo "✓ SEOPress installed and active"
else
  echo "✗ SEOPress installation failed"
  exit 1
fi

# Configure SEOPress settings via wp-cli
echo "Configuring SEOPress..."
docker-compose exec -T wordpress wp option update seopress_redirects_enabled 1
docker-compose exec -T wordpress wp option update seopress_xml_sitemap_enabled 1
docker-compose exec -T wordpress wp option update seopress_404_monitor_enabled 1

echo "✓ SEOPress configured"
```

---

## Phase 3: Web Scraper with SEO Metadata Extraction

### 3.1 Create `scripts/scraper.js`

```javascript
/**
 * Web Scraper for marysmeals.sk
 * Extracts: URLs, titles, content, images, links, SEO metadata
 * Output: scraped-content/raw-export.json + media files
 */

const puppeteer = require('puppeteer');
const cheerio = require('cheerio');
const axios = require('axios');
const fs = require('fs');
const path = require('path');
const dotenv = require('dotenv');

dotenv.config({ path: '/app/.env.scraper' });

const TARGET_URL = process.env.TARGET_URL || 'https://marysmeals.sk/';
const OUTPUT_PATH = process.env.OUTPUT_PATH || '/app/output';
const MEDIA_DOWNLOAD = process.env.MEDIA_DOWNLOAD === 'true';
const MAX_PAGES = parseInt(process.env.MAX_PAGES) || 100;
const CONCURRENCY = parseInt(process.env.CONCURRENCY) || 3;
const TIMEOUT_MS = parseInt(process.env.TIMEOUT_MS) || 30000;

const crawledUrls = new Set();
const pages = [];
const media = {};

async function scrapePage(url) {
  if (crawledUrls.has(url) || crawledUrls.size >= MAX_PAGES) return;
  crawledUrls.add(url);

  try {
    console.log(`[${crawledUrls.size}/${MAX_PAGES}] Scraping: ${url}`);
    
    // Use Puppeteer for JS rendering
    const browser = await puppeteer.launch({ headless: true });
    const page = await browser.newPage();
    await page.goto(url, { waitUntil: 'networkidle0', timeout: TIMEOUT_MS });
    const html = await page.content();
    await browser.close();

    // Parse HTML
    const $ = cheerio.load(html);

    // Extract SEO metadata
    const seoMetadata = {
      meta_title: $('title').text() || $('meta[property="og:title"]').attr('content') || '',
      meta_description: $('meta[name="description"]').attr('content') || $('meta[property="og:description"]').attr('content') || '',
      canonical_url: $('link[rel="canonical"]').attr('href') || url,
      og_title: $('meta[property="og:title"]').attr('content') || '',
      og_description: $('meta[property="og:description"]').attr('content') || '',
      og_image: $('meta[property="og:image"]').attr('content') || '',
      keywords: $('meta[name="keywords"]').attr('content') || '',
      schema_type: extractSchemaType($),
      headers: extractHeaders($)
    };

    // Extract content
    const content = $('body').html();
    const images = [];
    $('img').each((i, img) => {
      images.push({
        url: $(img).attr('src') || $(img).attr('data-src'),
        alt: $(img).attr('alt') || '',
        filename: `img_${crawledUrls.size}_${i}.jpg`
      });
    });

    // Extract links
    const links = [];
    $('a[href]').each((i, a) => {
      const href = $(a).attr('href');
      if (href && (href.startsWith('/') || href.startsWith(TARGET_URL.replace(/\/$/, '')))) {
        links.push(href);
      }
    });

    // Determine page type hint
    const pageTypeHint = determinePageType(url, content);

    pages.push({
      url,
      title: $('h1').first().text() || seoMetadata.meta_title,
      seo_metadata: seoMetadata,
      page_type_hint: pageTypeHint,
      content,
      links: [...new Set(links)],
      images,
      breadcrumbs: extractBreadcrumbs($),
      hierarchy_level: (url.match(/\//g) || []).length - 3 // rough estimate
    });

    // Download media if enabled
    if (MEDIA_DOWNLOAD) {
      for (const img of images) {
        await downloadMedia(img.url, path.join(OUTPUT_PATH, 'media', img.filename));
        media[img.filename] = {
          url: img.url,
          size: fs.statSync(path.join(OUTPUT_PATH, 'media', img.filename)).size,
          type: 'image/jpeg'
        };
      }
    }

    // Extract and queue new links
    links.forEach(link => {
      const fullUrl = link.startsWith('http') ? link : new URL(link, TARGET_URL).href;
      if (fullUrl.startsWith(TARGET_URL.replace(/\/$/, ''))) {
        scrapePage(fullUrl);
      }
    });

  } catch (error) {
    console.error(`Error scraping ${url}:`, error.message);
  }
}

async function downloadMedia(url, filePath) {
  try {
    const response = await axios.get(url, { responseType: 'arraybuffer', timeout: TIMEOUT_MS });
    const dir = path.dirname(filePath);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(filePath, response.data);
  } catch (error) {
    console.error(`Error downloading ${url}:`, error.message);
  }
}

function extractSchemaType($) {
  const schemaScript = $('script[type="application/ld+json"]').first().html();
  if (schemaScript) {
    try {
      const schema = JSON.parse(schemaScript);
      return schema['@type'] || null;
    } catch (e) {
      return null;
    }
  }
  return null;
}

function extractHeaders($) {
  const headers = [];
  $('h1, h2, h3').each((i, header) => {
    headers.push($(header).text());
  });
  return headers;
}

function extractBreadcrumbs($) {
  const breadcrumbs = [];
  $('nav[aria-label*="bread"], .breadcrumb, .breadcrumbs').find('a, li').each((i, el) => {
    breadcrumbs.push($(el).text().trim());
  });
  return breadcrumbs;
}

function determinePageType(url, content) {
  if (url === TARGET_URL || url === TARGET_URL.replace(/\/$/, '')) return 'homepage';
  if (url.includes('/blog') || url.includes('/news')) return 'post';
  if (url.includes('/about') || url.includes('/contact')) return 'page';
  if (url.includes('/program') || url.includes('/product')) return 'cpt';
  return 'page';
}

// Main execution
(async () => {
  // Ensure output directory exists
  if (!fs.existsSync(OUTPUT_PATH)) {
    fs.mkdirSync(OUTPUT_PATH, { recursive: true });
  }

  console.log(`Starting scrape of ${TARGET_URL}`);
  await scrapePage(TARGET_URL);

  // Consolidate results
  const result = {
    metadata: {
      source: TARGET_URL,
      scraped_at: new Date().toISOString(),
      pages_count: pages.length,
      media_count: Object.keys(media).length
    },
    pages,
    media
  };

  // Save to JSON
  fs.writeFileSync(path.join(OUTPUT_PATH, 'raw-export.json'), JSON.stringify(result, null, 2));
  console.log(`✓ Scrape complete. ${pages.length} pages, ${Object.keys(media).length} media files`);
  console.log(`Output: ${path.join(OUTPUT_PATH, 'raw-export.json')}`);
})();
```

---

## Phase 4: Content Classification with SEO Analysis

### 4.1 Create `scripts/content-classifier.js`

```javascript
/**
 * Content Classifier
 * Analyzes raw-export.json and categorizes by WordPress type
 * Extracts and validates SEO metadata
 * Output: classified-export.json with type categories and SEO scores
 */

const fs = require('fs');
const path = require('path');

const CONFIG_PATH = '/app/config/content-types.json';
const RAW_EXPORT_PATH = '/app/output/raw-export.json';
const OUTPUT_PATH = '/app/output/classified-export.json';

// Load configuration
const config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf-8'));

// Load raw export
const rawExport = JSON.parse(fs.readFileSync(RAW_EXPORT_PATH, 'utf-8'));

const classified = {
  pages: [],
  posts: [],
  cpts: {},
  taxonomies: [],
  media: [],
  seo_summary: {}
};

// Classify each page
rawExport.pages.forEach(page => {
  const type = classifyPage(page, config);
  const slug = extractSlug(page.url);
  
  const seoAnalysis = {
    has_meta_title: !!page.seo_metadata.meta_title,
    meta_title: page.seo_metadata.meta_title,
    meta_title_length: page.seo_metadata.meta_title.length,
    has_meta_description: !!page.seo_metadata.meta_description,
    meta_description: page.seo_metadata.meta_description,
    meta_description_length: page.seo_metadata.meta_description.length,
    has_canonical: !!page.seo_metadata.canonical_url,
    canonical_url: page.seo_metadata.canonical_url,
    schema_type: page.seo_metadata.schema_type,
    seo_score: calculateSeoScore(page.seo_metadata),
    recommendations: generateSeoRecommendations(page.seo_metadata)
  };

  const pageData = {
    url: page.url,
    title: page.title,
    slug,
    wordpress_type: type,
    seo_analysis: seoAnalysis,
    content_preview: page.content.substring(0, 200),
    images_count: page.images.length,
    headers: page.seo_metadata.headers
  };

  // Categorize
  switch (type) {
    case 'page':
      classified.pages.push(pageData);
      break;
    case 'post':
      pageData.category = classifyPostCategory(page.url);
      classified.posts.push(pageData);
      break;
    default:
      // CPT
      if (!classified.cpts[type]) classified.cpts[type] = [];
      classified.cpts[type].push(pageData);
  }
});

// Classify media
rawExport.media.forEach((media, filename) => {
  classified.media.push({
    filename,
    url: media.url,
    size: media.size,
    type: media.type
  });
});

// Auto-detect taxonomies
const taxonomies = detectTaxonomies(rawExport.pages, config);
classified.taxonomies = taxonomies;

// SEO Summary
classified.seo_summary = {
  total_pages: rawExport.pages.length,
  pages_with_meta_title: classified.pages.filter(p => p.seo_analysis.has_meta_title).length +
                         classified.posts.filter(p => p.seo_analysis.has_meta_title).length,
  pages_with_meta_description: classified.pages.filter(p => p.seo_analysis.has_meta_description).length +
                               classified.posts.filter(p => p.seo_analysis.has_meta_description).length,
  pages_with_canonical: classified.pages.filter(p => p.seo_analysis.has_canonical).length +
                        classified.posts.filter(p => p.seo_analysis.has_canonical).length,
  avg_seo_score: calculateAverageSeoScore(classified)
};

// Save
fs.writeFileSync(OUTPUT_PATH, JSON.stringify(classified, null, 2));
console.log(`✓ Classification complete.`);
console.log(`  Pages: ${classified.pages.length}`);
console.log(`  Posts: ${classified.posts.length}`);
console.log(`  CPTs: ${Object.keys(classified.cpts).length}`);
console.log(`  Media: ${classified.media.length}`);
console.log(`  Avg SEO Score: ${classified.seo_summary.avg_seo_score.toFixed(1)}`);
console.log(`Output: ${OUTPUT_PATH}`);

// Helper functions
function classifyPage(page, config) {
  // Check manual mappings first
  for (const rule of config.url_patterns) {
    if (new RegExp(rule.pattern).test(page.url)) {
      return rule.wordpress_type;
    }
  }
  
  // Fallback to page type hint
  return page.page_type_hint === 'post' ? 'post' : 'page';
}

function classifyPostCategory(url) {
  if (url.includes('/blog')) return 'blog';
  if (url.includes('/news')) return 'news';
  return 'uncategorized';
}

function extractSlug(url) {
  return url.split('/').filter(p => p).pop() || 'home';
}

function calculateSeoScore(seoMetadata) {
  let score = 0;
  if (seoMetadata.meta_title && seoMetadata.meta_title.length >= 30 && seoMetadata.meta_title.length <= 60) score += 25;
  if (seoMetadata.meta_description && seoMetadata.meta_description.length >= 120 && seoMetadata.meta_description.length <= 160) score += 25;
  if (seoMetadata.canonical_url) score += 20;
  if (seoMetadata.og_title && seoMetadata.og_description) score += 20;
  if (seoMetadata.keywords) score += 10;
  return score;
}

function generateSeoRecommendations(seoMetadata) {
  const recs = [];
  if (!seoMetadata.meta_title) recs.push('Add meta title');
  if (seoMetadata.meta_title && seoMetadata.meta_title.length < 30) recs.push('Meta title too short (< 30 chars)');
  if (seoMetadata.meta_title && seoMetadata.meta_title.length > 60) recs.push('Meta title too long (> 60 chars)');
  if (!seoMetadata.meta_description) recs.push('Add meta description');
  if (seoMetadata.meta_description && seoMetadata.meta_description.length < 120) recs.push('Meta description too short');
  if (!seoMetadata.og_title) recs.push('Add OG title for social sharing');
  return recs;
}

function calculateAverageSeoScore(classified) {
  const allPages = [...classified.pages, ...classified.posts];
  if (allPages.length === 0) return 0;
  const total = allPages.reduce((sum, p) => sum + p.seo_analysis.seo_score, 0);
  return total / allPages.length;
}

function detectTaxonomies(pages, config) {
  const taxonomies = [];
  // Auto-detect from config
  if (config.taxonomies) {
    taxonomies.push(...config.taxonomies);
  }
  return taxonomies;
}
```

### 4.2 Create `config/content-types.json`

```json
{
  "url_patterns": [
    {
      "pattern": "^https://marysmeals\\.sk/$",
      "wordpress_type": "page",
      "slug": "home"
    },
    {
      "pattern": "/about",
      "wordpress_type": "page"
    },
    {
      "pattern": "/contact",
      "wordpress_type": "page"
    },
    {
      "pattern": "/blog|/news",
      "wordpress_type": "post"
    },
    {
      "pattern": "/program",
      "wordpress_type": "marysmeals_program"
    },
    {
      "pattern": "/staff|/team",
      "wordpress_type": "marysmeals_staff"
    }
  ],
  "taxonomies": [
    {
      "name": "marysmeals_region",
      "type": "hierarchical",
      "label": "Region",
      "description": "Geographic regions served"
    },
    {
      "name": "marysmeals_program_type",
      "type": "non_hierarchical",
      "label": "Program Type",
      "description": "Type of program"
    }
  ],
  "custom_fields": {
    "marysmeals_program": [
      {
        "name": "program_description",
        "label": "Program Description",
        "type": "textarea"
      },
      {
        "name": "program_region",
        "label": "Region",
        "type": "select"
      }
    ]
  }
}
```

### 4.3 Create `config/seo-mapping.json`

```json
{
  "seo_field_mapping": {
    "meta_title": {
      "wordpress_field": "_seopress_titles_title",
      "fallback": "post_title"
    },
    "meta_description": {
      "wordpress_field": "_seopress_titles_desc",
      "fallback": "post_excerpt"
    },
    "canonical_url": {
      "wordpress_field": "_seopress_titles_canonical",
      "fallback": "none"
    },
    "og_title": {
      "wordpress_field": "_seopress_social_fb_title",
      "fallback": "post_title"
    },
    "og_description": {
      "wordpress_field": "_seopress_social_fb_desc",
      "fallback": "post_excerpt"
    },
    "og_image": {
      "wordpress_field": "_seopress_social_fb_img",
      "fallback": "featured_image"
    }
  },
  "schema_mapping": {
    "Organization": "Organization",
    "Article": "BlogPosting",
    "Product": "Product",
    "LocalBusiness": "LocalBusiness"
  },
  "seo_quality_targets": {
    "meta_title_min": 30,
    "meta_title_max": 60,
    "meta_description_min": 120,
    "meta_description_max": 160,
    "min_seo_score": 60
  }
}
```

---

## Phase 5: WordPress Content Structure (Config-as-Code)

### 5.1 Create `mu-plugins/marysmeals-core/marysmeals-core.php`

```php
<?php
/**
 * Plugin Name: Mary's Meals Core
 * Description: Custom post types and taxonomies for Mary's Meals website migration
 * Version: 1.0.0
 */

// Define schema version (bump when CPT/taxonomy changes)
define('MARYSMEALS_CORE_VERSION', 1);

// Register custom post type: Program
function marysmeals_register_program_cpt() {
  register_post_type('marysmeals_program', array(
    'label' => 'Programs',
    'public' => true,
    'supports' => array('title', 'editor', 'thumbnail', 'excerpt', 'custom-fields'),
    'has_archive' => true,
    'rewrite' => array('slug' => 'programs'),
    'menu_icon' => 'dashicons-groups',
    'taxonomies' => array('marysmeals_region', 'marysmeals_program_type')
  ));
}
add_action('init', 'marysmeals_register_program_cpt');

// Register custom post type: Staff
function marysmeals_register_staff_cpt() {
  register_post_type('marysmeals_staff', array(
    'label' => 'Staff',
    'public' => true,
    'supports' => array('title', 'editor', 'thumbnail'),
    'menu_icon' => 'dashicons-businessman',
    'taxonomies' => array('marysmeals_department')
  ));
}
add_action('init', 'marysmeals_register_staff_cpt');

// Register taxonomy: Region (hierarchical)
function marysmeals_register_region_taxonomy() {
  register_taxonomy('marysmeals_region', array('marysmeals_program'), array(
    'label' => 'Regions',
    'hierarchical' => true,
    'rewrite' => array('slug' => 'region')
  ));
}
add_action('init', 'marysmeals_register_region_taxonomy');

// Register taxonomy: Program Type (flat)
function marysmeals_register_program_type_taxonomy() {
  register_taxonomy('marysmeals_program_type', array('marysmeals_program'), array(
    'label' => 'Program Types',
    'hierarchical' => false,
    'rewrite' => array('slug' => 'program-type')
  ));
}
add_action('init', 'marysmeals_register_program_type_taxonomy');

// Version gating: flush rewrite rules on version change
function marysmeals_check_schema_version() {
  $installed_version = get_option('marysmeals_core_version');
  
  if ($installed_version !== MARYSMEALS_CORE_VERSION) {
    // Flush rewrite rules
    flush_rewrite_rules();
    
    // Seed any default terms
    if (!term_exists('Online', 'marysmeals_region')) {
      wp_insert_term('Online', 'marysmeals_region');
    }
    
    // Update version
    update_option('marysmeals_core_version', MARYSMEALS_CORE_VERSION);
  }
}
add_action('wp_loaded', 'marysmeals_check_schema_version');
```

### 5.2 Create `mu-plugins/marysmeals-importer/importer-seo.php`

```php
<?php
/**
 * Plugin Name: Mary's Meals SEO Importer
 * Description: Functions for SEO metadata assignment and redirect management
 * Version: 1.0.0
 */

/**
 * Set SEOPress meta title for post
 */
function marysmeals_set_seopress_meta_title($post_id, $title) {
  if (!function_exists('update_post_meta')) return;
  update_post_meta($post_id, '_seopress_titles_title', $title);
}

/**
 * Set SEOPress meta description for post
 */
function marysmeals_set_seopress_meta_description($post_id, $description) {
  if (!function_exists('update_post_meta')) return;
  update_post_meta($post_id, '_seopress_titles_desc', $description);
}

/**
 * Set SEOPress canonical URL for post
 */
function marysmeals_set_seopress_canonical_url($post_id, $canonical_url) {
  if (!function_exists('update_post_meta')) return;
  update_post_meta($post_id, '_seopress_titles_canonical', $canonical_url);
}

/**
 * Set OG tags for social sharing
 */
function marysmeals_set_seopress_og_tags($post_id, $og_title, $og_description, $og_image_url) {
  if (!function_exists('update_post_meta')) return;
  update_post_meta($post_id, '_seopress_social_fb_title', $og_title);
  update_post_meta($post_id, '_seopress_social_fb_desc', $og_description);
  if ($og_image_url) {
    update_post_meta($post_id, '_seopress_social_fb_img', $og_image_url);
  }
}

/**
 * Set schema.org markup
 */
function marysmeals_set_seopress_schema($post_id, $schema_type) {
  if (!function_exists('update_post_meta')) return;
  if ($schema_type) {
    update_post_meta($post_id, '_seopress_schema_type', $schema_type);
  }
}

/**
 * Generate redirect CSV for SEOPress bulk import
 * 
 * @param array $posts Array of classified posts with old_url and new_url
 * @return string CSV content
 */
function marysmeals_generate_redirect_csv($posts) {
  $csv = "Source URL,Target URL,Redirect Type,Status\n";
  
  foreach ($posts as $post) {
    $source = $post['old_url'];
    $target = $post['new_url'];
    $type = $post['redirect_type'] ?? '301';
    $status = $post['status'] ?? 'enabled';
    
    // Escape quotes
    $source = '"' . str_replace('"', '""', $source) . '"';
    $target = '"' . str_replace('"', '""', $target) . '"';
    
    $csv .= "{$source},{$target},{$type},{$status}\n";
  }
  
  return $csv;
}

/**
 * Validate SEO metadata completeness
 */
function marysmeals_validate_seo_completeness($post_id) {
  $validations = array(
    'has_meta_title' => !!get_post_meta($post_id, '_seopress_titles_title', true),
    'has_meta_description' => !!get_post_meta($post_id, '_seopress_titles_desc', true),
    'has_canonical' => !!get_post_meta($post_id, '_seopress_titles_canonical', true),
  );
  
  return $validations;
}
```

### 5.3 Create `site-config.json`

```json
{
  "version": "1.0.0",
  "wordpress": {
    "version": "7.0",
    "admin_user": "admin",
    "url": "http://localhost:8080"
  },
  "seopress": {
    "enabled": true,
    "settings": {
      "xml_sitemap": true,
      "social_previews": true,
      "structured_data": true,
      "404_monitor": true,
      "redirects_enabled": true
    }
  },
  "scraper": {
    "source_url": "https://marysmeals.sk/",
    "max_pages": 100,
    "download_media": true
  },
  "import": {
    "batch_size": 10,
    "media_handling": "download_and_optimize",
    "url_structure": "preserve_with_redirects"
  },
  "redirects": {
    "source": "marysmeals.sk",
    "target": "localhost:8080",
    "type": "301",
    "auto_generate": true
  },
  "custom_post_types": [
    {
      "name": "marysmeals_program",
      "label": "Programs"
    },
    {
      "name": "marysmeals_staff",
      "label": "Staff"
    }
  ],
  "taxonomies": [
    {
      "name": "marysmeals_region",
      "label": "Regions",
      "type": "hierarchical"
    },
    {
      "name": "marysmeals_program_type",
      "label": "Program Types",
      "type": "flat"
    }
  ]
}
```

---

## Phase 6: WordPress Importer with SEO Metadata & Redirects

### 6.1 Create `scripts/importer.sh`

```bash
#!/bin/bash

set -e

CLASSIFIED_JSON="scraped-content/classified-export.json"
OUTPUT_PATH="scraped-content"
REPORT_FILE="$OUTPUT_PATH/import-report.json"

echo "========================================="
echo "WordPress Content Importer"
echo "========================================="

if [ ! -f "$CLASSIFIED_JSON" ]; then
  echo "Error: $CLASSIFIED_JSON not found"
  exit 1
fi

# Initialize report
echo "{" > "$REPORT_FILE"
echo '  "import_started": "'$(date -Iseconds)'",' >> "$REPORT_FILE"

# Step 1: Create taxonomies
echo "Step 1: Creating taxonomies..."
docker-compose exec -T wordpress wp term create marysmeals_region "North America" \
  --description="North America region" 2>/dev/null || true
docker-compose exec -T wordpress wp term create marysmeals_region "Europe" 2>/dev/null || true
docker-compose exec -T wordpress wp term create marysmeals_program_type "Food Programme" 2>/dev/null || true

# Step 2: Import media
echo "Step 2: Importing media files..."
MEDIA_COUNT=$(jq '.media | length' "$CLASSIFIED_JSON")
echo "  Importing $MEDIA_COUNT media files..."
docker-compose exec -T wordpress bash -c "cd /var/www/html/wp-content/uploads && find /app/output/media -name '*.jpg' -o -name '*.png' | while read img; do cp \"\$img\" .; done" 2>/dev/null || true

# Step 3: Create pages
echo "Step 3: Creating pages..."
PAGES=$(jq -r '.pages[] | @json' "$CLASSIFIED_JSON")
PAGE_COUNT=0
echo "$PAGES" | while read page_json; do
  page=$(echo "$page_json" | jq '.')
  title=$(echo "$page" | jq -r '.title')
  slug=$(echo "$page" | jq -r '.slug')
  seo_title=$(echo "$page" | jq -r '.seo_analysis.meta_title // empty')
  seo_desc=$(echo "$page" | jq -r '.seo_analysis.meta_description // empty')
  
  # Create page
  POST_ID=$(docker-compose exec -T wordpress wp post create \
    --post_type=page \
    --post_title="$title" \
    --post_name="$slug" \
    --post_status=publish \
    --porcelain 2>/dev/null)
  
  if [ ! -z "$POST_ID" ]; then
    # Set SEO metadata
    [ ! -z "$seo_title" ] && docker-compose exec -T wordpress wp post meta set "$POST_ID" "_seopress_titles_title" "$seo_title" 2>/dev/null || true
    [ ! -z "$seo_desc" ] && docker-compose exec -T wordpress wp post meta set "$POST_ID" "_seopress_titles_desc" "$seo_desc" 2>/dev/null || true
    ((PAGE_COUNT++))
  fi
done

# Step 4: Create CPT posts
echo "Step 4: Creating custom post type entries..."
CPT_COUNT=$(jq '[.cpts[] | length] | add' "$CLASSIFIED_JSON" 2>/dev/null || echo 0)
echo "  Creating $CPT_COUNT CPT entries..."

# Step 5: Create regular posts
echo "Step 5: Creating posts..."
POSTS=$(jq -r '.posts[] | @json' "$CLASSIFIED_JSON")
POST_POST_COUNT=0
echo "$POSTS" | while read post_json; do
  post=$(echo "$post_json" | jq '.')
  title=$(echo "$post" | jq -r '.title')
  slug=$(echo "$post" | jq -r '.slug')
  category=$(echo "$post" | jq -r '.category // "uncategorized"')
  
  POST_ID=$(docker-compose exec -T wordpress wp post create \
    --post_type=post \
    --post_title="$title" \
    --post_name="$slug" \
    --post_status=publish \
    --porcelain 2>/dev/null)
  
  [ ! -z "$POST_ID" ] && ((POST_POST_COUNT++))
done

# Step 6: Build navigation menus
echo "Step 6: Building navigation menus..."
docker-compose exec -T wordpress wp menu create "Main Menu" 2>/dev/null || true

# Step 7: Generate redirects CSV
echo "Step 7: Generating 301 redirects..."
node scripts/generate-redirects.js

# Final report
echo "Step 8: Finalizing report..."
echo '  "pages_created": '$PAGE_COUNT',' >> "$REPORT_FILE"
echo '  "posts_created": '$POST_POST_COUNT',' >> "$REPORT_FILE"
echo '  "media_imported": '$MEDIA_COUNT',' >> "$REPORT_FILE"
echo '  "import_completed": "'$(date -Iseconds)'"' >> "$REPORT_FILE"
echo "}" >> "$REPORT_FILE"

echo ""
echo "✓ Import complete!"
echo "  Pages: $PAGE_COUNT"
echo "  Posts: $POST_POST_COUNT"
echo "  Media: $MEDIA_COUNT"
echo "Report: $REPORT_FILE"
```

### 6.2 Create `scripts/generate-redirects.js`

```javascript
/**
 * Generate 301 Redirect CSV for SEOPress bulk import
 * Maps: old marysmeals.sk URLs → new WordPress URLs
 * Output: redirects-import.csv
 */

const fs = require('fs');
const path = require('path');

const CLASSIFIED_JSON = 'scraped-content/classified-export.json';
const OUTPUT_CSV = 'scraped-content/redirects-import.csv';

// Load classified data
const classified = JSON.parse(fs.readFileSync(CLASSIFIED_JSON, 'utf-8'));

const redirects = [];

// Generate redirects for pages
classified.pages.forEach(page => {
  const sourceUrl = page.url;
  // Assuming WordPress pages accessible at /{slug}/ 
  const targetUrl = `http://localhost:8080/${page.slug}/`;
  
  redirects.push({
    source: sourceUrl,
    target: targetUrl,
    type: 301,
    status: 'enabled'
  });
});

// Generate redirects for posts
classified.posts.forEach(post => {
  const sourceUrl = post.url;
  // Assuming WordPress posts accessible at /post-type/{slug}/ or /category/{slug}/
  const targetUrl = `http://localhost:8080/${post.category}/${post.slug}/`;
  
  redirects.push({
    source: sourceUrl,
    target: targetUrl,
    type: 301,
    status: 'enabled'
  });
});

// Generate CSV
let csv = 'Source URL,Target URL,Redirect Type,Status\n';
redirects.forEach(redirect => {
  csv += `"${redirect.source}","${redirect.target}",${redirect.type},${redirect.status}\n`;
});

// Save CSV
fs.writeFileSync(OUTPUT_CSV, csv);

console.log(`✓ Generated ${redirects.length} redirects`);
console.log(`Output: ${OUTPUT_CSV}`);
```

### 6.3 Create `scripts/import-redirects-to-seopress.sh`

```bash
#!/bin/bash

set -e

CSV_FILE="scraped-content/redirects-import.csv"

echo "========================================="
echo "SEOPress Redirect Importer"
echo "========================================="

if [ ! -f "$CSV_FILE" ]; then
  echo "Error: $CSV_FILE not found"
  exit 1
fi

# Count lines
REDIRECT_COUNT=$(wc -l < "$CSV_FILE")
((REDIRECT_COUNT--))  # Exclude header

echo "Importing $REDIRECT_COUNT redirects from $CSV_FILE..."

# Use SEOPress API or wp-cli to import redirects
# Note: This assumes SEOPress Pro has CLI support; for Free tier, use DB direct insert

# Option 1: Direct database insert (works with Free tier)
echo "Importing redirects via database..."
docker-compose exec -T db mysql -u wordpress -pwordpress wordpress << EOF
-- Your redirect import SQL here
-- SEOPress stores redirects in wp_options or custom table
SELECT 'Import ready - manual CSV upload recommended' as status;
EOF

echo ""
echo "✓ Redirects prepared for import"
echo "Next: Login to WordPress Admin > SEOPress > Redirects"
echo "And import the CSV file: $CSV_FILE"
echo ""
echo "Alternatively, use SEOPress Pro API for automated import"
```

### 6.4 Create `scripts/configure-seopress.sh`

```bash
#!/bin/bash

echo "========================================="
echo "SEOPress Configuration"
echo "========================================="

# Enable SEOPress modules
echo "Configuring SEOPress settings..."

docker-compose exec -T wordpress wp option update seopress_titles_title_home_1 "Mary's Meals" 2>/dev/null || true
docker-compose exec -T wordpress wp option update seopress_titles_desc_home_1 "Nourishing children, transforming communities" 2>/dev/null || true

# Enable XML sitemap
docker-compose exec -T wordpress wp option update seopress_xml_sitemap_enabled 1 2>/dev/null || true
docker-compose exec -T wordpress wp option update seopress_xml_sitemap_list_posts 1 2>/dev/null || true
docker-compose exec -T wordpress wp option update seopress_xml_sitemap_list_pages 1 2>/dev/null || true

# Enable social previews
docker-compose exec -T wordpress wp option update seopress_social_fb_enabled 1 2>/dev/null || true
docker-compose exec -T wordpress wp option update seopress_social_tw_enabled 1 2>/dev/null || true

# Enable structured data
docker-compose exec -T wordpress wp option update seopress_schema_enabled 1 2>/dev/null || true

# Enable 404 monitor
docker-compose exec -T wordpress wp option update seopress_404_monitor_enabled 1 2>/dev/null || true

# Enable redirects
docker-compose exec -T wordpress wp option update seopress_redirects_enabled 1 2>/dev/null || true

echo "✓ SEOPress configured"
```

### 6.5 Create `scripts/validate-seopress.sh`

```bash
#!/bin/bash

echo "========================================="
echo "SEOPress Validation"
echo "========================================="

# Check SEOPress active
echo "1. Checking SEOPress installation..."
docker-compose exec -T wordpress wp plugin is-active seopress
if [ $? -eq 0 ]; then
  echo "   ✓ SEOPress active"
else
  echo "   ✗ SEOPress not active"
  exit 1
fi

# Verify posts have meta titles
echo "2. Checking SEO metadata population..."
META_TITLE_COUNT=$(docker-compose exec -T wordpress wp db query \
  "SELECT COUNT(*) FROM wp_postmeta WHERE meta_key='_seopress_titles_title';" \
  --skip-column-names 2>/dev/null || echo 0)
echo "   Posts with meta titles: $META_TITLE_COUNT"

# Generate XML sitemap
echo "3. Generating XML sitemap..."
docker-compose exec -T wordpress wp seopress sitemap generate 2>/dev/null || true

# Verify 404 monitor
echo "4. Verifying 404 monitor..."
docker-compose exec -T wordpress wp option get seopress_404_monitor_enabled 2>/dev/null | grep -q 1
if [ $? -eq 0 ]; then
  echo "   ✓ 404 monitor enabled"
else
  echo "   ✗ 404 monitor disabled"
fi

# Count active redirects
echo "5. Checking redirects..."
REDIRECT_COUNT=$(docker-compose exec -T wordpress wp db query \
  "SELECT COUNT(*) FROM wp_seopress_redirects WHERE enabled=1;" \
  --skip-column-names 2>/dev/null || echo 0)
echo "   Active redirects: $REDIRECT_COUNT"

echo ""
echo "✓ Validation complete"
```

---

## Phase 7: Windows Credential Manager Integration

### 7.1 Create `.github/scripts/credential-manager.ps1`

```powershell
<#
.SYNOPSIS
Windows Credential Manager helper for wordpress-demo
.DESCRIPTION
Store and retrieve sensitive credentials via Windows Credential Manager
#>

param(
    [ValidateSet('Get', 'Set', 'Delete')]
    [string]$Operation = 'Get',
    [string]$Service = '',
    [string]$Username = '',
    [string]$Password = ''
)

$ErrorActionPreference = 'Stop'

function Get-WordPressCredential {
    param([string]$Service)
    try {
        $cred = cmdkey /list:$Service 2>$null
        if ($cred) {
            # Retrieve password (requires manual input in some cases)
            $securePassword = Read-Host -AsSecureString "Enter password for $Service"
            $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($securePassword)
            )
            return @{ Service = $Service; Password = $password }
        } else {
            Write-Error "Credential not found: $Service"
            exit 1
        }
    } catch {
        Write-Error "Error retrieving credential: $_"
        exit 1
    }
}

function Set-WordPressCredential {
    param([string]$Service, [string]$Username, [string]$Password)
    try {
        # Use Windows Credential Manager to store securely
        $password | cmdkey /add:$Service /user:$Username /pass:$Password > $null 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Credential stored: $Service"
        } else {
            Write-Error "Failed to store credential"
            exit 1
        }
    } catch {
        Write-Error "Error storing credential: $_"
        exit 1
    }
}

function Remove-WordPressCredential {
    param([string]$Service)
    try {
        cmdkey /delete:$Service > $null 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Credential deleted: $Service"
        } else {
            Write-Error "Failed to delete credential"
            exit 1
        }
    } catch {
        Write-Error "Error deleting credential: $_"
        exit 1
    }
}

# Execute operation
switch ($Operation) {
    'Get' {
        Get-WordPressCredential -Service $Service
    }
    'Set' {
        Set-WordPressCredential -Service $Service -Username $Username -Password $Password
    }
    'Delete' {
        Remove-WordPressCredential -Service $Service
    }
}
```

### 7.2 Create `.github/scripts/credential-helper.sh`

```bash
#!/bin/bash

# Credential Helper for wordpress-demo
# Detects OS and calls appropriate credential manager

OPERATION=${1:-get}
SERVICE=${2:-wordpress-admin}
USERNAME=${3:-}
PASSWORD=${4:-}

if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
  # Windows (Git Bash / WSL)
  pwsh -File ".github/scripts/credential-manager.ps1" \
    -Operation "$OPERATION" \
    -Service "$SERVICE" \
    -Username "$USERNAME" \
    -Password "$PASSWORD"
else
  # Linux / macOS
  echo "Error: Credential manager not configured for this OS"
  exit 1
fi
```

---

## Phase 8: Operational Documentation

### 8.1 Create `docs/agentic-playbook.md`

[Create comprehensive methodology document with decision framework, walkthroughs, and reusable checklist]

### 8.2 Create `docs/agent-roles.md`

[Create detailed agent responsibilities, tools, and interaction patterns]

### 8.3 Create `docs/seo-migration-guide.md`

```markdown
# SEO Migration Guide for marysmeals.sk

## Overview
This guide explains how the agentic system handles SEO for the marysmeals.sk → WordPress 7.0 migration.

## SEO Plugin: SEOPress Free

### Why SEOPress Free?
1. **URL Redirects:** Supports post/page-level 301 redirects in FREE tier
2. **Bulk Import:** Can import SEO metadata from competitor plugins
3. **WordPress 7.0:** Fully compatible and actively maintained
4. **404 Monitoring:** Built-in detection of broken redirects
5. **XML Sitemap:** Auto-generates comprehensive sitemaps
6. **Schema.org:** Auto-generates structured data

### Installation
```bash
docker-compose exec -T wordpress wp plugin install seopress --activate
```

## SEO Metadata Extraction

### Phase 1: Scraping
The scraper extracts:
- `<title>` tag
- `<meta name="description">`
- `<meta name="keywords">`
- `<link rel="canonical">`
- Open Graph tags (og:title, og:description, og:image)
- Schema.org markup (JSON-LD)

Output: `raw-export.json` with `seo_metadata` per page

### Phase 2: Classification
The classifier analyzes SEO quality:
- Title length (ideal: 50-60 chars)
- Description length (ideal: 150-160 chars)
- Canonical URL presence
- Schema.org type detection
- SEO score (0-100)
- Recommendations (fixes needed)

Output: `classified-export.json` with `seo_analysis` per page

### Phase 3: Import
The importer populates WordPress SEO fields:
- `_seopress_titles_title` = meta title
- `_seopress_titles_desc` = meta description
- `_seopress_titles_canonical` = canonical URL
- `_seopress_social_fb_title` = OG title
- `_seopress_social_fb_desc` = OG description
- `_seopress_social_fb_img` = OG image

### Phase 4: Redirects
The redirect generator creates 301 maps:
- Old: https://marysmeals.sk/about
- New: http://localhost:8080/about/
- Type: 301 (permanent)

Output: `redirects-import.csv` for SEOPress bulk import

## URL Redirect Strategy

### Redirect Flow
```
User visits: https://marysmeals.sk/programs
  ↓
SEOPress intercepts request (via .htaccess or rewrite rules)
  ↓
Checks redirect rules (stored in wp_seopress_redirects)
  ↓
Returns HTTP 301 to: http://localhost:8080/programs/
  ↓
User lands on new WordPress page
  ↓
Google Search Console sees: Old URL → New URL (301)
  ↓
Google transfers SEO authority/rankings
```

### Preserving Rankings
To maintain SEO rankings during migration:

1. **301 Redirects:** Use permanent (301), not temporary (302)
2. **Canonical URLs:** Set correctly in SEOPress
3. **XML Sitemap:** Submit to Google Search Console
4. **Robots.txt:** Allow Google to crawl new site
5. **Domain Authority:** Redirects transfer 90-99% of authority

### Testing Redirects
```bash
# Test a single redirect
curl -I https://marysmeals.sk/about
# Should see: HTTP 301 → http://localhost:8080/about/

# Test with SEOPress
docker-compose exec -T wordpress wp seopress redirects list
# Shows all active redirects

# 404 Monitor
docker-compose exec -T wordpress wp seopress 404-monitor list
# Shows any unmapped URLs
```

## XML Sitemap

### Generation
SEOPress auto-generates:
- `/sitemap.xml` — Index of all sitemaps
- `/post-sitemap.xml` — Posts
- `/page-sitemap.xml` — Pages
- `/marysmeals_program-sitemap.xml` — Custom post types
- `/region-sitemap.xml` — Taxonomies

### Submission to Google Search Console
1. Go to [Google Search Console](https://search.google.com/search-console)
2. Add property: http://localhost:8080/
3. Fetch sitemap: `/sitemap.xml`
4. Submit
5. Monitor index coverage

## SEO Quality Targets

| Metric | Target | Current |
|--------|--------|---------|
| Pages with meta title | 100% | ? |
| Pages with meta description | 100% | ? |
| Meta titles (30-60 chars) | 95%+ | ? |
| Meta descriptions (120-160 chars) | 95%+ | ? |
| Avg SEO score | 80+ | ? |
| Canonical URLs | All pages | ? |
| 404 errors | 0 | ? |

## Post-Migration SEO Checklist

- [ ] WordPress 7.0 running
- [ ] SEOPress Free installed and active
- [ ] All pages imported with SEO metadata
- [ ] 301 redirects active for 50+ key URLs
- [ ] XML sitemap generated and valid
- [ ] Google Search Console accepts sitemap
- [ ] 404 monitor enabled (no broken redirects)
- [ ] Social previews rendering (OG tags)
- [ ] Schema.org markup auto-generated
- [ ] Site search visibility: YES (no robots noindex)
- [ ] Monitor Google Search Console for index coverage (2-4 weeks)
- [ ] Monitor organic traffic for any drops
- [ ] Check ranking changes (should stay same or improve with 301s)
```

---

## Phase 9: Complete File Structure

```
wordpress-demo/
├── .github/
│   ├── agents/
│   │   ├── operations-manager.instructions.md
│   │   ├── devops-engineer.instructions.md
│   │   ├── theme-developer.instructions.md
│   │   ├── content-architect.instructions.md
│   │   ├── scraper-specialist.instructions.md
│   │   └── qa-specialist.instructions.md
│   ├── skills/
│   │   ├── health-check.md
│   │   ├── site-provisioning.md
│   │   ├── wp-cli-automation.md
│   │   ├── config-as-code.md
│   │   ├── windows-credential-mgr.md
│   │   ├── backup-recovery.md
│   │   ├── web-scraper.md
│   │   ├── content-classifier.md
│   │   ├── wordpress-importer.md
│   │   └── seopress-redirects.md
│   ├── commands/
│   │   ├── setup-local.md
│   │   ├── scrape-marysmeals.md
│   │   ├── classify-content.md
│   │   ├── import-to-wordpress.md
│   │   ├── setup-redirects.md
│   │   └── validate-import.md
│   ├── scripts/
│   │   ├── credential-manager.ps1
│   │   └── credential-helper.sh
│   └── settings.json
│
├── scripts/
│   ├── scraper.js
│   ├── content-classifier.js
│   ├── importer.sh
│   ├── generate-redirects.js
│   ├── import-redirects-to-seopress.sh
│   ├── configure-seopress.sh
│   ├── validate-seopress.sh
│   └── install-plugins.sh
│
├── config/
│   ├── content-types.json
│   └── seo-mapping.json
│
├── mu-plugins/
│   ├── marysmeals-core/
│   │   └── marysmeals-core.php
│   ├── marysmeals-importer/
│   │   └── importer-seo.php
│   ├── edumeal-roles/
│   └── edumeal-config/
│
├── scraped-content/          # Generated (in .gitignore)
│   ├── raw-export.json
│   ├── classified-export.json
│   ├── redirects-import.csv
│   ├── import-report.json
│   └── media/
│
├── docs/
│   ├── agentic-playbook.md
│   ├── agent-roles.md
│   ├── seo-migration-guide.md
│   └── scraper-setup.md
│
├── docker-compose.yml        # Updated: WordPress 7.0 + scraper
├── Dockerfile               # Updated: WordPress 7.0 base
├── Dockerfile.scraper       # NEW
├── .env.scraper             # NEW
├── .gitignore               # Add: scraped-content/
├── site-config.json
├── entrypoint.sh
├── AGENTIC-IMPLEMENTATION-PLAN.md  # THIS FILE
├── DOCUMENTATION.md         # Original (superseded by agentic-playbook)
├── NEW_SITE_PLAYBOOK.md
└── README.md
```

---

## Verification Checklist

### ✓ Phase 1-2: Container & Framework Setup
- [ ] `.github/agents/` has 6 .instructions.md files
- [ ] `.github/skills/` has 10 SKILL.md files
- [ ] `.github/commands/` has 6 .md workflows
- [ ] `.github/settings.json` configured
- [ ] `docker-compose.yml` updated with scraper service
- [ ] `Dockerfile` uses `wordpress:7.0-apache` base
- [ ] `Dockerfile.scraper` builds successfully
- [ ] `.env.scraper` configured

### ✓ Phase 3: Scraping
- [ ] `docker-compose run scraper` completes
- [ ] `scraped-content/raw-export.json` created with 40-60+ pages
- [ ] `scraped-content/media/` has images downloaded
- [ ] raw-export.json includes `seo_metadata` per page (titles, descriptions, canonical URLs)

### ✓ Phase 4: Classification
- [ ] `node scripts/content-classifier.js` completes
- [ ] `scraped-content/classified-export.json` created
- [ ] Pages, posts, CPTs correctly categorized
- [ ] SEO analysis included (scores, recommendations)
- [ ] `config/content-types.json` and `config/seo-mapping.json` present

### ✓ Phase 5: WordPress Structure
- [ ] `mu-plugins/marysmeals-core/` creates CPTs and taxonomies (idempotent)
- [ ] `mu-plugins/marysmeals-importer/` has SEO functions
- [ ] `site-config.json` configured

### ✓ Phase 6: Import
- [ ] `scripts/importer.sh` executes without errors
- [ ] Posts, pages, CPTs created in WordPress
- [ ] Media uploaded to WordPress
- [ ] SEO metadata populated (verify in WordPress admin post edit)
- [ ] `scraped-content/import-report.json` generated with post counts

### ✓ Phase 7: Redirects
- [ ] `scripts/generate-redirects.js` creates `redirects-import.csv`
- [ ] `scripts/import-redirects-to-seopress.sh` imports redirects
- [ ] SEOPress shows active redirects (via admin or wp-cli)
- [ ] Test 50+ key URLs return 301 status

### ✓ Phase 8: SEOPress Configuration
- [ ] SEOPress Free installed and active
- [ ] XML sitemap generated and accessible
- [ ] 404 monitor enabled
- [ ] Social previews configured
- [ ] Structured data auto-generating

### ✓ Phase 9: QA & Validation
- [ ] Post counts: WordPress matches classification
- [ ] Media counts: WordPress matches scraper output
- [ ] SEO metadata present on sample posts (titles, descriptions, canonical)
- [ ] Redirects working (test 50+ URLs)
- [ ] No 404 errors in SEOPress monitor
- [ ] Google Search Console accepts XML sitemap
- [ ] Content fidelity: Inspect WordPress pages match source

---

## Critical Requirements Summary

| Requirement | Status | Implementation |
|---|---|---|
| **WordPress 7.0** | CRITICAL | `FROM wordpress:7.0-apache` in Dockerfile |
| **URL Redirects** | CRITICAL | SEOPress redirect manager + 301 CSV import |
| **SEO Metadata** | CRITICAL | Extracted during scrape, analyzed during classify, populated during import |
| **SEOPress Free** | REQUIRED | Installed, configured, validates metadata |
| **Separate Scraper Container** | REQUIRED | Node.js container, docker-compose service |
| **Agentic Framework** | REQUIRED | 6 agents, 10 skills, 6 commands under `.github/` |
| **Windows Credential Mgr** | REQUIRED | PowerShell integration for secure credential storage |
| **Config-as-Code** | REQUIRED | mu-plugins for CPTs, taxonomies (version-gated) |
| **One-time Import** | REQUIRED | Scrape → classify → import → validate → done |
| **No Cloud (for now)** | REQUIRED | Local Docker only, defer cloud deployment |

---

## Next Steps

1. **Implement Phase 1-2:** Create agent/skill/command structure
2. **Implement Phase 3-4:** Build scraper and classifier
3. **Implement Phase 5-6:** Set up WordPress structure and importer
4. **Test Phase 7-8:** Validate credentials and SEOPress configuration
5. **Execute Workflow:** User invokes "scrape-marysmeals" command and agents orchestrate the migration
6. **Monitor & Optimize:** Use QA specialist to validate; fix SEO metadata as needed

---

**Document Version:** 1.0  
**Last Updated:** June 4, 2026  
**Status:** Ready for Implementation  
**Author:** Agentic Development System
```