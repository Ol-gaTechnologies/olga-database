# OLGA Connect Azure SQL deployment package

This package creates the Release 1 Azure SQL database objects defined by Database Architecture and Table-Level Design v2.2. It is intended for a new, empty Azure SQL database. Existing standalone NLP databases require a reviewed migration rather than running the baseline over them.

## Package contents

- `001_schemas_sequences.sql`: 12 schemas and the chat message sequence.
- `010_tables.sql`: all 58 documented product tables.
- `020_constraints_indexes.sql`: foreign keys, checks, unique rules and critical access-path indexes.
- `030_views.sql`: four controlled security/integration views.
- `040_procedures.sql`: eight controlled workflow procedures.
- `050_seed.sql`: roles, `ranking-v1`, and optional provisional QA notification policies.
- `060_security.sql`: least-privilege database roles and grants.
- `070_bind_identities.template.sql`: Entra managed-identity binding template; excluded from automatic deployment.
- `090_verify.sql`: post-deployment completeness and trust checks.
- `deploy.sql`: SQLCMD-mode deployment manifest.
- `deploy.ps1`: Entra-authenticated deployment wrapper.
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

## Safety and migration notes

- Take a backup/export and test restore before applying this package to any database containing data.
- The baseline is additive and does not drop tables or columns.
- Schema drift is not silently repaired. Review any pre-existing object before deployment.
- `chat.Attachment.blob_path_hash` and `notification.PushToken.token_fingerprint` are implementation-supporting SHA-256 values. They enforce the documented uniqueness rules without exceeding Azure SQL index-key limits or indexing encrypted token ciphertext.
- Verification is structural; run API integration, authorization, concurrency, retention and performance tests before QA sign-off.
