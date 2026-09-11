\set ON_ERROR_STOP on
SELECT set_config('olga.seed_mvp_policies', :'seed_mvp_policies', false);
\ir 001_schemas_sequences.sql
\ir 010_tables.sql
\ir 015_audit_history.sql
\ir 020_constraints_indexes.sql
\ir 025_invariants.sql
\ir 030_views.sql
\ir 040_procedures.sql
\ir 050_seed.sql
\ir 060_security.sql
\ir 090_verify.sql
