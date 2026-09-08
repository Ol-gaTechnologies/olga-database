DO $$
DECLARE
    expected_tables text[] := ARRAY[
        'core.community','core.organization','core.organization_member','core.member_profile','core.sector','core.member_sector','core.member_geography','core.profile_field_visibility','core.member_verification',
        'iam.member','iam.member_identity','iam.role','iam.permission','iam.role_permission','iam.member_role','iam.member_device','iam.auth_session',
        'consent.consent_policy','consent.member_consent','consent.privacy_request','consent.privacy_request_task',
        'event.venue','event.event','event.event_matching_policy','event.event_registration','event.live_mode_session','event.event_presence',
        'social.connection_request','social.connection','social.member_block','social.member_report',
        'chat.conversation','chat.conversation_participant','chat.message','chat.message_receipt',
        'storage.file_asset','storage.file_asset_link',
        'notification.notification_policy','notification.notification_preference','notification.push_token','notification.notification','notification.notification_delivery_attempt',
        'nlp.nlp_intent','nlp.nlp_embedding','nlp.nlp_model_version','nlp.nlp_ranking_config','nlp.nlp_processing_job','nlp.match_request','nlp.nlp_match_result','nlp.nlp_feedback','nlp.match_suppression','nlp.evaluation_dataset','nlp.evaluation_pair','nlp.evaluation_run',
        'moderation.moderation_case','moderation.moderation_action','moderation.content_rule','moderation.content_scan',
        'ops.outbox_event','ops.idempotency_record','ops.background_job','ops.sync_change','ops.retention_policy','ops.retention_execution','ops.audit_event',
        'analytics.product_event'
    ];
    expected_views text[] := ARRAY[
        'nlp.vw_member_context_eligibility','nlp.vw_member_relationship','chat.vw_authorized_conversation','admin.vw_member_review'
    ];
    expected_functions text[] := ARRAY[
        'nlp.get_requester_intent','nlp.get_eligible_candidates','nlp.save_match_results','nlp.save_feedback',
        'social.accept_connection_request','chat.save_message','event.purge_expired_presence','notification.try_enqueue'
    ];
    expected_triggers text[] := ARRAY[
        'storage.file_asset_link.enforce_file_asset_link_resource',
        'consent.privacy_request.enforce_privacy_request_completion',
        'consent.privacy_request_task.protect_completed_privacy_request_tasks',
        'ops.retention_policy.protect_active_retention_policy'
    ];
    item text;
    actual_count int;
BEGIN
    SELECT count(*) INTO actual_count
    FROM information_schema.tables
    WHERE table_type = 'BASE TABLE'
      AND table_schema IN ('core','iam','consent','event','social','chat','storage','notification','nlp','moderation','ops','analytics');
    IF actual_count <> cardinality(expected_tables) THEN
        RAISE EXCEPTION 'Unexpected OLGA product-table count: expected %, found %', cardinality(expected_tables), actual_count;
    END IF;
    FOREACH item IN ARRAY expected_tables LOOP
        IF to_regclass(item) IS NULL THEN RAISE EXCEPTION 'Required table is missing: %', item; END IF;
    END LOOP;
    FOREACH item IN ARRAY expected_views LOOP
        IF to_regclass(item) IS NULL THEN RAISE EXCEPTION 'Required view is missing: %', item; END IF;
    END LOOP;
    FOREACH item IN ARRAY expected_functions LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = split_part(item,'.',1) AND p.proname = split_part(item,'.',2)
        ) THEN RAISE EXCEPTION 'Required function is missing: %', item; END IF;
    END LOOP;
    FOREACH item IN ARRAY expected_triggers LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_trigger t
            JOIN pg_class c ON c.oid = t.tgrelid
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE NOT t.tgisinternal AND n.nspname = split_part(item,'.',1)
              AND c.relname = split_part(item,'.',2) AND t.tgname = split_part(item,'.',3)
        ) THEN RAISE EXCEPTION 'Required trigger is missing: %', item; END IF;
    END LOOP;
    IF to_regclass('chat.message_sequence') IS NULL OR to_regclass('ops.sync_change_sequence') IS NULL THEN
        RAISE EXCEPTION 'One or more required sequences are missing.';
    END IF;
    IF to_regclass('chat.attachment') IS NOT NULL THEN RAISE EXCEPTION 'Legacy chat.attachment must not remain.'; END IF;
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'iam' AND table_name = 'member_identity' AND column_name = 'provider_subject'
    ) THEN RAISE EXCEPTION 'Plaintext identity subject column remains.'; END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'iam' AND table_name = 'member_identity' AND column_name = 'provider_subject_hash'
    ) OR NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'iam' AND table_name = 'member_identity' AND column_name = 'provider_subject_ciphertext' AND data_type = 'bytea'
    ) THEN RAISE EXCEPTION 'Protected identity subject columns are missing or invalid.'; END IF;
    IF NOT EXISTS (
        SELECT 1
        FROM pg_attribute a
        JOIN pg_class t ON t.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = t.relnamespace
        WHERE n.nspname = 'nlp' AND t.relname = 'nlp_embedding' AND a.attname = 'embedding'
          AND format_type(a.atttypid, a.atttypmod) = 'vector(1536)'
    ) THEN RAISE EXCEPTION 'nlp_embedding.embedding must use pgvector.'; END IF;
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE column_name = 'row_version'
          AND table_schema IN ('core','iam','consent','event','social','chat','storage','notification','nlp','moderation','ops')
          AND (data_type <> 'bigint' OR column_default IS NULL OR column_default !~ '^1(?:::bigint)?$')
    ) THEN RAISE EXCEPTION 'Every row_version must be bigint with default 1.'; END IF;
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns c
        WHERE c.column_name = 'row_version'
          AND c.table_schema IN ('core','iam','consent','event','social','chat','storage','notification','nlp','moderation','ops')
          AND NOT EXISTS (
              SELECT 1 FROM pg_trigger t
              WHERE t.tgrelid = format('%I.%I', c.table_schema, c.table_name)::regclass
                AND t.tgname = 'set_row_version' AND t.tgfoid = 'ops.set_row_version()'::regprocedure
                AND t.tgenabled <> 'D'
          )
    ) THEN RAISE EXCEPTION 'One or more row_version triggers are missing or disabled.'; END IF;
    IF EXISTS (
        SELECT 1 FROM pg_constraint c
        JOIN pg_namespace n ON n.oid = c.connamespace
        WHERE n.nspname IN ('core','iam','consent','event','social','chat','storage','notification','nlp','moderation','ops','analytics')
          AND NOT c.convalidated
    ) THEN RAISE EXCEPTION 'One or more constraints are not validated.'; END IF;
    IF EXISTS (
        SELECT 1 FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname IN ('core','iam','consent','event','social','chat','storage','notification','nlp','moderation','ops','analytics')
          AND NOT i.indisvalid
    ) THEN RAISE EXCEPTION 'One or more indexes are invalid.'; END IF;
    IF EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname IN ('core','iam','consent','event','social','chat','storage','notification','nlp','moderation','ops','analytics')
          AND indexdef ~* 'USING[[:space:]]+(hnsw|ivfflat)'
    ) THEN RAISE EXCEPTION 'Approximate vector indexes are not approved.'; END IF;
    IF NOT EXISTS (SELECT 1 FROM iam.permission WHERE status = 'ACTIVE')
       OR NOT EXISTS (SELECT 1 FROM iam.role_permission WHERE revoked_at IS NULL) THEN
        RAISE EXCEPTION 'Authorization permission seeds are missing.';
    END IF;
END;
$$;

COMMENT ON SCHEMA ops IS 'OLGA.SchemaVersion=2.3';
COMMIT;
