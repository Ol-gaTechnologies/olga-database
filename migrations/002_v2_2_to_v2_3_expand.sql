SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'iam.MemberIdentity', N'U') IS NULL
    THROW 50700, 'The v2.2 iam.MemberIdentity table is missing; this upgrade cannot identify the source baseline.', 1;
GO

IF COL_LENGTH(N'iam.MemberIdentity', N'provider_subject_hash') IS NULL
    ALTER TABLE iam.MemberIdentity ADD provider_subject_hash char(64) NULL;
GO
IF COL_LENGTH(N'iam.MemberIdentity', N'provider_subject_ciphertext') IS NULL
    ALTER TABLE iam.MemberIdentity ADD provider_subject_ciphertext varbinary(max) NULL;
GO
IF COL_LENGTH(N'iam.MemberIdentity', N'display_hint') IS NULL
    ALTER TABLE iam.MemberIdentity ADD display_hint nvarchar(80) NULL;
GO

-- On a populated baseline, the first run stops here after creating backfill columns. The approved
-- CIAM process can then write ciphertext and keyed hashes; a second run completes the contract.
IF COL_LENGTH(N'iam.MemberIdentity', N'provider_subject') IS NOT NULL
   AND EXISTS (SELECT 1 FROM iam.MemberIdentity WHERE provider_subject_hash IS NULL OR provider_subject_ciphertext IS NULL)
    THROW 50701, 'Backfill MemberIdentity with approved ciphertext and keyed hashes, then rerun the v2.3 upgrade.', 1;
GO

IF NOT EXISTS (SELECT 1 FROM iam.MemberIdentity WHERE provider_subject_hash IS NULL OR provider_subject_ciphertext IS NULL)
BEGIN
    ALTER TABLE iam.MemberIdentity ALTER COLUMN provider_subject_hash char(64) NOT NULL;
    ALTER TABLE iam.MemberIdentity ALTER COLUMN provider_subject_ciphertext varbinary(max) NOT NULL;
END;
GO
IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'iam.MemberIdentity') AND name = N'UX_MemberIdentity_ProviderSubject')
    DROP INDEX UX_MemberIdentity_ProviderSubject ON iam.MemberIdentity;
GO
IF COL_LENGTH(N'iam.MemberIdentity', N'provider_subject') IS NOT NULL
    ALTER TABLE iam.MemberIdentity DROP COLUMN provider_subject;
GO

-- Remove v2.2 access paths that are replaced by documented v2.3 composite indexes.
DECLARE @ObsoleteIndexes TABLE(schema_name sysname,table_name sysname,index_name sysname);
INSERT @ObsoleteIndexes VALUES
('core','OrganizationMember','IX_OrganizationMember_member_id'),('core','MemberSector','IX_MemberSector_sector_code'),
('event','EventRegistration','IX_EventRegistration_member_id'),('event','LiveModeSession','IX_LiveModeSession_member_id'),
('social','Connection','IX_Connection_member_high_id'),('social','MemberBlock','IX_MemberBlock_blocked_member_id'),
('chat','Message','IX_Message_sender_member_id'),('notification','PushToken','IX_PushToken_device_id'),
('event','Event','IX_Event_venue_id'),('event','EventPresence','IX_EventPresence_live_session_id'),
('nlp','NlpIntent','IX_NlpIntent_member_id'),('analytics','ProductEvent','IX_ProductEvent_community_id'),
('iam','MemberRole','IX_MemberRole_role_code'),('iam','MemberDevice','IX_MemberDevice_member_id'),
('core','Sector','IX_Sector_parent_sector_code'),('core','MemberVerification','IX_MemberVerification_member_id'),
('consent','MemberConsent','IX_MemberConsent_member_id'),('consent','MemberConsent','IX_MemberConsent_policy_id'),
('consent','PrivacyRequest','IX_PrivacyRequest_member_id'),('social','MemberReport','IX_MemberReport_reported_member_id'),
('chat','ConversationParticipant','IX_ConversationParticipant_member_id'),('chat','MessageReceipt','IX_MessageReceipt_member_id'),
('nlp','MatchSuppression','IX_MatchSuppression_member_id'),('nlp','MatchSuppression','IX_MatchSuppression_intent_id'),
('nlp','EvaluationPair','IX_EvaluationPair_dataset_id'),('nlp','EvaluationRun','IX_EvaluationRun_dataset_id'),
('nlp','EvaluationRun','IX_EvaluationRun_model_version'),('moderation','ModerationCase','IX_ModerationCase_subject_member_id'),
('moderation','ModerationAction','IX_ModerationAction_moderation_case_id'),('moderation','ModerationAction','IX_ModerationAction_actor_member_id'),
('core','MemberProfile','IX_MemberProfile_member_id'),('iam','MemberRole','IX_MemberRole_member_id'),
('core','ProfileFieldVisibility','IX_ProfileFieldVisibility_member_id'),('chat','ConversationParticipant','IX_ConversationParticipant_conversation_id'),
('chat','MessageReceipt','IX_MessageReceipt_message_id'),('notification','NotificationPreference','IX_NotificationPreference_member_id');
DECLARE @SchemaName sysname,@TableName sysname,@IndexName sysname,@DropIndexSql nvarchar(1000);
DECLARE obsolete_index_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT schema_name,table_name,index_name FROM @ObsoleteIndexes;
OPEN obsolete_index_cursor;
FETCH NEXT FROM obsolete_index_cursor INTO @SchemaName,@TableName,@IndexName;
WHILE @@FETCH_STATUS=0
BEGIN
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(QUOTENAME(@SchemaName)+'.'+QUOTENAME(@TableName)) AND name=@IndexName)
    BEGIN
        SET @DropIndexSql=N'DROP INDEX '+QUOTENAME(@IndexName)+N' ON '+QUOTENAME(@SchemaName)+N'.'+QUOTENAME(@TableName)+N';';
        EXEC sys.sp_executesql @DropIndexSql;
    END;
    FETCH NEXT FROM obsolete_index_cursor INTO @SchemaName,@TableName,@IndexName;
END;
CLOSE obsolete_index_cursor;
DEALLOCATE obsolete_index_cursor;
GO

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberVerification_evidence_attachment_id' AND parent_object_id = OBJECT_ID(N'core.MemberVerification'))
    ALTER TABLE core.MemberVerification DROP CONSTRAINT FK_MemberVerification_evidence_attachment_id;
GO
IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'core.MemberVerification') AND name = N'IX_MemberVerification_evidence_attachment_id')
    DROP INDEX IX_MemberVerification_evidence_attachment_id ON core.MemberVerification;
GO
IF COL_LENGTH(N'core.MemberVerification', N'evidence_attachment_id') IS NOT NULL
    EXEC sys.sp_rename N'core.MemberVerification.evidence_attachment_id', N'evidence_file_asset_id', N'COLUMN';
GO

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_PrivacyRequest_result_attachment_id' AND parent_object_id = OBJECT_ID(N'consent.PrivacyRequest'))
    ALTER TABLE consent.PrivacyRequest DROP CONSTRAINT FK_PrivacyRequest_result_attachment_id;
GO
IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'consent.PrivacyRequest') AND name = N'IX_PrivacyRequest_result_attachment_id')
    DROP INDEX IX_PrivacyRequest_result_attachment_id ON consent.PrivacyRequest;
GO
IF COL_LENGTH(N'consent.PrivacyRequest', N'result_attachment_id') IS NOT NULL
    EXEC sys.sp_rename N'consent.PrivacyRequest.result_attachment_id', N'result_file_asset_id', N'COLUMN';
GO
