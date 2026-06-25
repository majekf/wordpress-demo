# Redirect Strategy Investigation Results

## Investigated legacy patterns
- Reviewed the live marysmeals.sk homepage and sitemap structure.
- Observed legacy URLs using .php extensions, a root index page, archive-style news routes, and extensionless paths.
- Confirmed that query-string-driven entry points such as /podpora.php?b=1 are relevant for the real migration.

## Test environment
- WordPress: 6.7.2-php8.3-apache
- MySQL: 8.0.36
- WP-CLI: 2.11.0-php8.3
- Base URL: http://localhost:8081

## Method availability
- Method A (wp redirection add): unavailable
- Method B (Red_Item::create): available
- Method C (bulk Red_Item::create loop): available
- Method D (.htaccess): available

## Recommendation
- For a migration of this size, use Method C as the import workflow for reviewable redirect artifacts.
- Keep Method D as the performance-oriented fallback for static, high-volume routes such as old .php URLs and archive pages.
- Use Method B during development and validation, but prefer Method C for bulk imports and Method D for production hardening.

## Summary
- Passed: 12
- Failed: 0
