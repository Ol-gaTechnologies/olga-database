# OLGA Connect Azure SQL deployment package

This package creates the OLGA Connect Release 1 Azure SQL objects defined by Database Architecture and Table-Level Design v2.3 and the MVP Architecture Implementation Guide v1.0. Use the baseline for a new database and the versioned upgrade manifest for a v2.2 database.

## Package contents

- `001_schemas_sequences.sql`: 13 schemas plus chat and mobile-sync sequences.
- `010_tables.sql`: all 66 documented v2.3 product tables.
- `020_constraints_indexes.sql`: foreign keys, checks, unique rules and critical access-path indexes.
- `025_invariants.sql`: cross-row and polymorphic integrity guards for files, privacy completion and active retention policies.
- `030_views.sql`: four controlled security/integration views.
- `040_procedures.sql`: eight controlled workflow procedures.
- `050_seed.sql`: roles, `ranking-v1`, and optional provisional QA notification policies.
- `060_security.sql`: least-privilege database roles and grants.
- `070_bind_identities.template.sql`: Entra managed-identity binding template; excluded from automatic deployment.
- `090_verify.sql`: post-deployment completeness and trust checks.
- `deploy.sql`: SQLCMD-mode deployment manifest.
- `deploy.ps1`: Entra-authenticated deployment wrapper.
- `migrations/002_v2_2_to_v2_3_expand.sql` and `migrations/002_v2_2_to_v2_3_contract.sql`: reviewed expand/contract upgrade steps.
- `upgrade_v2_2_to_v2_3.sql` and `upgrade.ps1`: SQLCMD and PowerShell upgrade entry points for the previous baseline.
- `docs/architecture-decisions-v2.3.md`: implemented boundaries, intentional Azure SQL adaptations and product values that remain unapproved.
- `OLGA_Connect_AzureSQL_Full_Setup.sql`: single standalone setup script for SSMS, Azure Data Studio, or another client that supports `GO` batches.

## Details needed before Azure deployment

Obtain the subscription ID, tenant ID, resource group, Azure region, SQL logical-server name, database name, Microsoft Entra administrator object ID, target service objective, network access approach, and the managed identity names for each deployed service.

The SQL scripts do not contain subscription IDs, passwords, connection strings or secrets. Azure infrastructure provisioning and private networking should be reviewed separately before deployment.

## Create the Azure SQL database

Use a company-controlled Microsoft Entra tenant and subscription. The recommended test baseline is an Entra-only logical SQL server, TLS 1.2 or later, an Azure SQL Database sized after a cost review, and private network access. The examples below use placeholders and do not run automatically.

1. Sign in and select the approved subscription.

```powershell
az login --tenant '<tenant-id>'
az account set --subscription '<subscription-id>'
```

2. Create the resource group.

```powershell
az group create --name 'rg-olga-test' --location '<azure-region>'
```

3. Create the logical server with Microsoft Entra-only authentication. Use an Entra group as administrator where possible.

```powershell
az sql server create `
  --name '<globally-unique-server-name>' `
  --resource-group 'rg-olga-test' `
  --location '<azure-region>' `
  --enable-ad-only-auth true `
  --external-admin-principal-type Group `
  --external-admin-name '<entra-admin-group-name>' `
  --external-admin-sid '<entra-admin-group-object-id>' `
  --minimal-tls-version 1.2 `
  --enable-public-network false
```

4. Review available database editions in the selected region, then create the test database. `S0` is shown only as a simple starting example; choose the SKU after workload and cost review.

```powershell
az sql db list-editions --location '<azure-region>' --output table
az sql db create `
  --resource-group 'rg-olga-test' `
  --server '<globally-unique-server-name>' `
  --name 'olga-connect-test' `
  --service-objective S0 `
  --backup-storage-redundancy Local
```

5. Configure connectivity. Private Endpoint is preferred. If a temporary test workstation firewall rule is approved instead, allow only that workstation's public IP and remove the rule after deployment. Do not enable the broad `0.0.0.0` "Allow Azure services" rule as the default.

6. Confirm the server and database exist.

```powershell
az sql server show --resource-group 'rg-olga-test' --name '<globally-unique-server-name>'
az sql db show --resource-group 'rg-olga-test' --server '<globally-unique-server-name>' --name 'olga-connect-test'
```

Microsoft references: [Azure SQL database CLI](https://learn.microsoft.com/cli/azure/sql/db), [Microsoft Entra administrator](https://learn.microsoft.com/cli/azure/sql/server/ad-admin), and [Azure SQL firewall guidance](https://learn.microsoft.com/azure/azure-sql/database/firewall-configure).

## Deploy the database objects

Prerequisites: network access to the SQL endpoint, Microsoft Entra database administrator access, and `sqlcmd` installed.

```powershell
.\deploy.ps1 -ServerFqdn '<server>.database.windows.net' -DatabaseName '<database>'
```

To add provisional QA notification policies, pass `-SeedMvpPolicies 1`. Leave this disabled for production until the product/security defaults are approved.

After the workload managed identities exist, copy `070_bind_identities.template.sql`, replace the placeholders, review the role mapping and execute it as the Entra administrator.

## Upgrade a v2.2 database

Take a backup or export, restore it to a non-production environment and run the upgrade there first.

```powershell
.\upgrade.ps1 -ServerFqdn '<server>.database.windows.net' -DatabaseName '<database>'
```

The upgrade migrates `chat.Attachment` metadata and message associations into `storage.FileAsset` and `storage.FileAssetLink`, replaces attachment references in verification and privacy requests, and installs the new authorization, session, privacy-task, sync and retention objects.

For a populated identity table, the first upgrade run adds nullable ciphertext, hash and masked-hint columns, then stops before removing the v2.2 uniqueness control or plaintext. The approved CIAM migration process must backfill encrypted normalized subjects and keyed deterministic hashes. Rerun the same upgrade after the backfill; it validates completeness, makes the protected columns mandatory and removes plaintext. This fail-closed two-pass gate prevents a convenience migration from becoming the production cryptographic design.

## Safety and migration notes

- Take a backup/export and test restore before applying this package to any database containing data.
- The clean baseline is additive. The reviewed v2.2-to-v2.3 upgrade removes `chat.Attachment` only after every row has been copied and checked in domain-neutral storage.
- Schema drift is not silently repaired. Review any pre-existing object before deployment.
- `storage.FileAsset.blob_path_hash` and `notification.PushToken.token_fingerprint` are implementation-supporting SHA-256 values. They enforce uniqueness without exceeding Azure SQL index-key limits or indexing ciphertext. Services must verify the full value after a hash match and treat collisions as security events.
- `iam.MemberIdentity` stores only encrypted subjects, keyed deterministic hashes and optional masked hints. Passwords, OTP values, bearer tokens and refresh tokens remain outside Azure SQL.
- `090_verify.sql` validates the exact v2.3 table inventory, controlled views and procedures, invariant triggers, sequences, protected identity columns, trusted constraints, enabled indexes and authorization seeds. API integration, deny-path, concurrency, retention, recovery and performance evidence is still required for QA sign-off.
