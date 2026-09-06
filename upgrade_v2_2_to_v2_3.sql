:setvar SeedMvpPolicies "0"
:on error exit
PRINT 'Upgrading OLGA Connect Azure SQL baseline from v2.2 to v2.3...';
:r .\001_schemas_sequences.sql
:r .\migrations\002_v2_2_to_v2_3_expand.sql
:r .\010_tables.sql
:r .\migrations\002_v2_2_to_v2_3_contract.sql
:r .\020_constraints_indexes.sql
:r .\025_invariants.sql
:r .\030_views.sql
:r .\040_procedures.sql
:r .\050_seed.sql
:r .\060_security.sql
:r .\090_verify.sql
PRINT 'OLGA Connect Azure SQL baseline upgraded to v2.3 successfully.';
