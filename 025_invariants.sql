SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO

-- Polymorphic file links remain referentially safe even though one FK cannot target four tables.
CREATE OR ALTER TRIGGER storage.trg_FileAssetLink_ResourceIntegrity
ON storage.FileAssetLink
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        WHERE (i.resource_type = 'MESSAGE' AND NOT EXISTS (SELECT 1 FROM chat.Message x WHERE x.message_id = i.resource_id))
           OR (i.resource_type = 'MEMBER_VERIFICATION' AND NOT EXISTS (SELECT 1 FROM core.MemberVerification x WHERE x.verification_id = i.resource_id))
           OR (i.resource_type = 'PRIVACY_REQUEST' AND NOT EXISTS (SELECT 1 FROM consent.PrivacyRequest x WHERE x.privacy_request_id = i.resource_id))
           OR (i.resource_type = 'EVALUATION_RUN' AND NOT EXISTS (SELECT 1 FROM nlp.EvaluationRun x WHERE x.evaluation_run_id = i.resource_id))
    )
        THROW 50800, 'FileAssetLink resource does not exist in its owning domain.', 1;
END;
GO

-- A privacy request is terminal only after its explicit domain work is terminal and evidenced.
CREATE OR ALTER TRIGGER consent.trg_PrivacyRequest_CompletionGuard
ON consent.PrivacyRequest
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN deleted d ON d.privacy_request_id = i.privacy_request_id
        WHERE d.status = 'COMPLETED' AND i.status <> 'COMPLETED'
    )
        THROW 50801, 'A completed PrivacyRequest cannot return to a mutable state.', 1;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        WHERE i.status = 'COMPLETED'
          AND (
              NOT EXISTS (SELECT 1 FROM consent.PrivacyRequestTask t WHERE t.privacy_request_id = i.privacy_request_id)
              OR EXISTS (
                  SELECT 1
                  FROM consent.PrivacyRequestTask t
                  WHERE t.privacy_request_id = i.privacy_request_id
                    AND (t.status NOT IN ('COMPLETED','EXEMPTED') OR t.evidence_code IS NULL OR t.completed_at IS NULL)
              )
          )
    )
        THROW 50802, 'PrivacyRequest cannot complete until every required task is completed or evidenced as exempt.', 1;
END;
GO

CREATE OR ALTER TRIGGER consent.trg_PrivacyRequestTask_CompletedRequestGuard
ON consent.PrivacyRequestTask
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM deleted d
        JOIN consent.PrivacyRequest p ON p.privacy_request_id = d.privacy_request_id
        WHERE p.status = 'COMPLETED'
    )
        THROW 50803, 'Tasks and evidence for a completed PrivacyRequest are immutable.', 1;
END;
GO

-- Once activated, a retention version can only be retired; its approved policy fields are immutable.
CREATE OR ALTER TRIGGER ops.trg_RetentionPolicy_ImmutableActive
ON ops.RetentionPolicy
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN deleted d ON d.retention_policy_id = i.retention_policy_id
        WHERE d.status = 'ACTIVE'
          AND (
              i.resource_type <> d.resource_type
              OR i.policy_version <> d.policy_version
              OR i.retention_days <> d.retention_days
              OR i.disposition_action <> d.disposition_action
              OR i.legal_hold_supported <> d.legal_hold_supported
              OR i.effective_from <> d.effective_from
              OR ISNULL(i.approved_by, '') <> ISNULL(d.approved_by, '')
              OR i.status NOT IN ('ACTIVE','RETIRED')
          )
    )
        THROW 50804, 'An active retention policy version is immutable and may only be retired.', 1;
END;
GO
