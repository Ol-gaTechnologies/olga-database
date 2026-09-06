SET XACT_ABORT ON;
GO

DECLARE @Roles TABLE(role_name sysname, schema_name sysname);
INSERT @Roles VALUES
('olga_core_app','core'),('olga_identity_app','iam'),('olga_consent_app','consent'),('olga_event_app','event'),
('olga_social_app','social'),('olga_chat_app','chat'),('olga_storage_app','storage'),('olga_notification_app','notification'),('olga_nlp_app','nlp'),
('olga_moderation_app','moderation'),('olga_ops_worker','ops'),('olga_analytics_writer','analytics');
DECLARE @Role sysname,@Schema sysname,@Sql nvarchar(max);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT role_name,schema_name FROM @Roles;
OPEN c; FETCH NEXT FROM c INTO @Role,@Schema;
WHILE @@FETCH_STATUS=0
BEGIN
    IF DATABASE_PRINCIPAL_ID(@Role) IS NULL BEGIN SET @Sql=N'CREATE ROLE '+QUOTENAME(@Role)+N' AUTHORIZATION dbo;'; EXEC sys.sp_executesql @Sql; END;
    SET @Sql=N'GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::'+QUOTENAME(@Schema)+N' TO '+QUOTENAME(@Role)+N';'; EXEC sys.sp_executesql @Sql;
    FETCH NEXT FROM c INTO @Role,@Schema;
END
CLOSE c; DEALLOCATE c;
GO

IF DATABASE_PRINCIPAL_ID('olga_admin_reader') IS NULL CREATE ROLE olga_admin_reader AUTHORIZATION dbo;
GRANT SELECT ON admin.vw_MemberReview TO olga_admin_reader;
GRANT SELECT ON nlp.vw_MemberContextEligibility TO olga_nlp_app;
GRANT SELECT ON nlp.vw_MemberRelationship TO olga_nlp_app;
GRANT SELECT ON chat.vw_AuthorizedConversation TO olga_chat_app;
GRANT SELECT ON iam.Member TO olga_notification_app;
GRANT SELECT ON core.MemberProfile TO olga_nlp_app;
GRANT SELECT ON consent.MemberConsent TO olga_nlp_app;
GRANT SELECT ON event.EventMatchingPolicy TO olga_notification_app;
GRANT INSERT ON ops.OutboxEvent TO olga_social_app, olga_chat_app, olga_notification_app;
GRANT INSERT ON ops.OutboxEvent TO olga_storage_app;
GRANT INSERT ON ops.BackgroundJob TO olga_storage_app;
GRANT INSERT ON moderation.ContentScan TO olga_storage_app;
GRANT INSERT ON ops.AuditEvent TO olga_identity_app, olga_consent_app, olga_storage_app, olga_moderation_app;
GRANT INSERT ON ops.BackgroundJob TO olga_consent_app;
GRANT SELECT, UPDATE, DELETE ON storage.FileAsset TO olga_ops_worker;
GRANT SELECT, UPDATE, DELETE ON storage.FileAssetLink TO olga_ops_worker;
DENY UPDATE, DELETE ON ops.AuditEvent TO olga_ops_worker;
DENY INSERT, UPDATE, DELETE ON ops.RetentionPolicy TO olga_ops_worker;
DENY DELETE ON ops.RetentionExecution TO olga_ops_worker;
GRANT SELECT, INSERT, UPDATE ON ops.RetentionPolicy TO olga_consent_app;
DENY DELETE ON consent.PrivacyRequest TO olga_consent_app;
DENY DELETE ON consent.PrivacyRequestTask TO olga_consent_app;
DENY DELETE ON iam.Role TO olga_identity_app;
DENY DELETE ON iam.Permission TO olga_identity_app;
DENY DELETE ON iam.RolePermission TO olga_identity_app;
DENY DELETE ON iam.MemberRole TO olga_identity_app;
GO
