DO $$
DECLARE
    binding record;
BEGIN
    FOR binding IN
        SELECT * FROM (VALUES
            ('olga_core_app','core'),('olga_identity_app','iam'),('olga_consent_app','consent'),
            ('olga_event_app','event'),('olga_social_app','social'),('olga_chat_app','chat'),
            ('olga_storage_app','storage'),('olga_notification_app','notification'),('olga_nlp_app','nlp'),
            ('olga_moderation_app','moderation'),('olga_ops_worker','ops'),('olga_analytics_writer','analytics')
        ) AS roles(role_name, schema_name)
    LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = binding.role_name) THEN
            EXECUTE format('CREATE ROLE %I NOLOGIN', binding.role_name);
        END IF;
        EXECUTE format('REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA %I FROM PUBLIC', binding.schema_name);
        EXECUTE format('GRANT USAGE ON SCHEMA %I TO %I', binding.schema_name, binding.role_name);
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA %I TO %I', binding.schema_name, binding.role_name);
        EXECUTE format('GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA %I TO %I', binding.schema_name, binding.role_name);
        EXECUTE format('GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA %I TO %I', binding.schema_name, binding.role_name);
    END LOOP;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'olga_admin_reader') THEN
        EXECUTE 'CREATE ROLE olga_admin_reader NOLOGIN';
    END IF;
END;
$$;

GRANT USAGE ON SCHEMA admin TO olga_admin_reader;
GRANT SELECT ON admin.vw_member_review TO olga_admin_reader;
REVOKE ALL ON SCHEMA history FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA history FROM PUBLIC;
GRANT USAGE ON SCHEMA history TO olga_admin_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA history TO olga_admin_reader;
GRANT USAGE ON SCHEMA ops TO olga_core_app, olga_identity_app, olga_consent_app, olga_event_app,
    olga_social_app, olga_chat_app, olga_storage_app, olga_notification_app, olga_nlp_app,
    olga_moderation_app, olga_analytics_writer;
GRANT EXECUTE ON FUNCTION ops.set_audit_context(varchar), ops.current_audit_actor_id()
    TO olga_core_app, olga_identity_app, olga_consent_app, olga_event_app, olga_social_app,
       olga_chat_app, olga_storage_app, olga_notification_app, olga_nlp_app,
       olga_moderation_app, olga_analytics_writer;
GRANT SELECT ON nlp.vw_member_context_eligibility, nlp.vw_member_relationship TO olga_nlp_app;
GRANT SELECT ON chat.vw_authorized_conversation TO olga_chat_app;
GRANT SELECT ON iam.member TO olga_notification_app;
GRANT SELECT ON core.member_profile, consent.member_consent TO olga_nlp_app;
GRANT SELECT ON event.event_matching_policy TO olga_notification_app;
GRANT INSERT ON ops.outbox_event TO olga_social_app, olga_chat_app, olga_notification_app, olga_storage_app;
GRANT SELECT ON chat.conversation, chat.conversation_participant TO olga_social_app;
GRANT INSERT ON ops.background_job TO olga_storage_app, olga_consent_app;
GRANT INSERT ON moderation.content_scan TO olga_storage_app;
GRANT INSERT ON ops.audit_event TO olga_identity_app, olga_consent_app, olga_storage_app, olga_moderation_app;
GRANT SELECT, UPDATE, DELETE ON storage.file_asset, storage.file_asset_link TO olga_ops_worker;
GRANT SELECT, INSERT, UPDATE ON ops.retention_policy TO olga_consent_app;

-- Append-only and authorization catalogs remain non-deletable for runtime identities.
REVOKE UPDATE, DELETE ON ops.audit_event FROM olga_ops_worker;
REVOKE INSERT, UPDATE, DELETE ON ops.retention_policy FROM olga_ops_worker;
REVOKE DELETE ON ops.retention_execution FROM olga_ops_worker;
REVOKE DELETE ON consent.privacy_request, consent.privacy_request_task FROM olga_consent_app;
REVOKE DELETE ON iam.role, iam.permission, iam.role_permission, iam.member_role FROM olga_identity_app;

-- Atomic chat/connection workflows are function-only. Direct DML would bypass the
-- idempotency record, transactional outbox and member-scoped sync ledger.
REVOKE INSERT, UPDATE, DELETE ON social.connection FROM olga_social_app;
REVOKE INSERT, UPDATE, DELETE ON chat.conversation, chat.conversation_participant,
    chat.message, chat.message_receipt FROM olga_chat_app;
