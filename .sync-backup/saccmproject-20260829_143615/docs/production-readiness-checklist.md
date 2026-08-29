# SACCM Production Readiness Checklist

Last reviewed: 2026-05-25

## Go / No-Go

Status: 96% go-live-ready from repository automation and release tooling. Final 4% requires executing the documented preflight, backup, staging smoke, and HTTPS deployment checks against the actual production/staging environment.

## Test Result Summary

Readiness: 96% go-live-ready.

### Ready / Passed

- Backend guard suite passed: `npm test` covers repo hygiene, SQL-safety static guard, route-auth static guard, report unit smoke, and register ledger smoke.
- Backend HTTP e2e passed locally when intentionally allowed against a local non-test DB: auth-boundary, approval flow, and expense create/update flow.
- Backend HTTP e2e DB-safety guard passed: scripts refuse empty/unsafe `DB_NAME` unless the operator explicitly sets `ALLOW_E2E_NON_TEST_DB=true`.
- Backend route/auth hardening passed static and HTTP checks: protected expense, approval, finance-compliance, and report endpoints reject missing/invalid tokens.
- SQL regression guards passed: high-risk raw `INSERT` concatenation and legacy raw pagination patterns are blocked by `npm test`.
- Repository hygiene guard passed after untracking runtime artifacts: `.env`, `node_modules`, local SQLite DBs, `.dart_tool`, signing secrets, and build outputs are blocked from tracked files.
- Registry/backend production config validation is implemented and negative-tested against placeholder templates; positive validator smoke passed with synthetic safe values.
- Release script syntax checks passed for production config preflight, backup wrapper, go-live preflight, frontend release preflight, and deployed endpoint verifier.
- Frontend validation has passed previously: `flutter pub get`, `flutter analyze`, and `flutter test`.
- Release build preflight is ready: Android signing values, HTTPS API/Registry URLs, `pubspec.lock`, generated Flutter plugin files, and artifact manifest/checksums are enforced.
- Operational release tooling is ready: config preflight, MySQL backup script, go-live preflight, staging smoke runner, deployed endpoint verifier, and release artifact manifest/checksum generation.

### Still Required Before 100%

- Run `release/scripts/check-production-config.ps1` against real backend and registry `.env` files with rotated production secrets.
- Run `release/scripts/backup-mysql.ps1` and confirm restorable backups for backend master/school DBs and registry DB.
- Deploy backend and registry behind the real HTTPS reverse proxy with production CORS origins and `TRUST_PROXY=true` where applicable.
- Run `release/scripts/check-deployed-endpoints.ps1` against the deployed backend `/saccapi` and registry `/registryapi` URLs.
- Run `npm run test:e2e:http:staging` against the actual disposable staging DB and HTTPS staging endpoint.
- Build a release package with real Android signing keys and verify generated `manifest.json` / `SHA256SUMS.txt`.
- Keep raw SQL aggregate/report expressions on the incremental cleanup backlog; current exposure is reduced by route auth, parameterized filters, bounded date ranges, and static SQL guards.

### Expected Local Failure

- `npm run test:e2e:expense-http` fails when `DB_NAME` is empty or unsafe. This is expected and confirms the DB-safety guard is protecting against accidental writes to an unknown/production database.

## Completed Gates

- Backend and Registry HTTP hardening enabled: Helmet, rate limit, compression, restricted production CORS, request body limits.
- `/saccapi/setup/*` disabled in production unless `ENABLE_SETUP_ROUTES=true` and a setup/internal secret is provided.
- Runtime `.env` is ignored and the committed backend `.env` has been removed from source control.
- Backend and Registry now fail fast in `NODE_ENV=production` when required secrets/config still use placeholders or are too short.
- Registry startup/keygen refuses known backend database names (`sacc`, `sacc_master`, `saccm_master`) unless explicitly overridden, preventing mixed migration histories.
- Production login blocks seeded `admin/admin1234` and `officer/officer1234` unless `ALLOW_DEFAULT_CREDENTIALS=true`.
- High-risk finance, register, user, party, report-adjacent, and sync routes now enforce a valid token at route boundary.
- User listing no longer returns password hashes.
- Income and expense header/subline/cheque writes are wrapped in transactions.
- Backend and Registry production dependency audits report zero vulnerabilities with the npmjs audit endpoint.
- CI now runs backend migration/tests with MySQL and registry migration/keygen smoke with MySQL.
- Backend HTTP e2e smoke now covers approval and expense create/update flows against a live server.
- Frontend session token, remembered password, and license admin secret are stored via secure storage with migration from legacy preferences.
- Android release builds require a real signing configuration and no longer fall back to debug signing.
- Editable API URL settings now feed the runtime API base used by remote data sources.
- SQLite downgrade now fails fast instead of deleting the local database, and report sync failures surface warnings.
- Tracked Flutter `.dart_tool` and local SQLite runtime artifacts have been removed from the repo index and ignored.
- High-risk master-data create paths no longer build INSERT statements by concatenating request fields.
- Legacy list pagination reads that used raw `SELECT ... LIMIT` SQL have been converted to Knex builders in master/sub services.
- Historical sub-row insert helpers no longer build raw `INSERT` SQL from request/subdata fields.
- Backend `npm test` now includes a static SQL-safety guard to prevent reintroducing raw INSERT concatenation or legacy raw pagination patterns.
- Report/compliance date filters now use bounded ranges instead of `DATE(...)` / `DATE_FORMAT(...)` predicates where practical, preserving indexes and reducing raw SQL surface.
- Backend HTTP e2e now includes an auth-boundary smoke test for protected expense, approval, finance-compliance, and report endpoints with missing/invalid tokens.
- Backend `npm test` now includes a static route-auth guard for high-risk route boundaries and mutating route handlers.
- Backend HTTP e2e runners now refuse non-test database names unless `ALLOW_E2E_NON_TEST_DB=true` is set intentionally, reducing the risk of destructive smoke tests against real data.
- Backend expense HTTP e2e now explicitly deletes generated child rows and test-only master rows during cleanup instead of relying on implicit cascade behavior.
- Backend `npm test` now includes a repository hygiene guard that fails if tracked files include runtime `.env`, `node_modules`, Flutter local DB/tooling artifacts, Android signing secrets, or build outputs.
- Release tooling now includes `release/scripts/check-production-config.ps1` / `.js` to verify backend and registry production `.env` files before go-live without printing secret values.
- Release tooling now includes `release/scripts/backup-mysql.ps1` for pre-migration/go-live MySQL backups, and generated `release/backups/` output is ignored.
- Backend now includes `npm run test:e2e:http:staging`, a remote staging smoke runner that requires an HTTPS `/saccapi` base URL and a safe staging/test database name.
- Release tooling now includes `release/scripts/go-live-preflight.ps1`, a one-command gate for production config checks, backend guard suite, and optional remote staging smoke.
- Frontend release builds now run `frontend-release-preflight.ps1` to enforce HTTPS API/Registry URLs, real Android signing values, `pubspec.lock`, and clean generated Flutter plugin files.
- Release tooling now includes deployed endpoint verification for HTTPS, health JSON, security headers, and non-wildcard CORS on backend/registry URLs.
- Release builds now generate `manifest.json` and `SHA256SUMS.txt` for distributed Windows/Android artifacts.

## Required Deployment Inputs

- `SECRETKEY` must be long random material, unique per environment, and at least 32 characters.
- `INTERNAL_API_SECRET`, `SETUP_API_SECRET` (only if setup routes are enabled), and `LICENSE_ADMIN_SECRET` must be at least 24 characters, unique, and stored outside Git.
- `CORS_ORIGIN` must list only trusted browser origins; native desktop/mobile clients are not CORS-dependent.
- Database users should use least privilege. Root credentials should only be used during provisioning.
- Registry `DB_NAME` must be separate from the online backend DB, for example `saccm_registry`.
- Run backend and registry behind HTTPS in production.

## Verified Commands

- `backend`: `npm ci`
- `backend`: selected `node --check` validation for changed entrypoints/routes/services
- `backend`: `npm run migrate`
- `backend`: `npm test`
- `backend`: `npm run test:e2e:http` (`ALLOW_E2E_NON_TEST_DB=true` is required for intentional local runs against a non-test DB)
- `backend`: `npm run test:e2e:http:staging` guard validation for missing/invalid staging URL
- `backend`: `npm audit --omit=dev --registry=https://registry.npmjs.org`
- `registry-backend`: `npm ci`
- `registry-backend`: selected `node --check` validation for changed entrypoints/services/scripts
- `registry-backend`: `npm run migrate`
- `registry-backend`: `node scripts/keygen.js --name "โรงเรียนทดสอบ Production"`
- `registry-backend`: `npm audit --omit=dev --registry=https://registry.npmjs.org`
- `release`: `node release/scripts/check-production-config.js --backend-env release/templates/.env.production.example --registry-env registry-backend/.env.example` fails as expected on placeholder templates
- `release`: positive production config validator smoke via exported `check-production-config.js` functions
- `release`: selected release script syntax checks, including production config preflight and backup wrapper
- `release`: selected release script syntax checks, including go-live preflight wrapper
- `release`: selected frontend release preflight syntax/negative checks
- `release`: deployed endpoint verifier syntax/URL guard checks
- `forntend`: `flutter pub get`
- `forntend`: `flutter analyze`
- `forntend`: `flutter test`

## Remaining Risks

- Some services still contain raw SQL for aggregate/report expressions such as `SUM`, `COALESCE`, `CONCAT`, and monthly `DATE_FORMAT` grouping. Route auth, parameterized filters, bounded date ranges, and the static SQL-safety guard reduce exposure; remaining expression cleanup can continue incrementally.
- HTTP e2e tests now cover auth-boundary, approval, and expense flows locally/CI; the staging smoke runner is ready, but final go-live still requires running it against the actual disposable staging DB and deployed HTTPS endpoint.
- Production cannot be marked 100% complete until real `.env` secrets, reverse proxy HTTPS, database backups, and staging smoke evidence are verified outside the local development machine.
