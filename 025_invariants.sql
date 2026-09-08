-- Polymorphic file links remain referentially safe even though one FK cannot target four tables.
CREATE OR REPLACE FUNCTION storage.enforce_file_asset_link_resource()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF (NEW.resource_type = 'MESSAGE' AND NOT EXISTS (SELECT 1 FROM chat.message WHERE message_id = NEW.resource_id))
       OR (NEW.resource_type = 'MEMBER_VERIFICATION' AND NOT EXISTS (SELECT 1 FROM core.member_verification WHERE verification_id = NEW.resource_id))
       OR (NEW.resource_type = 'PRIVACY_REQUEST' AND NOT EXISTS (SELECT 1 FROM consent.privacy_request WHERE privacy_request_id = NEW.resource_id))
       OR (NEW.resource_type = 'EVALUATION_RUN' AND NOT EXISTS (SELECT 1 FROM nlp.evaluation_run WHERE evaluation_run_id = NEW.resource_id)) THEN
        RAISE EXCEPTION USING ERRCODE = '23503', MESSAGE = 'FileAssetLink resource does not exist in its owning domain.';
    END IF;
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS enforce_file_asset_link_resource ON storage.file_asset_link;
CREATE TRIGGER enforce_file_asset_link_resource
BEFORE INSERT OR UPDATE ON storage.file_asset_link
FOR EACH ROW EXECUTE FUNCTION storage.enforce_file_asset_link_resource();

-- A privacy request is terminal only after its explicit domain work is terminal and evidenced.
CREATE OR REPLACE FUNCTION consent.enforce_privacy_request_completion()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.status = 'COMPLETED' AND NEW.status <> 'COMPLETED' THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'A completed PrivacyRequest cannot return to a mutable state.';
    END IF;
    IF NEW.status = 'COMPLETED' AND (
        NOT EXISTS (SELECT 1 FROM consent.privacy_request_task WHERE privacy_request_id = NEW.privacy_request_id)
        OR EXISTS (
            SELECT 1 FROM consent.privacy_request_task
            WHERE privacy_request_id = NEW.privacy_request_id
              AND (status NOT IN ('COMPLETED','EXEMPTED') OR evidence_code IS NULL OR completed_at IS NULL)
        )
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'PrivacyRequest cannot complete until every required task is completed or evidenced as exempt.';
    END IF;
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS enforce_privacy_request_completion ON consent.privacy_request;
CREATE TRIGGER enforce_privacy_request_completion
BEFORE INSERT OR UPDATE ON consent.privacy_request
FOR EACH ROW EXECUTE FUNCTION consent.enforce_privacy_request_completion();

CREATE OR REPLACE FUNCTION consent.protect_completed_privacy_request_tasks()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM consent.privacy_request
        WHERE privacy_request_id = OLD.privacy_request_id AND status = 'COMPLETED'
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Tasks and evidence for a completed PrivacyRequest are immutable.';
    END IF;
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS protect_completed_privacy_request_tasks ON consent.privacy_request_task;
CREATE TRIGGER protect_completed_privacy_request_tasks
BEFORE UPDATE OR DELETE ON consent.privacy_request_task
FOR EACH ROW EXECUTE FUNCTION consent.protect_completed_privacy_request_tasks();

-- Active retention versions are immutable except for the ACTIVE-to-RETIRED transition.
CREATE OR REPLACE FUNCTION ops.protect_active_retention_policy()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.status = 'ACTIVE' AND (
        NEW.resource_type IS DISTINCT FROM OLD.resource_type
        OR NEW.policy_version IS DISTINCT FROM OLD.policy_version
        OR NEW.retention_days IS DISTINCT FROM OLD.retention_days
        OR NEW.disposition_action IS DISTINCT FROM OLD.disposition_action
        OR NEW.legal_hold_supported IS DISTINCT FROM OLD.legal_hold_supported
        OR NEW.effective_from IS DISTINCT FROM OLD.effective_from
        OR NEW.approved_by IS DISTINCT FROM OLD.approved_by
        OR NEW.status NOT IN ('ACTIVE','RETIRED')
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'An active retention policy version is immutable and may only be retired.';
    END IF;
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS protect_active_retention_policy ON ops.retention_policy;
CREATE TRIGGER protect_active_retention_policy
BEFORE UPDATE ON ops.retention_policy
FOR EACH ROW EXECUTE FUNCTION ops.protect_active_retention_policy();
