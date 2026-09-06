SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'chat.Attachment', N'U') IS NOT NULL
BEGIN
    EXEC(N'
        INSERT storage.FileAsset (
            file_asset_id, community_id, owner_member_id, purpose_code, container_name,
            blob_path, blob_path_hash, file_name, media_type, size_bytes, sha256,
            classification, scan_status, lifecycle_status, expires_at, created_at, updated_at
        )
        SELECT a.attachment_id, m.community_id, a.owner_member_id, ''CHAT_FILE'', ''legacy-chat'',
               a.blob_path, a.blob_path_hash, a.file_name, a.media_type, a.size_bytes, a.sha256,
               ''CONFIDENTIAL'', a.scan_status,
               CASE a.scan_status WHEN ''CLEAN'' THEN ''AVAILABLE'' WHEN ''PENDING'' THEN ''UPLOADING'' ELSE ''QUARANTINED'' END,
               a.expires_at, a.created_at, a.updated_at
        FROM chat.Attachment a
        JOIN iam.Member m ON m.member_id = a.owner_member_id
        WHERE NOT EXISTS (SELECT 1 FROM storage.FileAsset f WHERE f.file_asset_id = a.attachment_id);

        INSERT storage.FileAssetLink (file_asset_id, resource_type, resource_id, relationship_type, linked_by, created_at)
        SELECT a.attachment_id, ''MESSAGE'', a.message_id, ''PRIMARY'', a.owner_member_id, a.created_at
        FROM chat.Attachment a
        WHERE a.message_id IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM storage.FileAssetLink l
              WHERE l.file_asset_id = a.attachment_id AND l.resource_type = ''MESSAGE''
                AND l.resource_id = a.message_id AND l.relationship_type = ''PRIMARY''
          );
    ');

    DECLARE @MissingAttachmentCount int;
    EXEC sys.sp_executesql
        N'SELECT @Count = COUNT(*) FROM chat.Attachment a WHERE NOT EXISTS (SELECT 1 FROM storage.FileAsset f WHERE f.file_asset_id = a.attachment_id);',
        N'@Count int OUTPUT', @Count = @MissingAttachmentCount OUTPUT;
    IF @MissingAttachmentCount <> 0
        THROW 50702, 'One or more legacy attachments could not be migrated to storage.FileAsset.', 1;

    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Attachment_message_id' AND parent_object_id = OBJECT_ID(N'chat.Attachment'))
        EXEC(N'ALTER TABLE chat.Attachment DROP CONSTRAINT FK_Attachment_message_id;');
    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Attachment_owner_member_id' AND parent_object_id = OBJECT_ID(N'chat.Attachment'))
        EXEC(N'ALTER TABLE chat.Attachment DROP CONSTRAINT FK_Attachment_owner_member_id;');

    EXEC(N'DROP TABLE chat.Attachment;');
END;
GO

INSERT storage.FileAssetLink (file_asset_id, resource_type, resource_id, relationship_type, linked_by)
SELECT v.evidence_file_asset_id, 'MEMBER_VERIFICATION', v.verification_id, 'EVIDENCE', v.reviewed_by
FROM core.MemberVerification v
WHERE v.evidence_file_asset_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM storage.FileAssetLink l
      WHERE l.file_asset_id = v.evidence_file_asset_id AND l.resource_type = 'MEMBER_VERIFICATION'
        AND l.resource_id = v.verification_id AND l.relationship_type = 'EVIDENCE'
  );
GO

INSERT storage.FileAssetLink (file_asset_id, resource_type, resource_id, relationship_type)
SELECT p.result_file_asset_id, 'PRIVACY_REQUEST', p.privacy_request_id, 'RESULT'
FROM consent.PrivacyRequest p
WHERE p.result_file_asset_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM storage.FileAssetLink l
      WHERE l.file_asset_id = p.result_file_asset_id AND l.resource_type = 'PRIVACY_REQUEST'
        AND l.resource_id = p.privacy_request_id AND l.relationship_type = 'RESULT'
  );
GO

IF EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 0 AND name = N'OLGA.SchemaVersion')
    EXEC sys.sp_updateextendedproperty @name=N'OLGA.SchemaVersion', @value=N'2.3';
ELSE
    EXEC sys.sp_addextendedproperty @name=N'OLGA.SchemaVersion', @value=N'2.3';
GO
