SET NOCOUNT ON;
DECLARE @ExpectedTables int=66,@ExpectedViews int=4,@ExpectedProcedures int=8,@ExpectedTriggers int=4,@ExpectedSequences int=2;
DECLARE @ProductSchemas TABLE(schema_name sysname PRIMARY KEY);
INSERT @ProductSchemas VALUES ('core'),('iam'),('consent'),('event'),('social'),('chat'),('storage'),('notification'),('nlp'),('moderation'),('ops'),('analytics');

DECLARE @ExpectedTableList TABLE(schema_name sysname,table_name sysname,PRIMARY KEY(schema_name,table_name));
INSERT @ExpectedTableList VALUES
('core','Community'),('core','Organization'),('core','OrganizationMember'),('core','MemberProfile'),('core','Sector'),('core','MemberSector'),('core','MemberGeography'),('core','ProfileFieldVisibility'),('core','MemberVerification'),
('iam','Member'),('iam','MemberIdentity'),('iam','Role'),('iam','Permission'),('iam','RolePermission'),('iam','MemberRole'),('iam','MemberDevice'),('iam','AuthSession'),
('consent','ConsentPolicy'),('consent','MemberConsent'),('consent','PrivacyRequest'),('consent','PrivacyRequestTask'),
('event','Venue'),('event','Event'),('event','EventMatchingPolicy'),('event','EventRegistration'),('event','LiveModeSession'),('event','EventPresence'),
('social','ConnectionRequest'),('social','Connection'),('social','MemberBlock'),('social','MemberReport'),
('chat','Conversation'),('chat','ConversationParticipant'),('chat','Message'),('chat','MessageReceipt'),
('storage','FileAsset'),('storage','FileAssetLink'),
('notification','NotificationPolicy'),('notification','NotificationPreference'),('notification','PushToken'),('notification','Notification'),('notification','NotificationDeliveryAttempt'),
('nlp','NlpIntent'),('nlp','NlpEmbedding'),('nlp','NlpModelVersion'),('nlp','NlpRankingConfig'),('nlp','NlpProcessingJob'),('nlp','MatchRequest'),('nlp','NlpMatchResult'),('nlp','NlpFeedback'),('nlp','MatchSuppression'),('nlp','EvaluationDataset'),('nlp','EvaluationPair'),('nlp','EvaluationRun'),
('moderation','ModerationCase'),('moderation','ModerationAction'),('moderation','ContentRule'),('moderation','ContentScan'),
('ops','OutboxEvent'),('ops','IdempotencyRecord'),('ops','BackgroundJob'),('ops','SyncChange'),('ops','RetentionPolicy'),('ops','RetentionExecution'),('ops','AuditEvent'),
('analytics','ProductEvent');

DECLARE @ActualTables int=(SELECT COUNT(*) FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id JOIN @ProductSchemas p ON p.schema_name=s.name);
DECLARE @ActualViews int=(SELECT COUNT(*) FROM sys.views WHERE object_id IN (OBJECT_ID('nlp.vw_MemberContextEligibility'),OBJECT_ID('nlp.vw_MemberRelationship'),OBJECT_ID('chat.vw_AuthorizedConversation'),OBJECT_ID('admin.vw_MemberReview')));
DECLARE @ActualProcedures int=(SELECT COUNT(*) FROM sys.procedures WHERE object_id IN (OBJECT_ID('nlp.GetRequesterIntent'),OBJECT_ID('nlp.GetEligibleCandidates'),OBJECT_ID('nlp.SaveMatchResults'),OBJECT_ID('nlp.SaveFeedback'),OBJECT_ID('social.AcceptConnectionRequest'),OBJECT_ID('chat.SaveMessage'),OBJECT_ID('event.PurgeExpiredPresence'),OBJECT_ID('notification.TryEnqueue')));
DECLARE @ActualTriggers int=(SELECT COUNT(*) FROM sys.triggers WHERE object_id IN (OBJECT_ID('storage.trg_FileAssetLink_ResourceIntegrity'),OBJECT_ID('consent.trg_PrivacyRequest_CompletionGuard'),OBJECT_ID('consent.trg_PrivacyRequestTask_CompletedRequestGuard'),OBJECT_ID('ops.trg_RetentionPolicy_ImmutableActive')));
DECLARE @ActualSequences int=(SELECT COUNT(*) FROM sys.sequences WHERE object_id IN (OBJECT_ID('chat.MessageSequence'),OBJECT_ID('ops.SyncChangeSequence')));

SELECT @ActualTables AS actual_tables,@ExpectedTables AS expected_tables,@ActualViews AS actual_views,@ExpectedViews AS expected_views,
       @ActualProcedures AS actual_procedures,@ExpectedProcedures AS expected_procedures,@ActualTriggers AS actual_triggers,@ExpectedTriggers AS expected_triggers,
       @ActualSequences AS actual_sequences,@ExpectedSequences AS expected_sequences;

IF @ActualTables<>@ExpectedTables THROW 50900,'Unexpected OLGA product-table count.',1;
IF EXISTS (SELECT 1 FROM @ExpectedTableList e WHERE OBJECT_ID(QUOTENAME(e.schema_name)+'.'+QUOTENAME(e.table_name),'U') IS NULL)
    THROW 50901,'One or more required v2.3 tables are missing.',1;
IF EXISTS (
    SELECT 1 FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id JOIN @ProductSchemas p ON p.schema_name=s.name
    WHERE NOT EXISTS (SELECT 1 FROM @ExpectedTableList e WHERE e.schema_name=s.name AND e.table_name=t.name)
) THROW 50902,'An unexpected table exists in a product schema.',1;
IF @ActualViews<>@ExpectedViews THROW 50903,'One or more controlled views are missing.',1;
IF @ActualProcedures<>@ExpectedProcedures THROW 50904,'One or more controlled procedures are missing.',1;
IF @ActualTriggers<>@ExpectedTriggers THROW 50905,'One or more v2.3 invariant triggers are missing.',1;
IF @ActualSequences<>@ExpectedSequences THROW 50906,'One or more required sequences are missing.',1;
IF OBJECT_ID('chat.Attachment','U') IS NOT NULL THROW 50907,'Legacy chat.Attachment must not remain after the v2.3 upgrade.',1;
IF COL_LENGTH('iam.MemberIdentity','provider_subject') IS NOT NULL THROW 50908,'Plaintext identity subject column remains.',1;
IF COL_LENGTH('iam.MemberIdentity','provider_subject_hash') IS NULL OR COL_LENGTH('iam.MemberIdentity','provider_subject_ciphertext') IS NULL THROW 50909,'Protected identity subject columns are missing.',1;
IF COL_LENGTH('core.MemberVerification','evidence_file_asset_id') IS NULL OR COL_LENGTH('consent.PrivacyRequest','result_file_asset_id') IS NULL THROW 50910,'FileAsset references are incomplete.',1;
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE is_not_trusted=1 OR is_disabled=1) THROW 50911,'One or more foreign keys are untrusted or disabled.',1;
IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE is_not_trusted=1 OR is_disabled=1) THROW 50912,'One or more check constraints are untrusted or disabled.',1;
IF EXISTS (SELECT 1 FROM sys.triggers WHERE parent_class=1 AND is_disabled=1 AND OBJECT_SCHEMA_NAME(parent_id) IN ('storage','consent','ops')) THROW 50913,'One or more v2.3 invariant triggers are disabled.',1;
IF EXISTS (SELECT 1 FROM sys.indexes WHERE is_disabled=1 AND object_id IN (SELECT t.object_id FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id JOIN @ProductSchemas p ON p.schema_name=s.name)) THROW 50914,'One or more product-table indexes are disabled.',1;
IF NOT EXISTS (SELECT 1 FROM iam.Permission WHERE status='ACTIVE') OR NOT EXISTS (SELECT 1 FROM iam.RolePermission WHERE revoked_at IS NULL) THROW 50915,'Authorization permission seeds are missing.',1;
IF EXISTS (SELECT 1 FROM sys.sql_expression_dependencies d WHERE d.referenced_id IS NULL AND d.referenced_entity_name IS NOT NULL AND OBJECT_SCHEMA_NAME(d.referencing_id) IN ('nlp','chat','storage','admin','social','event','notification','consent','ops'))
    THROW 50916,'One or more database objects have unresolved dependencies.',1;

IF EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 0 AND name = N'OLGA.SchemaVersion')
    EXEC sys.sp_updateextendedproperty @name=N'OLGA.SchemaVersion', @value=N'2.3';
ELSE
    EXEC sys.sp_addextendedproperty @name=N'OLGA.SchemaVersion', @value=N'2.3';

PRINT 'OLGA Connect Azure SQL v2.3 baseline verification passed.';
GO
