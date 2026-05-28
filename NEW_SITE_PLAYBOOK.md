# New Agent-Managed Site Playbook (v3)

Operational guide for bringing a new WordPress site into the
claude-workspace fleet so that Claude Code agents can own most of its
lifecycle. Sized for the actual fleet: ~5 sites, one operator
(Ondrej), part-time effort.

> **v3 supersedes v2.** v2 specified enterprise process; v3 sizes the
> process to the operator. No version v4 until v3 has shipped at
> least one Tier-Standard site end-to-end.

---

## 0. Frame

### 0.1 Fleet reality

| Fact | Implication |
|---|---|
| ~5 sites, growing slowly | No need for fleet-wide automation that won't pay back across <10 sites |
| One operator + part-time effort | Tooling cost must be < running cost it saves |
| NGOs are stakeholders, not headcount | Sign-offs are best-effort, not gating |
| Agent context is metered $ | Per-deploy efficiency matters more than per-site polish |

### 0.2 Site Tiers

| Tier | Definition | Existing examples | Process subset |
|---|---|---|---|
| Campaign | One-page or microsite, annual or one-off, <10 pages | Tehlička | Skip Phase 0a + 0c; collapse to one Build phase |
| Standard | 10–50 pages, ongoing, single language | Savio | Full playbook |
| Complex | 50+ pages, multilingual, donation flows, or legacy migration | Mary's Meals, Domka | Full playbook + per-site addendum in `runbooks/{slug}.md` |

The Tier is recorded in `sites/{slug}.yaml` as `tier: campaign|standard|complex`.

### 0.3 Agent-Managed (binding)

A site is `agent-managed` when **all four** are true:

1. `tools.scripts.site_readiness --site X` PASSes 3 runs out of any 5 within 7 days. Transient failures (hosting maintenance, network) are whitelisted in `sites/{slug}/src_exceptions.yaml`.
2. Credentials resolve from Keychain for every env listed in YAML.
3. A documented rollback procedure exists in `sites/{slug}/SITE.md` § Rollback.
4. Operator has performed one manual rollback drill in the last 90 days.

Until all four hold, `status: bootstrap`.

---

## 1. Phases (advisory checklist, not hook-enforced)

Phases are a **checklist** in `sites/{slug}/PHASE.md`. The pre-tool hook checks one thing only: that the YAML has no `TBD` values before any deploy command runs. Everything else is operator discipline.

| Phase | Name | Required for tier | Typical duration |
|---|---|---|---|
| 0 | Brief & Lock | All; collapsed for Campaign | Campaign: 1 session. Standard: 1–2 weeks. Complex: 3+ weeks. |
| 1 | Provision | All | 1 week (gated on hosting + DNS access) |
| 2 | Scaffold | All | 1 day |
| 3 | Build | All | Campaign: 1 week. Standard: 2–4 weeks. Complex: 4+ weeks. |
| 4 | Cut-over | All | 1 day live + 24h watch |
| 5 | Steady | All | Indefinite |

### Phase 0 — Brief & Lock

- Stakeholder conversation logged in `sites/{slug}/BRIEF.md`
- Figma file URL + node IDs for visual-compare sections recorded in YAML (or "no Figma — Block patterns only" stated explicitly)
- Plugin list agreed against §2.2
- For Standard/Complex: legacy URL crawl → `legacy_inventory.csv`
- For Complex: REQUIREMENTS.md with locked decisions D1..Dn

### Phase 1 — Provision

- Hosting account, billing settled, SSH key deployed
- `sites/{slug}.yaml` zero `TBD`; schema-validated; connectivity smoke-test green
- DNS control mode recorded in YAML: `dns_control: api | portal | external`
- TLS provisioned or auto-issuance on; DNS baseline snapshotted

### Phase 2 — Scaffold

- `cp -r sites/_site_template/ sites/{slug}/`
- Fill `SITE.md`; runbook entry; Docker compose on next +100 port
- Keychain entries verified

### Phase 3 — Build

- For sites with Figma: section-by-section visual gate
- For sites without Figma: block-pattern catalog + per-page review
- A11y check (`axe-core` via Playwright) — manual if not installed; flagged as `[planned]`
- Per-page sign-off appended to `handoff.md`

### Phase 4 — Cut-over

Branches by `dns_control` mode (see §3.1 for full procedure). All modes share:

- T-48h: lower DNS TTL, final backup, restore-drill on disposable env
- T-0: deploy, switch origin, run smoke matrix
- T+24h: monitor

Per-mode rollback documented in `sites/{slug}/SITE.md` § Rollback.

### Phase 5 — Steady

- SRC runs weekly (not nightly — context cost)
- Quarterly retro via `/retrospective`
- `handoff.md` rotates quarterly

---

## 2. Stack rules

### 2.1 Hard rules (audited)

| # | Rule | Audited by |
|---|---|---|
| 1 | Block editor only (no Oxygen/Elementor/Bricks/Divi) | `stack_audit` [planned P1] — until built, checked at PR review |
| 2 | Default `wp_` table prefix unless documented exception | YAML field `db.table_prefix` must match live; manual check |
| 3 | SSH + WP-CLI working OR documented SFTP-only exception | Connectivity smoke-test |
| 4 | DNS controllable (`api`/`portal`); `external` mode allowed only with documented manual rollback | YAML schema check |
| 5 | TLS + HSTS on | `curl -sI` check, scripted later |

### 2.2 Plugin allowlist (categorized)

Same categories as v2, but **non-binding suggestions** rather than enforced allowlist. Per-site deviations recorded in `sites/{slug}/SITE.md` § Plugin Choices with rationale. Audit catches deviations, doesn't block.

| Category | Suggested options |
|---|---|
| SEO | Rank Math, Yoast |
| Forms | Contact Form 7, Fluent Forms |
| Security | Wordfence (free) — optional if hosting has WAF |
| Backup | UpdraftPlus, or workspace's own backup tool |
| Analytics | Matomo (preferred over GA for GDPR) |
| Consent | Complianz, CookieYes |
| Image opt | EWWW, ShortPixel |
| NGO-specific | Up to 3 (donations, CRM sync, newsletter) — record rationale |

### 2.3 Version pinning (manual until tooled)

- Pinned versions recorded in `sites/{slug}/wp-lock.json` (custom format: `{core, theme, plugins[]}` with version+slug+sha256 of zip)
- Snapshot tool `wp_lock_snapshot` is [planned P1]
- Until built: hand-update on accepted-update events

---

## 3. Per-mode procedures

### 3.1 DNS control modes

| Mode | Example site | Cut-over | Rollback |
|---|---|---|---|
| `api` | WebSupport sites with registrar API | Agent runs DNS swap | Agent reverts via API; <5 min |
| `portal` | Mediahost / M365 | Operator runs DNS swap via portal | Operator reverts via portal; 5–15 min |
| `external` | DNS held by third party outside operator control | Operator coordinates with third party | Manual; SLA-dependent |

### 3.2 Site tier mapping (initial)

| Site | Tier | Notes |
|---|---|---|
| savio-sk | Standard | Multilingual SK+EN — extends Standard with §2.2 i18n addendum |
| domka-sk | Complex | Oxygen builder = permanent §2.1 Rule 1 exception, documented in runbook |
| tehlicka-sk | Campaign | Fresh build, Block patterns + Figma |
| marysmeals-sk | Complex | 3-layer legacy + M365 DNS (`dns_control: external`) |
| edumeal-org | Standard | v3 layout adopted 2026-05-26 (first site on v3) — see `sites/edumeal-org/PHASE.md` |

---

## 4. Documents

Every artifact has one owner. Doc count kept minimal.

| File | Role | Source of truth? | Owner |
|---|---|---|---|
| `sites/{slug}.yaml` | Config (connection, tier, DNS mode, env list) | **Yes** | Operator |
| `sites/{slug}/SITE.md` | Operating model: how to deploy, rollback, monitor; § Quickstart for new operator | Yes (operations) | Agent |
| `sites/{slug}/BRIEF.md` | Phase 0 brief + locked decisions | Yes (intent) | Operator |
| `sites/{slug}/PHASE.md` | Phase checklist; current phase marked | Yes (process state) | Agent |
| `sites/{slug}/handoff.md` | Append-only session log | Yes (history) | Agent |
| `sites/{slug}/wp-lock.json` | Pinned core/theme/plugin versions | Yes (versions) | Tool |
| `sites/{slug}/legacy_inventory.csv` | Pre-migration URL crawl | Yes (legacy) | Tool |
| `sites/{slug}/redirects.csv` | 301 map | Yes (redirects) | Tool+operator |
| `runbooks/{slug}.md` | Quirks, incidents, exceptions to playbook | Yes (narrative) | Operator+agent |
| `docker/sites/{slug}.yml` | Local dev | — | Agent |

**Dropped from v2:** `status.json`, `inventory.md` (rolled into SITE.md § Live State, regenerated on demand), `migration_map.md` (rolled into BRIEF.md), `design_tokens.json` (rolled into SITE.md or omitted), `dns_baseline.json` (rolled into runbook).

Credentials in macOS Keychain `wp-{slug}-{type}-{env}`, account `claude-workspace`. Existing secret-detector hook is the enforcement; no new validator.

---

## 5. Ownership

One Owner field per artifact. Single accountable person.

| Artifact / action | Owner |
|---|---|
| All ops, deploys, RACI in v2 | **Ondrej** |
| NGO-specific sign-off (content, brand) | NGO contact per site, recorded in BRIEF.md |
| Production deploy approval | Ondrej (cannot be agent-only) |
| Bus-factor backup | **Currently none** — see §8 |

---

## 6. Agent operating constraints

Only constraints that exist or are reasonable:

- Production deploys require human approval each session (per CLAUDE.md, already enforced)
- Pre-tool secret-detector hook (already enforced)
- `OPS_FREEZE` env in `~/.claude/settings.json` as kill switch for all writes [planned P1]
- Per-session token budget logged in `logs/playbook-metrics.jsonl` for review, not enforcement

Removed from v2: arbitrary file-count limits, paging, on-call.

---

## 7. Incident response

When a site is broken or compromised:

1. **Detect** — `/monitor {site}` red, donor complaint, or alert.
2. **Contain** — if compromise suspected, take site to maintenance mode via hosting panel or `.htaccess`. Don't deploy.
3. **Diagnose** — read `runbooks/{slug}.md` first; check `handoff.md` for recent changes; review `logs/tool-calls.jsonl` for agent-driven changes.
4. **Recover** — `/backup` first, then either restore from last verified backup or hotfix forward.
5. **Comms** — Ondrej notifies NGO contact per `sites/{slug}/BRIEF.md` § NGO contact.
6. **Retro** — append to `runbooks/{slug}.md` § Incidents.

No paging. No on-call. Detection is operator-initiated until monitoring is automated.

---

## 8. Continuity (bus factor)

Currently a single point of failure (Ondrej). Minimum mitigations:

- `sites/{slug}/SITE.md` § Quickstart written so a competent WP operator can take over within 4 hours
- Credentials documented in Keychain naming convention (not the values; just where they live)
- Second operator: **not yet named**. Action P1: identify and onboard one volunteer or contractor as backup operator. Until then, document this as accepted risk.

---

## 9. Decommissioning

When a site retires (campaign ended, NGO dissolved):

1. Final backup with 7-year retention (NGO accountability)
2. DNS: park, redirect to NGO main site, or release per BRIEF.md decision
3. Site files: move repo entries to `sites/_archive/{slug}/` with date
4. Runbook entry: `runbooks/_archive/{slug}.md` with cause of decommission

---

## 10. Tradeoffs (no growth, just honesty)

| Tradeoff | Cost | Mitigation |
|---|---|---|
| Single operator | Bus factor = 1 | §8; aim for 2 by Q4 2026 |
| Tooling cost > saving at current fleet size | Some §11 items may never ship | Strict P0/P1/P2; don't build P2 unless fleet doubles |
| No designer-friendly WP page builder | Layouts are code | Block patterns + Figma-first |
| Off-platform DNS (M365) | Manual cut-over | `dns_control: portal/external` modes; per-site procedure |
| Markdown-driven process | Drift between docs and reality | Quarterly retro reviews handoff vs reality |
| Agent context cost grows with doc count | Each session reads more | v3 dropped 4 doc files from v2 |

---

## 11. P0 / P1 / P2 — build in this order

### P0 (build now; blocks everything else)

| # | Deliverable | Why P0 | Estimate |
|---|---|---|---|
| 1 | `tools.scripts.site_readiness` (SRC runner, MVP) — bash script wrapping existing `/backup`, `/deploy`, `/verify`, `/monitor`; outputs PASS/FAIL with reasons | Makes `agent-managed` measurable; everything else is fluff without it | 1–2 days |
| 2 | `sites/_schema.yaml` strict mode (no `TBD` allowed at Phase 1 exit) + pre-tool hook check | Catches the failure mode (Tehlička/MM) of "agent-managed YAML with TBD creds" | 0.5 day |
| 3 | Site tier field added to all five YAMLs; tier table populated in §3.2 | Half the over-engineering disappears once tiers are recognized | 0.5 day |

### P1 (build after P0 ships, when value is clear)

| # | Deliverable | Estimate |
|---|---|---|
| 4 | `wp_lock_snapshot` tool | 1 day |
| 5 | `stack_audit` tool | 1 day |
| 6 | `OPS_FREEZE` kill switch via settings.json | 0.5 day |
| 7 | Retrofit Domka with SITE.md additively | 1 day |
| 8 | Audit edumeal-org against this playbook | 0.5 day |
| 9 | First end-to-end Tehlička run as v3 validation | 1–2 weeks |

### P2 (if-ever; build only if fleet doubles or pain is real)

| # | Deliverable |
|---|---|
| 10 | `phase_promote` hook with refusal logic |
| 11 | `security_audit` tool (TLS+HSTS+headers) |
| 12 | `inventory_snapshot` tool |
| 13 | `content_parity_check` tool |
| 14 | `redirect_audit` tool |
| 15 | `legacy_crawl` tool |
| 16 | Metrics review automation |

---

## 12. What still requires humans (unchanged from v2)

Brand voice, copywriting, photo selection; NGO sign-off; legal/GDPR review; a11y audit; translation QA; donation gateway terms; DNS cut-over (portal/external modes); hosting account creation; paid-plugin licensing; production deploy approval per session; incident comms to donors.

---

## 13. Repository boundaries (unchanged from v2)

`claude-workspace`: site YAML, ops docs, agent runbooks/skills/hooks, backup/deploy/monitor tooling, logs.

`copilot-workspace`: theme PHP/CSS/JS, block patterns, design assets, build artifacts.

Bind mount preferred over submodule (lower agent friction).

---

## Changelog

- **v3 (2026-05-26)** — Tiered sites (Campaign/Standard/Complex); replaced enforced phase gates with advisory checklists; named single Owner; cut doc count by 4; added incident response, decommissioning, continuity; split roadmap into P0/P1/P2 with explicit "don't build P2 unless fleet grows".
- **v2 (2026-05-26)** — Enterprise specification; SRC, hook-enforced gates, RACI.
- **v1 (2026-05-26)** — Manifesto.
