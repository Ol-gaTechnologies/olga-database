SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER VIEW nlp.vw_MemberContextEligibility
AS
WITH GrantedConsent AS (
    SELECT DISTINCT mc.member_id, cp.purpose_code
    FROM consent.MemberConsent mc
    JOIN consent.ConsentPolicy cp ON cp.policy_id = mc.policy_id
    WHERE mc.decision = 'GRANTED' AND mc.withdrawn_at IS NULL
      AND cp.effective_from <= SYSUTCDATETIME() AND cp.retired_at IS NULL
), ActiveEventPolicy AS (
    SELECT p.*
    FROM event.EventMatchingPolicy p
    WHERE p.status = 'ACTIVE' AND p.effective_from <= SYSUTCDATETIME()
      AND (p.effective_to IS NULL OR p.effective_to > SYSUTCDATETIME())
)
SELECT m.member_id, CAST('GENERAL' AS varchar(64)) AS context_id,
       CAST(1 AS bit) AS is_live,
       CAST(CASE WHEN m.status = 'ACTIVE' AND p.profile_status = 'ACTIVE' AND p.visibility <> 'HIDDEN' THEN 1 ELSE 0 END AS bit) AS is_visible,
       CAST(CASE WHEN gc.member_id IS NOT NULL THEN 1 ELSE 0 END AS bit) AS has_consent,
       CAST(CASE WHEN m.status = 'SUSPENDED' OR m.suspended_at IS NOT NULL THEN 1 ELSE 0 END AS bit) AS is_suspended,
       CAST(CASE WHEN m.status = 'DELETED' OR m.deleted_at IS NOT NULL THEN 1 ELSE 0 END AS bit) AS is_deleted
FROM iam.Member m
JOIN core.MemberProfile p ON p.member_id = m.member_id
LEFT JOIN GrantedConsent gc ON gc.member_id = m.member_id AND gc.purpose_code IN ('MATCH','MATCHING')
UNION ALL
SELECT m.member_id, e.event_id,
       CAST(CASE WHEN ep.live_mode_required = 0 OR (ls.status = 'ACTIVE' AND ls.active_until > SYSUTCDATETIME()) THEN 1 ELSE 0 END AS bit) AS is_live,
       CAST(CASE WHEN m.status = 'ACTIVE' AND p.profile_status = 'ACTIVE' AND p.visibility <> 'HIDDEN' THEN 1 ELSE 0 END AS bit) AS is_visible,
       CAST(CASE WHEN gc.member_id IS NOT NULL THEN 1 ELSE 0 END AS bit) AS has_consent,
       CAST(CASE WHEN m.status = 'SUSPENDED' OR m.suspended_at IS NOT NULL THEN 1 ELSE 0 END AS bit) AS is_suspended,
       CAST(CASE WHEN m.status = 'DELETED' OR m.deleted_at IS NOT NULL THEN 1 ELSE 0 END AS bit) AS is_deleted
FROM event.Event e
JOIN ActiveEventPolicy ep ON ep.event_id = e.event_id
JOIN event.EventRegistration er ON er.event_id = e.event_id
JOIN iam.Member m ON m.member_id = er.member_id
JOIN core.MemberProfile p ON p.member_id = m.member_id
LEFT JOIN event.LiveModeSession ls ON ls.event_id = e.event_id AND ls.member_id = m.member_id AND ls.status = 'ACTIVE'
LEFT JOIN GrantedConsent gc ON gc.member_id = m.member_id AND gc.purpose_code IN ('LIVE_MODE','MATCH','MATCHING')
WHERE e.status IN ('PUBLISHED','ACTIVE')
  AND (ep.registration_required = 0 OR er.status IN ('REGISTERED','CHECKED_IN'))
  AND (ep.check_in_required = 0 OR er.status = 'CHECKED_IN');
GO

CREATE OR ALTER VIEW nlp.vw_MemberRelationship
AS
SELECT c.member_low_id AS member_id, c.member_high_id AS other_member_id,
       CAST('GLOBAL' AS varchar(64)) AS context_id, CAST(0 AS bit) AS is_blocked, CAST(1 AS bit) AS is_connected
FROM social.Connection c WHERE c.status = 'ACTIVE'
UNION ALL
SELECT c.member_high_id, c.member_low_id, CAST('GLOBAL' AS varchar(64)), CAST(0 AS bit), CAST(1 AS bit)
FROM social.Connection c WHERE c.status = 'ACTIVE'
UNION ALL
SELECT b.blocker_member_id, b.blocked_member_id, CAST('GLOBAL' AS varchar(64)), CAST(1 AS bit), CAST(0 AS bit)
FROM social.MemberBlock b WHERE b.removed_at IS NULL
UNION ALL
SELECT b.blocked_member_id, b.blocker_member_id, CAST('GLOBAL' AS varchar(64)), CAST(1 AS bit), CAST(0 AS bit)
FROM social.MemberBlock b WHERE b.removed_at IS NULL;
GO

CREATE OR ALTER VIEW chat.vw_AuthorizedConversation
AS
SELECT cp.conversation_id, cp.member_id, c.connection_id, c.status AS conversation_status,
       CAST(CASE WHEN c.status = 'ACTIVE' AND cn.status = 'ACTIVE' AND cp.left_at IS NULL
                      AND NOT EXISTS (
                          SELECT 1 FROM social.MemberBlock b
                          WHERE b.removed_at IS NULL
                            AND ((b.blocker_member_id = cp.member_id AND b.blocked_member_id IN (cn.member_low_id, cn.member_high_id))
                              OR (b.blocked_member_id = cp.member_id AND b.blocker_member_id IN (cn.member_low_id, cn.member_high_id)))
                      ) THEN 1 ELSE 0 END AS bit) AS can_send
FROM chat.ConversationParticipant cp
JOIN chat.Conversation c ON c.conversation_id = cp.conversation_id
JOIN social.Connection cn ON cn.connection_id = c.connection_id;
GO

CREATE OR ALTER VIEW admin.vw_MemberReview
AS
SELECT m.member_id, m.community_id, m.status AS member_status, m.verified_at, m.suspended_at, m.deleted_at,
       p.display_name, p.headline, p.profile_status, p.visibility, p.completeness_score,
       v.verification_id, v.verification_type, v.status AS verification_status, v.reviewed_by, v.reviewed_at, v.reason_code
FROM iam.Member m
LEFT JOIN core.MemberProfile p ON p.member_id = m.member_id
LEFT JOIN core.MemberVerification v ON v.member_id = m.member_id;
GO
