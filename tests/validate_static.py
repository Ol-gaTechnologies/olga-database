from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASELINE_FILES = [
    "001_schemas_sequences.sql", "010_tables.sql", "020_constraints_indexes.sql", "025_invariants.sql",
    "030_views.sql", "040_procedures.sql", "050_seed.sql", "060_security.sql", "090_verify.sql",
]
EXPECTED_TABLES = {
    "core.community", "core.organization", "core.organization_member", "core.member_profile", "core.sector",
    "core.member_sector", "core.member_geography", "core.profile_field_visibility", "core.member_verification",
    "iam.member", "iam.member_identity", "iam.role", "iam.permission", "iam.role_permission", "iam.member_role",
    "iam.member_device", "iam.auth_session", "consent.consent_policy", "consent.member_consent",
    "consent.privacy_request", "consent.privacy_request_task", "event.venue", "event.event",
    "event.event_matching_policy", "event.event_registration", "event.live_mode_session", "event.event_presence",
    "social.connection_request", "social.connection", "social.member_block", "social.member_report",
    "chat.conversation", "chat.conversation_participant", "chat.message", "chat.message_receipt",
    "storage.file_asset", "storage.file_asset_link", "notification.notification_policy",
    "notification.notification_preference", "notification.push_token", "notification.notification",
    "notification.notification_delivery_attempt", "nlp.nlp_intent", "nlp.nlp_embedding", "nlp.nlp_model_version",
    "nlp.nlp_ranking_config", "nlp.nlp_processing_job", "nlp.match_request", "nlp.nlp_match_result",
    "nlp.nlp_feedback", "nlp.match_suppression", "nlp.evaluation_dataset", "nlp.evaluation_pair",
    "nlp.evaluation_run", "moderation.moderation_case", "moderation.moderation_action",
    "moderation.content_rule", "moderation.content_scan", "ops.outbox_event", "ops.idempotency_record",
    "ops.background_job", "ops.sync_change", "ops.retention_policy", "ops.retention_execution",
    "ops.audit_event", "analytics.product_event",
}


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def parse_tables(text: str) -> dict[str, set[str]]:
    result: dict[str, set[str]] = {}
    pattern = re.compile(r"CREATE TABLE IF NOT EXISTS ([a-z_]+\.[a-z_]+)\s*\((.*?)\n\s*\);", re.S)
    for match in pattern.finditer(text):
        columns = {
            column.group(1)
            for line in match.group(2).splitlines()
            if (column := re.match(r"\s*([a-z_][a-z0-9_]*)\s+[a-z]", line))
            and column.group(1).lower() != "constraint"
        }
        result[match.group(1)] = columns
    return result


def validate_delimiters(name: str, text: str) -> None:
    code = re.sub(r"--[^\n]*", "", text)
    code = re.sub(r"'(?:''|[^'])*'", "''", code)
    depth = 0
    for character in code:
        if character == "(":
            depth += 1
        elif character == ")":
            depth -= 1
            if depth < 0:
                fail(f"unbalanced closing parenthesis in {name}")
    if depth:
        fail(f"unbalanced parentheses in {name}: depth={depth}")
    for delimiter in set(re.findall(r"\$[a-z_]*\$", text, re.I)):
        if text.count(delimiter) % 2:
            fail(f"unbalanced dollar quote {delimiter} in {name}")


def main() -> None:
    texts = {name: (ROOT / name).read_text(encoding="utf-8") for name in BASELINE_FILES}
    for name, text in texts.items():
        validate_delimiters(name, text)
    combined = "\n".join([*texts.values(), (ROOT / "070_bind_identities.template.sql").read_text(encoding="utf-8")])
    tables = parse_tables(texts["010_tables.sql"])
    if set(tables) != EXPECTED_TABLES:
        fail(f"table inventory mismatch; missing={sorted(EXPECTED_TABLES-set(tables))}, extra={sorted(set(tables)-EXPECTED_TABLES)}")

    forbidden = re.compile(
        r"(?im)^\s*GO\s*$|\[[A-Za-z_][^]]*\]|\b(?:nvarchar|datetimeoffset|rowversion|varbinary|SYSUTCDATETIME|OBJECT_ID|SCHEMA_ID|CREATE OR ALTER|MERGE)\b|DECLARE\s+@|@@"
    )
    match = forbidden.search(combined)
    if match:
        fail(f"SQL Server syntax remains: {match.group(0)!r}")
    mixed_identifier = re.search(
        r"\b(?:core|iam|consent|event|social|chat|storage|notification|nlp|moderation|ops|analytics|admin)\.[A-Za-z0-9_]*[A-Z][A-Za-z0-9_]*",
        combined,
    )
    if mixed_identifier:
        fail(f"mixed-case PostgreSQL identifier remains: {mixed_identifier.group(0)!r}")

    foreign_keys = re.findall(
        r"add_constraint_if_missing\('([a-z_]+)', '([a-z_]+)', '[a-z0-9_]+', \$constraint\$FOREIGN KEY \(([a-z0-9_]+)\) REFERENCES ([a-z_]+\.[a-z_]+) \(([a-z0-9_]+)\)\$constraint\$\)",
        texts["020_constraints_indexes.sql"], re.I,
    )
    if len(foreign_keys) != 103:
        fail(f"unexpected foreign-key inventory: {len(foreign_keys)}")
    for source_schema, source_name, source_column, target_table, target_column in foreign_keys:
        source_table = f"{source_schema}.{source_name}"
        if source_column not in tables.get(source_table, set()):
            fail(f"foreign-key source does not exist: {source_table}.{source_column}")
        if target_column not in tables.get(target_table, set()):
            fail(f"foreign-key target does not exist: {target_table}.{target_column}")

    for index_name, table_name, expression in re.findall(
        r"CREATE (?:UNIQUE )?INDEX IF NOT EXISTS ([a-z0-9_]+) ON ([a-z_]+\.[a-z_]+) \(([^)]+)\)",
        texts["020_constraints_indexes.sql"], re.I,
    ):
        if table_name not in tables:
            fail(f"index {index_name} references missing table {table_name}")
        for column in re.findall(r"\b[a-z_][a-z0-9_]*\b", expression):
            if column.lower() not in {"asc", "desc"} and column not in tables[table_name]:
                fail(f"index {index_name} references missing column {table_name}.{column}")

    constraint_count = len(re.findall(r"^SELECT ops\.add_constraint_if_missing", texts["020_constraints_indexes.sql"], re.M))
    index_count = len(re.findall(r"^CREATE (?:UNIQUE )?INDEX IF NOT EXISTS", texts["020_constraints_indexes.sql"], re.M))
    if constraint_count != 167 or index_count != 172:
        fail(f"constraint/index inventory mismatch: constraints={constraint_count}, indexes={index_count}")

    if not re.search(r"embedding\s+vector\(1536\)\s+NOT NULL", texts["010_tables.sql"], re.I):
        fail("nlp_embedding.embedding is not vector(1536)")
    if "<=>" not in texts["040_procedures.sql"] or "AS MATERIALIZED" not in texts["040_procedures.sql"]:
        fail("candidate retrieval does not eligibility-bound exact cosine ranking")
    if re.search(r"USING\s+(?:hnsw|ivfflat)", combined, re.I):
        fail("approximate vector indexes are prohibited before load-test approval")
    if "p_max_rows NOT BETWEEN 50 AND 200" not in texts["040_procedures.sql"]:
        fail("candidate retrieval is not capped to the approved 50-200 range")
    if re.search(r"\brow_version\s+(?!bigint NOT NULL DEFAULT 1)", texts["010_tables.sql"], re.I):
        fail("row_version is not trigger-managed bigint with default 1")
    if "NULLS NOT DISTINCT WHERE status = 'ACTIVE'" not in texts["020_constraints_indexes.sql"]:
        fail("global active notification policies are not null-safe unique")
    if "ux_push_token_fingerprint" not in texts["020_constraints_indexes.sql"] or re.search(
        r"CREATE .*INDEX.*\([^)]*ciphertext", texts["020_constraints_indexes.sql"], re.I
    ):
        fail("sensitive ciphertext indexing guard is missing")
    if len(re.findall(r"CREATE OR REPLACE VIEW ", texts["030_views.sql"], re.I)) != 4:
        fail("controlled-view count differs from the design")
    if len(re.findall(r"CREATE OR REPLACE FUNCTION (?:nlp|social|chat|event|notification)\.", texts["040_procedures.sql"], re.I)) != 8:
        fail("controlled-function count differs from the design")

    manifest = texts["001_schemas_sequences.sql"] + (ROOT / "deploy.sql").read_text(encoding="utf-8")
    for name in BASELINE_FILES:
        if name != "001_schemas_sequences.sql" and name not in manifest:
            fail(f"deploy.sql omits {name}")
    if "RAISE EXCEPTION" not in (ROOT / "upgrade_v2_2_to_v2_3.sql").read_text(encoding="utf-8"):
        fail("unsupported cross-engine upgrade entry point is not fail-closed")
    full_setup = (ROOT / "OLGA_Connect_PostgreSQL_Full_Setup.sql").read_text(encoding="utf-8")
    for name, text in texts.items():
        if text.strip() not in full_setup:
            fail(f"standalone setup is stale relative to {name}")
    print(f"Static validation passed: {len(tables)} PostgreSQL tables; foreign keys, indexes, functions, and manifests resolve.")


if __name__ == "__main__":
    main()
