from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TABLES_SQL = ROOT / "010_tables.sql"
CONSTRAINTS_SQL = ROOT / "020_constraints_indexes.sql"

EXPECTED_TABLES = {
    "core.Community", "core.Organization", "core.OrganizationMember", "core.MemberProfile", "core.Sector",
    "core.MemberSector", "core.MemberGeography", "core.ProfileFieldVisibility", "core.MemberVerification",
    "iam.Member", "iam.MemberIdentity", "iam.Role", "iam.Permission", "iam.RolePermission", "iam.MemberRole",
    "iam.MemberDevice", "iam.AuthSession", "consent.ConsentPolicy", "consent.MemberConsent",
    "consent.PrivacyRequest", "consent.PrivacyRequestTask", "event.Venue", "event.Event",
    "event.EventMatchingPolicy", "event.EventRegistration", "event.LiveModeSession", "event.EventPresence",
    "social.ConnectionRequest", "social.Connection", "social.MemberBlock", "social.MemberReport",
    "chat.Conversation", "chat.ConversationParticipant", "chat.Message", "chat.MessageReceipt",
    "storage.FileAsset", "storage.FileAssetLink", "notification.NotificationPolicy",
    "notification.NotificationPreference", "notification.PushToken", "notification.Notification",
    "notification.NotificationDeliveryAttempt", "nlp.NlpIntent", "nlp.NlpEmbedding", "nlp.NlpModelVersion",
    "nlp.NlpRankingConfig", "nlp.NlpProcessingJob", "nlp.MatchRequest", "nlp.NlpMatchResult", "nlp.NlpFeedback",
    "nlp.MatchSuppression", "nlp.EvaluationDataset", "nlp.EvaluationPair", "nlp.EvaluationRun",
    "moderation.ModerationCase", "moderation.ModerationAction", "moderation.ContentRule", "moderation.ContentScan",
    "ops.OutboxEvent", "ops.IdempotencyRecord", "ops.BackgroundJob", "ops.SyncChange", "ops.RetentionPolicy",
    "ops.RetentionExecution", "ops.AuditEvent", "analytics.ProductEvent",
}


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def parse_tables(text: str):
    result = {}
    pattern = re.compile(
        r"CREATE TABLE \[([^]]+)\]\.\[([^]]+)\]\s*\((.*?)\n\s*\);",
        re.IGNORECASE | re.DOTALL,
    )
    column_pattern = re.compile(
        r"^\s*\[([^]]+)\]\s+([A-Za-z0-9_]+(?:\([^)]*\))?)(?:\s+IDENTITY\([^)]*\))?\s+(?:NULL|NOT NULL)",
        re.IGNORECASE,
    )
    for match in pattern.finditer(text):
        table_name = f"{match.group(1)}.{match.group(2)}"
        columns = {}
        for line in match.group(3).splitlines():
            column = column_pattern.match(line)
            if column:
                columns[column.group(1)] = column.group(2).lower()
        result[table_name] = columns
    return result


def max_key_bytes(sql_type: str) -> int:
    value = sql_type.lower().replace(" ", "")
    if value in {"bigint", "datetimeoffset(7)"}:
        return 8 if value == "bigint" else 10
    if value in {"int", "date"}:
        return 4 if value == "int" else 3
    if value in {"smallint", "time"}:
        return 2 if value == "smallint" else 5
    if value in {"bit", "tinyint"}:
        return 1
    if value in {"rowversion", "binary(8)"}:
        return 8
    sized = re.fullmatch(r"(n?varchar|char|binary)\((\d+)\)", value)
    if sized:
        multiplier = 2 if sized.group(1) == "nvarchar" else 1
        return int(sized.group(2)) * multiplier
    decimal = re.fullmatch(r"decimal\((\d+),(\d+)\)", value)
    if decimal:
        precision = int(decimal.group(1))
        return 5 if precision <= 9 else 9 if precision <= 19 else 13 if precision <= 28 else 17
    return 1701


def main() -> None:
    tables_text = TABLES_SQL.read_text(encoding="utf-8")
    constraints_text = CONSTRAINTS_SQL.read_text(encoding="utf-8")
    tables = parse_tables(tables_text)
    if set(tables) != EXPECTED_TABLES:
        fail(f"table inventory mismatch; missing={sorted(EXPECTED_TABLES-set(tables))}, extra={sorted(set(tables)-EXPECTED_TABLES)}")

    for line_number, line in enumerate(tables_text.splitlines(), start=1):
        if re.match(r"^\s*\[[^]]+\].*--.*,$", line):
            fail(f"line {line_number} places a required comma inside a SQL comment")

    foreign_key_pattern = re.compile(
        r"ALTER TABLE \[([^]]+)\]\.\[([^]]+)\].*?FOREIGN KEY \(\[([^]]+)\]\) REFERENCES \[([^]]+)\]\.\[([^]]+)\] \(\[([^]]+)\]\)",
        re.IGNORECASE,
    )
    for match in foreign_key_pattern.finditer(constraints_text):
        source_table = f"{match.group(1)}.{match.group(2)}"
        target_table = f"{match.group(4)}.{match.group(5)}"
        if source_table not in tables or match.group(3) not in tables[source_table]:
            fail(f"foreign key source does not exist: {source_table}.{match.group(3)}")
        if target_table not in tables or match.group(6) not in tables[target_table]:
            fail(f"foreign key target does not exist: {target_table}.{match.group(6)}")

    index_pattern = re.compile(
        r"CREATE\s+(?:UNIQUE\s+)?INDEX\s+\[([^]]+)\]\s+ON\s+\[([^]]+)\]\.\[([^]]+)\]\s*\(([^)]+)\)",
        re.IGNORECASE,
    )
    for match in index_pattern.finditer(constraints_text):
        index_name = match.group(1)
        table_name = f"{match.group(2)}.{match.group(3)}"
        if table_name not in tables:
            fail(f"index {index_name} references missing table {table_name}")
        column_names = re.findall(r"\[([^]]+)\]", match.group(4))
        missing_columns = [name for name in column_names if name not in tables[table_name]]
        if missing_columns:
            fail(f"index {index_name} references missing columns {missing_columns}")
        key_bytes = sum(max_key_bytes(tables[table_name][name]) for name in column_names)
        if key_bytes > 1700:
            fail(f"index {index_name} can exceed the Azure SQL 1700-byte nonclustered key limit ({key_bytes} bytes)")

    required_manifest_files = {
        "deploy.sql": ["001_schemas_sequences.sql", "010_tables.sql", "020_constraints_indexes.sql", "025_invariants.sql", "030_views.sql", "040_procedures.sql", "050_seed.sql", "060_security.sql", "090_verify.sql"],
        "upgrade_v2_2_to_v2_3.sql": ["001_schemas_sequences.sql", "migrations\\002_v2_2_to_v2_3_expand.sql", "010_tables.sql", "migrations\\002_v2_2_to_v2_3_contract.sql", "020_constraints_indexes.sql", "025_invariants.sql", "030_views.sql", "040_procedures.sql", "050_seed.sql", "060_security.sql", "090_verify.sql"],
    }
    for manifest_name, expected_files in required_manifest_files.items():
        manifest = (ROOT / manifest_name).read_text(encoding="utf-8")
        for expected_file in expected_files:
            if expected_file not in manifest:
                fail(f"{manifest_name} omits {expected_file}")

    if "chat.Attachment" in tables_text or "provider_subject]" in tables_text:
        fail("legacy attachment or plaintext identity schema remains in the clean baseline")
    if "OLGA.SchemaVersion" not in (ROOT / "090_verify.sql").read_text(encoding="utf-8"):
        fail("verification does not stamp the deployed schema version")
    verify_text = (ROOT / "090_verify.sql").read_text(encoding="utf-8")
    inventory_match = re.search(r"INSERT @ExpectedTableList VALUES(.*?);", verify_text, re.IGNORECASE | re.DOTALL)
    if not inventory_match:
        fail("verification table inventory is missing")
    verified_tables = {f"{schema}.{table}" for schema, table in re.findall(r"\('([^']+)','([^']+)'\)", inventory_match.group(1))}
    if verified_tables != EXPECTED_TABLES:
        fail("verification table inventory differs from the baseline")
    trigger_count = len(re.findall(r"CREATE OR ALTER TRIGGER", (ROOT / "025_invariants.sql").read_text(encoding="utf-8"), re.IGNORECASE))
    if f"@ExpectedTriggers int={trigger_count}" not in verify_text:
        fail("verification trigger count differs from the invariant script")

    full_setup = (ROOT / "OLGA_Connect_AzureSQL_Full_Setup.sql").read_text(encoding="utf-8")
    for component in ["001_schemas_sequences.sql", "010_tables.sql", "020_constraints_indexes.sql", "025_invariants.sql", "030_views.sql", "040_procedures.sql", "060_security.sql", "090_verify.sql"]:
        if (ROOT / component).read_text(encoding="utf-8").strip() not in full_setup:
            fail(f"standalone setup is stale relative to {component}")
    seed_for_standalone = (ROOT / "050_seed.sql").read_text(encoding="utf-8").replace("IF '$(SeedMvpPolicies)'='1'", "IF 0=1").strip()
    if seed_for_standalone not in full_setup:
        fail("standalone setup is stale relative to 050_seed.sql")
    print(f"Static validation passed: {len(tables)} tables, foreign keys and indexes resolve, manifests are complete.")


if __name__ == "__main__":
    main()
