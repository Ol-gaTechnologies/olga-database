# Deploying with DBeaver Community

The same PostgreSQL schema is deployed to every environment. The production
entry point adds a database-name guard and continues to use the fail-closed
seed behavior from `OLGA_Connect_PostgreSQL_Full_Setup.sql`.

## Before deployment

1. Confirm that the target is a new PostgreSQL 17 database.
2. Confirm that `vector`, `pg_stat_statements`, and `temporal_tables` are allowlisted.
3. Connect as `olga_migration_admin` using the connection secret retrieved by
   your authorized Azure user. This account owns the baseline objects and can
   create or alter schemas, tables, functions, roles, and grants.
4. In the SQL editor, verify the active connection and database shown in the
   toolbar. A PostgreSQL connection cannot switch databases in-place.

## Non-production database

The Terraform database name is `olga_connect_dev`. The wrapper stops before
deployment if DBeaver is connected to any other database.

1. Open `deploy_dbeaver.sql` from this directory in DBeaver.
2. Associate the editor with the intended database connection.
3. Choose **Execute SQL Script** or press **Alt+X**.
4. Confirm that the final transaction commits without an error.

## Production database

The production database is expected to be named `olga_connect_prod`.

1. Open `deploy_dbeaver_prd.sql` in DBeaver.
2. Associate the editor with the `olga_connect_prod` database connection.
3. Recheck the host, database, and user before execution.
4. Choose **Execute SQL Script** or press **Alt+X**.
5. Do not enable a provisional QA policy seed for production. The included
   standalone setup keeps it disabled.

The production wrapper aborts before deployment when `current_database()` is
not exactly `olga_connect_prod`.

## Local DBeaver connection

Terraform permits PostgreSQL and Key Vault access only from the exact `/32`
addresses configured for the selected environment in the infrastructure
repository's `postgres-access.auto.tfvars`. Your Azure user can read only the
`postgresql-connection` secret. If your public IP changes, update that file and
apply the reviewed Terraform plan before connecting.

Retrieve the connection without printing its password, then place only the
password on the clipboard:

```powershell
$tenantId = '9972baa6-9591-43d7-8b13-59da8e6f1a72'
$subscriptionId = 'e0bb013f-a8af-4d60-9c5b-0140b361f257'
$resourceGroup = 'rg-olga-dev-malaysiawest'

az login --tenant $tenantId
az account set --subscription $subscriptionId

$keyVaultName = az keyvault list `
  --resource-group $resourceGroup `
  --query '[0].name' `
  --output tsv

$connectionString = az keyvault secret show `
  --vault-name $keyVaultName `
  --name 'postgresql-connection' `
  --query value `
  --output tsv

$connection = @{}
$connectionString.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries) |
  ForEach-Object {
    $name, $value = $_.Split('=', 2)
    $connection[$name] = $value
  }

$connection['Password'] | Set-Clipboard
$connectionString = $null
```

Create the DBeaver PostgreSQL connection with:

- Host: `$connection['Host']`
- Port: `$connection['Port']`
- Database: `$connection['Database']`
- Username: `$connection['Username']` (`olga_migration_admin`)
- Password: paste from the clipboard
- SSL mode: `verify-full`

After connecting, clear the clipboard:

```powershell
Set-Clipboard -Value ''
```

Microsoft Entra database authentication is also enabled. An Entra login uses
its principal name plus a short-lived `oss-rdbms` access token as the password;
it does not use the user's normal Microsoft password. Use
`olga_migration_admin` for owner-level DDL unless database ownership is moved
to a shared Entra-backed role in a future change.

## Identity binding

`070_bind_identities.template.sql` is intentionally not included. Replace its
placeholder principals only after Azure PostgreSQL Microsoft Entra mappings
exist, then execute it once per PostgreSQL server/environment. Role membership
is server-wide; the schema and object grants in the main setup are applied to
each database separately.
