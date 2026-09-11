FROM postgres:17-alpine

LABEL org.opencontainers.image.title="OLGA database migrations"
LABEL org.opencontainers.image.description="Transactional PostgreSQL schema deployment for OLGA Connect"

WORKDIR /migrations

COPY 001_schemas_sequences.sql ./
COPY 010_tables.sql ./
COPY 020_constraints_indexes.sql ./
COPY 025_invariants.sql ./
COPY 030_views.sql ./
COPY 040_procedures.sql ./
COPY 050_seed.sql ./
COPY 060_security.sql ./
COPY 090_verify.sql ./
COPY deploy.sql ./
COPY container/run-migrations.sh ./run-migrations.sh

RUN chmod 0555 /migrations/run-migrations.sh \
    && chmod 0444 /migrations/*.sql

USER postgres

ENTRYPOINT ["/migrations/run-migrations.sh"]
