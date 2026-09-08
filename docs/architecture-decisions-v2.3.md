# OLGA Connect Database v2.3 Implementation Decisions

## Scope

This database package implements the persistence, integrity, migration and least-privilege boundaries in Database Architecture and Table-Level Design v2.3 and the MVP Architecture Implementation Guide v1.0. API behavior, Azure infrastructure, CIAM configuration, Blob Storage lifecycle policies, Service Bus topology, OpenAPI contracts and QA evidence remain owned by their respective delivery workstreams.

## Implemented decisions

- Replaced `chat.Attachment` with `storage.FileAsset` and `storage.FileAssetLink`. The new model supports chat files, verification evidence, privacy exports and NLP evaluation reports without assigning storage ownership to chat.
- Added `iam.Permission`, `iam.RolePermission` and `iam.AuthSession`. PostgreSQL stores application authorization and session revocation state, not credentials or bearer and refresh tokens.
- Replaced plaintext identity subjects with encrypted ciphertext, a keyed deterministic lookup hash and an optional masked support hint.
- Added `consent.PrivacyRequestTask` so privacy completion is based on evidenced domain tasks rather than a single mutable status.
- Added `ops.SyncChange` with a durable sequence, member scope, tombstones and expiry for authorization-filtered mobile delta synchronization.
- Added versioned `ops.RetentionPolicy` and auditable `ops.RetentionExecution` records.
- Added database guards for polymorphic file-link integrity, privacy-request completion and active retention-policy immutability.
- Added an exact object-inventory verification, trusted-constraint checks, disabled-object checks and schema-version stamping.

## Security and PostgreSQL implementation notes

- `storage.file_asset.blob_path` can exceed PostgreSQL B-tree entry limits. `blob_path_hash` is the enforceable unique key; the file service compares the full path after a hash match and treats a collision as a security event.
- `notification.PushToken.token_ciphertext` is not indexed. `token_fingerprint` is retained as a non-secret lookup and uniqueness value so encrypted provider tokens remain opaque at rest.
- The v2.2 upgrade refuses to transform populated plaintext `iam.MemberIdentity.provider_subject` values. An approved CIAM migration must generate ciphertext and keyed hashes before the contract migration removes plaintext.
- `storage.FileAssetLink` is polymorphic by design. A trigger verifies that each supported resource exists in its authoritative domain table; the owning service must still perform authorization before creating a link.
- NOLOGIN database roles grant service-owned schema access. Cross-schema grants are explicit. Application and worker identities remain separate from migration and Microsoft Entra administration identities.

## Product values intentionally not activated

The following decisions remain configuration or product approvals and are not silently frozen by this package:

- Release 1 community and tenant scope.
- Production retention periods for messages, files, NLP data, feedback, audit evidence and privacy cases.
- Whether event registration is mandatory before Live Mode and the QA coarse-location policy.
- Production event-alert confidence, hourly and per-event limits and minimum alert interval.
- Notification channels, daily and hourly caps, retry schedules, time-to-live values and safety or account bypass rules.
- Profile-field visibility before and after connection acceptance.
- Production CIAM provider and required email or mobile verification policy.
- HNSW activation only after representative PostgreSQL latency and recall evidence.

`SeedMvpPolicies` remains disabled by default. Retention policies have no default production seed. Approved values should be introduced in a reviewed migration so the deployed configuration is reproducible and auditable.

## Deployment paths

- New database: run `deploy.ps1` or `deploy.sql`.
- Existing v2.2 SQL Server database: use a separately reviewed cross-engine data migration; legacy upgrade scripts are not PostgreSQL deployment inputs.
- Standalone deployment: use `OLGA_Connect_PostgreSQL_Full_Setup.sql` for a new empty database.

The cross-engine migration must preserve legacy attachments, validate row counts and hashes, and pass the same PostgreSQL verification used by a clean deployment before cutover.
