SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE nlp.GetRequesterIntent
    @MemberId varchar(64), @IntentId varchar(64), @ContextId varchar(64)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT i.*, e.model_version, e.dimensions, e.normalized_hash AS embedding_hash, e.embedding
    FROM nlp.NlpIntent i
    JOIN nlp.NlpEmbedding e ON e.intent_id = i.intent_id AND e.status = 'ACTIVE'
    WHERE i.intent_id = @IntentId AND i.member_id = @MemberId AND i.context_id = @ContextId
      AND i.status = 'MATCH_READY' AND i.expires_at > SYSUTCDATETIME();
END;
GO

CREATE OR ALTER PROCEDURE nlp.GetEligibleCandidates
    @RequesterId varchar(64), @ContextId varchar(64), @MaxRows int = 200
AS
BEGIN
    SET NOCOUNT ON;
    IF @MaxRows NOT BETWEEN 1 AND 200 THROW 50001, 'MaxRows must be between 1 and 200.', 1;
    WITH EligibleMembers AS (
        SELECT TOP (@MaxRows) m.member_id
        FROM nlp.vw_MemberContextEligibility m
        WHERE m.context_id = @ContextId AND m.member_id <> @RequesterId
          AND m.is_live = 1 AND m.is_visible = 1 AND m.has_consent = 1 AND m.is_suspended = 0 AND m.is_deleted = 0
          AND NOT EXISTS (
              SELECT 1 FROM nlp.vw_MemberRelationship r
              WHERE r.context_id = 'GLOBAL' AND r.member_id = @RequesterId AND r.other_member_id = m.member_id
                AND (r.is_blocked = 1 OR r.is_connected = 1)
          )
          AND NOT EXISTS (
              SELECT 1 FROM nlp.MatchSuppression s
              WHERE s.starts_at <= SYSUTCDATETIME() AND (s.ends_at IS NULL OR s.ends_at > SYSUTCDATETIME())
                AND (s.member_id = m.member_id OR s.context_id = @ContextId)
          )
        ORDER BY m.member_id
    )
    SELECT i.*, e.model_version, e.dimensions, e.normalized_hash AS embedding_hash, e.embedding
    FROM EligibleMembers m
    JOIN nlp.NlpIntent i ON i.member_id = m.member_id AND i.context_id = @ContextId
    JOIN nlp.NlpEmbedding e ON e.intent_id = i.intent_id AND e.status = 'ACTIVE'
    WHERE i.intent_type = 'OFFER' AND i.status = 'MATCH_READY' AND i.expires_at > SYSUTCDATETIME()
    ORDER BY i.updated_at DESC;
END;
GO

CREATE OR ALTER PROCEDURE nlp.SaveMatchResults
    @RequestId varchar(64), @RequesterId varchar(64), @ResultsJson nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF ISJSON(@ResultsJson) <> 1 THROW 50002, 'ResultsJson must be valid JSON.', 1;
    BEGIN TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM nlp.NlpMatchResult WITH (UPDLOCK, HOLDLOCK) WHERE request_id = @RequestId)
    BEGIN
        INSERT nlp.NlpMatchResult(request_id, requester_id, candidate_id, rank, semantic_score, reciprocal_score, final_score, label, reason_codes, reason_text, model_version, preprocessing_version, ranking_version, policy_status)
        SELECT @RequestId, @RequesterId, candidate_id, rank, semantic_score, reciprocal_score, final_score, label, reason_codes, reason_text, model_version, preprocessing_version, ranking_version, COALESCE(policy_status, 'ELIGIBLE')
        FROM OPENJSON(@ResultsJson) WITH (
            candidate_id varchar(64), rank smallint, semantic_score decimal(8,7), reciprocal_score decimal(8,7), final_score decimal(8,7),
            label varchar(32), reason_codes nvarchar(1000) AS JSON, reason_text nvarchar(2000), model_version varchar(128),
            preprocessing_version varchar(128), ranking_version varchar(128), policy_status varchar(24)
        );
        UPDATE nlp.MatchRequest
        SET status = 'COMPLETED', candidate_count = (SELECT COUNT(*) FROM nlp.NlpMatchResult WHERE request_id = @RequestId),
            completed_at = SYSUTCDATETIME(), updated_at = SYSUTCDATETIME()
        WHERE request_id = @RequestId AND requester_id = @RequesterId;
    END;
    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE nlp.SaveFeedback
    @MatchResultId bigint, @RequesterId varchar(64), @Label varchar(64), @ReasonCode varchar(64) = NULL,
    @Reason nvarchar(1000) = NULL, @SupersedesFeedbackId bigint = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @Label NOT IN ('USEFUL','NOT_USEFUL','INAPPROPRIATE') THROW 50003, 'Unsupported feedback label.', 1;
    DECLARE @RequestId varchar(64), @CandidateId varchar(64);
    SELECT @RequestId = request_id, @CandidateId = candidate_id
    FROM nlp.NlpMatchResult WHERE match_result_id = @MatchResultId AND requester_id = @RequesterId;
    IF @RequestId IS NULL THROW 50004, 'Match result not found for requester.', 1;
    IF @SupersedesFeedbackId IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM nlp.NlpFeedback WHERE feedback_id = @SupersedesFeedbackId
          AND requester_id = @RequesterId AND match_result_id = @MatchResultId
    ) THROW 50005, 'Feedback correction does not reference the same requester and match result.', 1;
    INSERT nlp.NlpFeedback(supersedes_feedback_id, match_result_id, request_id, requester_id, candidate_id, label, reason_code, reason)
    VALUES(@SupersedesFeedbackId, @MatchResultId, @RequestId, @RequesterId, @CandidateId, @Label, @ReasonCode, @Reason);
END;
GO

CREATE OR ALTER PROCEDURE social.AcceptConnectionRequest
    @ConnectionRequestId varchar(64), @RecipientMemberId varchar(64), @ConnectionId varchar(64), @ConversationId varchar(64)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @SenderId varchar(64), @LowId varchar(64), @HighId varchar(64);
    BEGIN TRANSACTION;
    SELECT @SenderId = sender_member_id FROM social.ConnectionRequest WITH (UPDLOCK, HOLDLOCK)
    WHERE connection_request_id = @ConnectionRequestId AND recipient_member_id = @RecipientMemberId
      AND status = 'PENDING' AND expires_at > SYSUTCDATETIME();
    IF @SenderId IS NULL THROW 50100, 'Pending connection request not found.', 1;
    IF EXISTS (SELECT 1 FROM social.MemberBlock WHERE removed_at IS NULL AND ((blocker_member_id=@SenderId AND blocked_member_id=@RecipientMemberId) OR (blocker_member_id=@RecipientMemberId AND blocked_member_id=@SenderId)))
        THROW 50101, 'Connection is not eligible.', 1;
    SET @LowId = CASE WHEN @SenderId < @RecipientMemberId THEN @SenderId ELSE @RecipientMemberId END;
    SET @HighId = CASE WHEN @SenderId < @RecipientMemberId THEN @RecipientMemberId ELSE @SenderId END;
    UPDATE social.ConnectionRequest SET status='ACCEPTED', responded_at=SYSUTCDATETIME(), updated_at=SYSUTCDATETIME() WHERE connection_request_id=@ConnectionRequestId;
    INSERT social.Connection(connection_id,member_low_id,member_high_id,accepted_request_id) VALUES(@ConnectionId,@LowId,@HighId,@ConnectionRequestId);
    INSERT chat.Conversation(conversation_id,connection_id) VALUES(@ConversationId,@ConnectionId);
    INSERT chat.ConversationParticipant(conversation_id,member_id) VALUES(@ConversationId,@SenderId),(@ConversationId,@RecipientMemberId);
    INSERT ops.OutboxEvent(outbox_event_id,aggregate_type,aggregate_id,event_type,payload_json)
    VALUES(CONVERT(varchar(64),NEWID()),'CONNECTION',@ConnectionId,'connection.accepted',JSON_OBJECT('connectionId':@ConnectionId,'conversationId':@ConversationId));
    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE chat.SaveMessage
    @MessageId varchar(64), @ConversationId varchar(64), @SenderMemberId varchar(64),
    @MessageType varchar(20), @Body nvarchar(max) = NULL, @ClientSentAt datetimeoffset(7) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @MessageType NOT IN ('TEXT','FILE','SYSTEM') THROW 50200, 'Unsupported message type.', 1;
    IF NOT EXISTS (SELECT 1 FROM chat.vw_AuthorizedConversation WHERE conversation_id=@ConversationId AND member_id=@SenderMemberId AND can_send=1)
        THROW 50201, 'Member is not authorized to send to this conversation.', 1;
    BEGIN TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM chat.Message WITH (UPDLOCK,HOLDLOCK) WHERE message_id=@MessageId)
    BEGIN
        INSERT chat.Message(message_id,conversation_id,sender_member_id,message_type,body,client_sent_at)
        VALUES(@MessageId,@ConversationId,@SenderMemberId,@MessageType,@Body,@ClientSentAt);
        UPDATE chat.Conversation SET last_message_at=SYSUTCDATETIME(),updated_at=SYSUTCDATETIME() WHERE conversation_id=@ConversationId;
        INSERT ops.OutboxEvent(outbox_event_id,aggregate_type,aggregate_id,event_type,payload_json)
        VALUES(CONVERT(varchar(64),NEWID()),'MESSAGE',@MessageId,'chat.message.created',JSON_OBJECT('messageId':@MessageId,'conversationId':@ConversationId));
    END;
    COMMIT TRANSACTION;
    SELECT * FROM chat.Message WHERE message_id=@MessageId;
END;
GO

CREATE OR ALTER PROCEDURE event.PurgeExpiredPresence
    @BatchSize int = 5000
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @BatchSize NOT BETWEEN 1 AND 20000 THROW 50300, 'BatchSize must be between 1 and 20000.', 1;
    DELETE TOP (@BatchSize) FROM event.EventPresence WHERE expires_at <= SYSUTCDATETIME();
    SELECT @@ROWCOUNT AS deleted_rows;
END;
GO

CREATE OR ALTER PROCEDURE notification.TryEnqueue
    @NotificationId varchar(64), @MemberId varchar(64), @PurposeCode varchar(64), @Channel varchar(16),
    @ResourceType varchar(32), @ResourceId varchar(64), @TemplateCode varchar(64), @DedupeKey varchar(160),
    @ContextId varchar(64) = NULL, @SourceConfidence decimal(6,5) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @Now datetimeoffset(7)=SYSUTCDATETIME(), @CommunityId varchar(64), @PolicyId bigint,
            @OptOut bit, @QuietBehavior varchar(16), @DedupeSeconds int, @MaxHour smallint, @MaxDay smallint,
            @Ttl int, @EventPolicyId bigint=NULL, @AlertThreshold decimal(6,5)=NULL,
            @EventMaxHour smallint=NULL, @EventMaxTotal smallint=NULL, @MinInterval smallint=NULL,
            @Suppression varchar(64)=NULL, @ScheduledAt datetimeoffset(7), @BucketStart datetimeoffset(7),
            @PushEnabled bit=1, @EmailEnabled bit=1, @QuietStart time=NULL, @QuietEnd time=NULL, @TimezoneId varchar(64)=NULL;
    SELECT @CommunityId=community_id FROM iam.Member WHERE member_id=@MemberId AND status='ACTIVE';
    IF @CommunityId IS NULL THROW 50400, 'Active member not found.', 1;
    SELECT TOP(1) @PolicyId=notification_policy_id,@OptOut=member_opt_out_allowed,@QuietBehavior=quiet_hours_behavior,
           @DedupeSeconds=dedupe_window_seconds,@MaxHour=max_per_hour,@MaxDay=max_per_day,@Ttl=ttl_minutes
    FROM notification.NotificationPolicy
    WHERE status='ACTIVE' AND purpose_code=@PurposeCode AND channel=@Channel
      AND (community_id=@CommunityId OR community_id IS NULL) AND effective_from<=@Now AND (effective_to IS NULL OR effective_to>@Now)
    ORDER BY CASE WHEN community_id=@CommunityId THEN 0 ELSE 1 END, policy_version DESC;
    IF @PolicyId IS NULL THROW 50401, 'No active notification policy.', 1;
    IF @ContextId IS NOT NULL AND @ContextId<>'GENERAL'
        SELECT TOP(1) @EventPolicyId=event_matching_policy_id,@AlertThreshold=alert_confidence_threshold,
               @EventMaxHour=max_match_alerts_per_hour,@EventMaxTotal=max_match_alerts_per_event,@MinInterval=minimum_alert_interval_minutes
        FROM event.EventMatchingPolicy
        WHERE event_id=@ContextId AND status='ACTIVE' AND effective_from<=@Now AND (effective_to IS NULL OR effective_to>@Now)
        ORDER BY policy_version DESC;
    SELECT @PushEnabled=push_enabled,@EmailEnabled=email_enabled,@QuietStart=quiet_start_local,@QuietEnd=quiet_end_local,@TimezoneId=timezone_id
    FROM notification.NotificationPreference WHERE member_id=@MemberId AND purpose_code=@PurposeCode;
    SET @ScheduledAt=@Now;
    SET @BucketStart=DATEADD(SECOND, CONVERT(int,DATEDIFF_BIG(SECOND,'20000101',@Now)/@DedupeSeconds)*@DedupeSeconds, CONVERT(datetimeoffset(7),'20000101'));
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    BEGIN TRANSACTION;
    IF EXISTS (SELECT 1 FROM notification.Notification WITH (UPDLOCK,HOLDLOCK) WHERE member_id=@MemberId AND channel=@Channel AND dedupe_key=@DedupeKey AND dedupe_bucket_start=@BucketStart)
    BEGIN SELECT TOP(1) notification_id,status,suppression_reason FROM notification.Notification WHERE member_id=@MemberId AND channel=@Channel AND dedupe_key=@DedupeKey AND dedupe_bucket_start=@BucketStart; COMMIT; RETURN; END;
    IF @OptOut=1 AND ((@Channel='PUSH' AND @PushEnabled=0) OR (@Channel='EMAIL' AND @EmailEnabled=0)) SET @Suppression='OPT_OUT';
    IF @EventPolicyId IS NOT NULL AND @SourceConfidence IS NOT NULL AND @SourceConfidence<@AlertThreshold SET @Suppression='BELOW_THRESHOLD';
    IF @Suppression IS NULL AND (SELECT COUNT(*) FROM notification.Notification WITH (UPDLOCK,HOLDLOCK) WHERE member_id=@MemberId AND notification_policy_id=@PolicyId AND created_at>DATEADD(HOUR,-1,@Now) AND status IN ('PENDING','SENT','DELIVERED'))>=@MaxHour SET @Suppression='RATE_LIMIT';
    IF @Suppression IS NULL AND (SELECT COUNT(*) FROM notification.Notification WITH (UPDLOCK,HOLDLOCK) WHERE member_id=@MemberId AND notification_policy_id=@PolicyId AND created_at>DATEADD(DAY,-1,@Now) AND status IN ('PENDING','SENT','DELIVERED'))>=@MaxDay SET @Suppression='RATE_LIMIT';
    IF @Suppression IS NULL AND @EventPolicyId IS NOT NULL AND (SELECT COUNT(*) FROM notification.Notification WITH (UPDLOCK,HOLDLOCK) WHERE member_id=@MemberId AND event_matching_policy_id=@EventPolicyId AND created_at>DATEADD(HOUR,-1,@Now) AND status IN ('PENDING','SENT','DELIVERED'))>=@EventMaxHour SET @Suppression='RATE_LIMIT';
    IF @Suppression IS NULL AND @EventPolicyId IS NOT NULL AND (SELECT COUNT(*) FROM notification.Notification WITH (UPDLOCK,HOLDLOCK) WHERE member_id=@MemberId AND event_matching_policy_id=@EventPolicyId AND status IN ('PENDING','SENT','DELIVERED'))>=@EventMaxTotal SET @Suppression='RATE_LIMIT';
    IF @Suppression IS NULL AND @EventPolicyId IS NOT NULL AND EXISTS (SELECT 1 FROM notification.Notification WITH (UPDLOCK,HOLDLOCK) WHERE member_id=@MemberId AND event_matching_policy_id=@EventPolicyId AND created_at>DATEADD(MINUTE,-@MinInterval,@Now) AND status IN ('PENDING','SENT','DELIVERED')) SET @Suppression='RATE_LIMIT';
    IF @Suppression IS NULL AND @QuietStart IS NOT NULL AND @QuietEnd IS NOT NULL AND @TimezoneId IS NOT NULL
    BEGIN
        DECLARE @LocalNow datetimeoffset(7)=@Now AT TIME ZONE @TimezoneId, @LocalTime time=CONVERT(time,@Now AT TIME ZONE @TimezoneId);
        DECLARE @InQuiet bit=CASE WHEN @QuietStart<@QuietEnd AND @LocalTime>=@QuietStart AND @LocalTime<@QuietEnd THEN 1 WHEN @QuietStart>@QuietEnd AND (@LocalTime>=@QuietStart OR @LocalTime<@QuietEnd) THEN 1 ELSE 0 END;
        IF @InQuiet=1 AND @QuietBehavior='SUPPRESS' SET @Suppression='QUIET_HOURS';
        IF @InQuiet=1 AND @QuietBehavior='DEFER'
        BEGIN
            DECLARE @TargetDate date=CASE WHEN @LocalTime<@QuietEnd THEN CONVERT(date,@LocalNow) ELSE DATEADD(DAY,1,CONVERT(date,@LocalNow)) END;
            DECLARE @LocalEnd datetime2=DATEADD(SECOND,DATEDIFF(SECOND,CONVERT(time,'00:00'),@QuietEnd),CONVERT(datetime2,@TargetDate));
            SET @ScheduledAt=SWITCHOFFSET(@LocalEnd AT TIME ZONE @TimezoneId,'+00:00');
        END;
    END;
    INSERT notification.Notification(notification_id,member_id,notification_policy_id,event_matching_policy_id,purpose_code,channel,resource_type,resource_id,template_code,dedupe_key,dedupe_bucket_start,source_confidence,context_id,status,scheduled_at,expires_at,suppression_reason)
    VALUES(@NotificationId,@MemberId,@PolicyId,@EventPolicyId,@PurposeCode,@Channel,@ResourceType,@ResourceId,@TemplateCode,@DedupeKey,@BucketStart,@SourceConfidence,@ContextId,CASE WHEN @Suppression IS NULL THEN 'PENDING' ELSE 'SUPPRESSED' END,@ScheduledAt,DATEADD(MINUTE,@Ttl,@Now),@Suppression);
    IF @Suppression IS NULL INSERT ops.OutboxEvent(outbox_event_id,aggregate_type,aggregate_id,event_type,payload_json) VALUES(CONVERT(varchar(64),NEWID()),'NOTIFICATION',@NotificationId,'notification.queued',JSON_OBJECT('notificationId':@NotificationId));
    COMMIT TRANSACTION;
    SELECT notification_id,status,scheduled_at,expires_at,suppression_reason FROM notification.Notification WHERE notification_id=@NotificationId;
END;
GO
