# OLGA Connect Database v2.3 Implementation Decisions

## Scope

This database package implements the persistence, integrity, migration and least-privilege boundaries in Database Architecture and Table-Level Design v2.3 and the MVP Architecture Implementation Guide v1.0. API behavior, Azure infrastructure, CIAM configuration, Blob Storage lifecycle policies, Service Bus topology, OpenAPI contracts and QA evidence remain owned by their respective delivery workstreams.

## Implemented decisions

- Replaced `chat.Attachment` with `storage.FileAsset` and `storage.FileAssetLink`. The new model supports chat files, verification evidence, privacy exports and NLP evaluation reports without assigning storage ownership to chat.
- Added `iam.Permission`, `iam.RolePermission` and `iam.AuthSession`. Azure SQL stores application authorization and session revocation state, not credentials or bearer and refresh tokens.
- Replaced plaintext identity subjects with encrypted ciphertext, a keyed deterministic lookup hash and an optional masked support hint.
- Added `consent.PrivacyRequestTask` so privacy completion is based on evidenced domain tasks rather than a single mutable status.
- Added `ops.SyncChange` with a durable sequence, member scope, tombstones and expiry for authorization-filtered mobile delta synchronization.
- Added versioned `ops.RetentionPolicy` and auditable `ops.RetentionExecution` records.
- Added database guards for polymorphic file-link integrity, privacy-request completion and active retention-policy immutability.
- Added an exact object-inventory verification, trusted-constraint checks, disabled-object checks and schema-version stamping.

## Security and Azure SQL implementation notes

- `storage.FileAsset.blob_path` is `nvarchar(1024)` and cannot be a safe Azure SQL index key because its maximum encoded size exceeds the 1,700-byte nonclustered-index key limit. `blob_path_hash` is the enforceable unique key. The file service must compare the full path after a hash match and treat a collision as a security event.
- `notification.PushToken.token_ciphertext` is not indexed. `token_fingerprint` is retained as a non-secret lookup and uniqueness value so encrypted provider tokens remain opaque at rest.
- The v2.2 upgrade refuses to transform populated plaintext `iam.MemberIdentity.provider_subject` values. An approved CIAM migration must generate ciphertext and keyed hashes before the contract migration removes plaintext.
- `storage.FileAssetLink` is polymorphic by design. A trigger verifies that each supported resource exists in its authoritative domain table; the owning service must still perform authorization before creating a link.
- Database roles grant service-owned schema access. Cross-schema grants are explicit. Application and worker identities are separate from migration and Microsoft Entra administration identities.

## Product values intentionally not activated

The following decisions remain configuration or product approvals and are not silently frozen by this package:

- Release 1 community and tenant scope.
- Production retention periods for messages, files, NLP data, feedback, audit evidence and privacy cases.
- Whether event registration is mandatory before Live Mode and the QA coarse-location policy.
- Production event-alert confidence, hourly and per-event limits and minimum alert interval.
- Notification channels, daily and hourly caps, retry schedules, time-to-live values and safety or account bypass rules.
- Profile-field visibility before and after connection acceptance.
- Production CIAM provider and required email or mobile verification policy.
- Azure SQL native vector support in the selected subscription and region.

`SeedMvpPolicies` remains disabled by default. Retention policies have no default production seed. Approved values should be introduced in a reviewed migration so the deployed configuration is reproducible and auditable.

## Deployment paths

- New database: run `deploy.ps1` or `deploy.sql`.
- Existing v2.2 database: restore a backup to a non-production environment and run `upgrade.ps1` or `upgrade_v2_2_to_v2_3.sql` first.
- Standalone SSMS or Azure Data Studio deployment: use `OLGA_Connect_AzureSQL_Full_Setup.sql` for a new empty database.

The upgrade path migrates legacy attachment rows before dropping `chat.Attachment`, verifies the copy, rebuilds constraints and indexes, installs v2.3 invariants and runs the same verification used by a clean deployment.
