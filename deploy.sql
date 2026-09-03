:setvar SeedMvpPolicies "0"
:on error exit
PRINT 'Deploying OLGA Connect Azure SQL baseline...';
:r .\001_schemas_sequences.sql
:r .\010_tables.sql
:r .\020_constraints_indexes.sql
:r .\030_views.sql
:r .\040_procedures.sql
:r .\050_seed.sql
:r .\060_security.sql
:r .\090_verify.sql
PRINT 'OLGA Connect Azure SQL baseline deployed successfully.';
