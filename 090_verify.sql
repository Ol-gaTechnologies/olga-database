SET NOCOUNT ON;
DECLARE @ExpectedTables int=58,@ExpectedViews int=4,@ExpectedProcedures int=8;
DECLARE @ActualTables int=(SELECT COUNT(*) FROM sys.tables WHERE schema_id IN (SELECT schema_id FROM sys.schemas WHERE name IN ('core','iam','consent','event','social','chat','notification','nlp','moderation','ops','analytics')));
DECLARE @ActualViews int=(SELECT COUNT(*) FROM sys.views WHERE object_id IN (OBJECT_ID('nlp.vw_MemberContextEligibility'),OBJECT_ID('nlp.vw_MemberRelationship'),OBJECT_ID('chat.vw_AuthorizedConversation'),OBJECT_ID('admin.vw_MemberReview')));
DECLARE @ActualProcedures int=(SELECT COUNT(*) FROM sys.procedures WHERE object_id IN (OBJECT_ID('nlp.GetRequesterIntent'),OBJECT_ID('nlp.GetEligibleCandidates'),OBJECT_ID('nlp.SaveMatchResults'),OBJECT_ID('nlp.SaveFeedback'),OBJECT_ID('social.AcceptConnectionRequest'),OBJECT_ID('chat.SaveMessage'),OBJECT_ID('event.PurgeExpiredPresence'),OBJECT_ID('notification.TryEnqueue')));
SELECT @ActualTables AS actual_tables,@ExpectedTables AS expected_tables,@ActualViews AS actual_views,@ExpectedViews AS expected_views,@ActualProcedures AS actual_procedures,@ExpectedProcedures AS expected_procedures;
IF @ActualTables<>@ExpectedTables THROW 50900,'Unexpected OLGA table count.',1;
IF @ActualViews<>@ExpectedViews THROW 50901,'One or more controlled views are missing.',1;
IF @ActualProcedures<>@ExpectedProcedures THROW 50902,'One or more controlled procedures are missing.',1;
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE is_not_trusted=1) THROW 50903,'One or more foreign keys are not trusted.',1;
IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE is_not_trusted=1) THROW 50904,'One or more check constraints are not trusted.',1;
IF EXISTS (SELECT 1 FROM sys.sql_expression_dependencies d LEFT JOIN sys.objects o ON o.object_id=d.referenced_id WHERE d.referenced_id IS NULL AND d.referenced_entity_name IS NOT NULL AND OBJECT_SCHEMA_NAME(d.referencing_id) IN ('nlp','chat','admin','social','event','notification'))
    PRINT 'Review unresolved dependencies reported by sys.sql_expression_dependencies.';
PRINT 'OLGA Connect Azure SQL baseline verification passed.';
GO
