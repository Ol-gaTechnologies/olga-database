SET XACT_ABORT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Member_community_id' AND parent_object_id = OBJECT_ID(N'[iam].[Member]'))
    ALTER TABLE [iam].[Member] WITH CHECK ADD CONSTRAINT [FK_Member_community_id] FOREIGN KEY ([community_id]) REFERENCES [core].[Community] ([community_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Member_community_id' AND is_not_trusted = 1)
    ALTER TABLE [iam].[Member] WITH CHECK CHECK CONSTRAINT [FK_Member_community_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberIdentity_member_id' AND parent_object_id = OBJECT_ID(N'[iam].[MemberIdentity]'))
    ALTER TABLE [iam].[MemberIdentity] WITH CHECK ADD CONSTRAINT [FK_MemberIdentity_member_id] FOREIGN KEY ([member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberIdentity_member_id' AND is_not_trusted = 1)
    ALTER TABLE [iam].[MemberIdentity] WITH CHECK CHECK CONSTRAINT [FK_MemberIdentity_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberRole_member_id' AND parent_object_id = OBJECT_ID(N'[iam].[MemberRole]'))
    ALTER TABLE [iam].[MemberRole] WITH CHECK ADD CONSTRAINT [FK_MemberRole_member_id] FOREIGN KEY ([member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberRole_member_id' AND is_not_trusted = 1)
    ALTER TABLE [iam].[MemberRole] WITH CHECK CHECK CONSTRAINT [FK_MemberRole_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberRole_role_code' AND parent_object_id = OBJECT_ID(N'[iam].[MemberRole]'))
    ALTER TABLE [iam].[MemberRole] WITH CHECK ADD CONSTRAINT [FK_MemberRole_role_code] FOREIGN KEY ([role_code]) REFERENCES [iam].[Role] ([role_code]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberRole_role_code' AND is_not_trusted = 1)
    ALTER TABLE [iam].[MemberRole] WITH CHECK CHECK CONSTRAINT [FK_MemberRole_role_code];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberRole_granted_by' AND parent_object_id = OBJECT_ID(N'[iam].[MemberRole]'))
    ALTER TABLE [iam].[MemberRole] WITH CHECK ADD CONSTRAINT [FK_MemberRole_granted_by] FOREIGN KEY ([granted_by]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberRole_granted_by' AND is_not_trusted = 1)
    ALTER TABLE [iam].[MemberRole] WITH CHECK CHECK CONSTRAINT [FK_MemberRole_granted_by];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberDevice_member_id' AND parent_object_id = OBJECT_ID(N'[iam].[MemberDevice]'))
    ALTER TABLE [iam].[MemberDevice] WITH CHECK ADD CONSTRAINT [FK_MemberDevice_member_id] FOREIGN KEY ([member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberDevice_member_id' AND is_not_trusted = 1)
    ALTER TABLE [iam].[MemberDevice] WITH CHECK CHECK CONSTRAINT [FK_MemberDevice_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Organization_community_id' AND parent_object_id = OBJECT_ID(N'[core].[Organization]'))
    ALTER TABLE [core].[Organization] WITH CHECK ADD CONSTRAINT [FK_Organization_community_id] FOREIGN KEY ([community_id]) REFERENCES [core].[Community] ([community_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Organization_community_id' AND is_not_trusted = 1)
    ALTER TABLE [core].[Organization] WITH CHECK CHECK CONSTRAINT [FK_Organization_community_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_OrganizationMember_organization_id' AND parent_object_id = OBJECT_ID(N'[core].[OrganizationMember]'))
    ALTER TABLE [core].[OrganizationMember] WITH CHECK ADD CONSTRAINT [FK_OrganizationMember_organization_id] FOREIGN KEY ([organization_id]) REFERENCES [core].[Organization] ([organization_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_OrganizationMember_organization_id' AND is_not_trusted = 1)
    ALTER TABLE [core].[OrganizationMember] WITH CHECK CHECK CONSTRAINT [FK_OrganizationMember_organization_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_OrganizationMember_member_id' AND parent_object_id = OBJECT_ID(N'[core].[OrganizationMember]'))
    ALTER TABLE [core].[OrganizationMember] WITH CHECK ADD CONSTRAINT [FK_OrganizationMember_member_id] FOREIGN KEY ([member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_OrganizationMember_member_id' AND is_not_trusted = 1)
    ALTER TABLE [core].[OrganizationMember] WITH CHECK CHECK CONSTRAINT [FK_OrganizationMember_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberProfile_member_id' AND parent_object_id = OBJECT_ID(N'[core].[MemberProfile]'))
    ALTER TABLE [core].[MemberProfile] WITH CHECK ADD CONSTRAINT [FK_MemberProfile_member_id] FOREIGN KEY ([member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberProfile_member_id' AND is_not_trusted = 1)
    ALTER TABLE [core].[MemberProfile] WITH CHECK CHECK CONSTRAINT [FK_MemberProfile_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Sector_parent_sector_code' AND parent_object_id = OBJECT_ID(N'[core].[Sector]'))
    ALTER TABLE [core].[Sector] WITH CHECK ADD CONSTRAINT [FK_Sector_parent_sector_code] FOREIGN KEY ([parent_sector_code]) REFERENCES [core].[Sector] ([sector_code]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Sector_parent_sector_code' AND is_not_trusted = 1)
    ALTER TABLE [core].[Sector] WITH CHECK CHECK CONSTRAINT [FK_Sector_parent_sector_code];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberSector_member_id' AND parent_object_id = OBJECT_ID(N'[core].[MemberSector]'))
    ALTER TABLE [core].[MemberSector] WITH CHECK ADD CONSTRAINT [FK_MemberSector_member_id] FOREIGN KEY ([member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberSector_member_id' AND is_not_trusted = 1)
    ALTER TABLE [core].[MemberSector] WITH CHECK CHECK CONSTRAINT [FK_MemberSector_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberSector_sector_code' AND parent_object_id = OBJECT_ID(N'[core].[MemberSector]'))
    ALTER TABLE [core].[MemberSector] WITH CHECK ADD CONSTRAINT [FK_MemberSector_sector_code] FOREIGN KEY ([sector_code]) REFERENCES [core].[Sector] ([sector_code]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberSector_sector_code' AND is_not_trusted = 1)
    ALTER TABLE [core].[MemberSector] WITH CHECK CHECK CONSTRAINT [FK_MemberSector_sector_code];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberGeography_member_id' AND parent_object_id = OBJECT_ID(N'[core].[MemberGeography]'))
    ALTER TABLE [core].[MemberGeography] WITH CHECK ADD CONSTRAINT [FK_MemberGeography_member_id] FOREIGN KEY ([member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberGeography_member_id' AND is_not_trusted = 1)
    ALTER TABLE [core].[MemberGeography] WITH CHECK CHECK CONSTRAINT [FK_MemberGeography_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ProfileFieldVisibility_member_id' AND parent_object_id = OBJECT_ID(N'[core].[ProfileFieldVisibility]'))
    ALTER TABLE [core].[ProfileFieldVisibility] WITH CHECK ADD CONSTRAINT [FK_ProfileFieldVisibility_member_id] FOREIGN KEY ([member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ProfileFieldVisibility_member_id' AND is_not_trusted = 1)
    ALTER TABLE [core].[ProfileFieldVisibility] WITH CHECK CHECK CONSTRAINT [FK_ProfileFieldVisibility_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberVerification_member_id' AND parent_object_id = OBJECT_ID(N'[core].[MemberVerification]'))
    ALTER TABLE [core].[MemberVerification] WITH CHECK ADD CONSTRAINT [FK_MemberVerification_member_id] FOREIGN KEY ([member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberVerification_member_id' AND is_not_trusted = 1)
    ALTER TABLE [core].[MemberVerification] WITH CHECK CHECK CONSTRAINT [FK_MemberVerification_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberVerification_evidence_attachment_id' AND parent_object_id = OBJECT_ID(N'[core].[MemberVerification]'))
    ALTER TABLE [core].[MemberVerification] WITH CHECK ADD CONSTRAINT [FK_MemberVerification_evidence_attachment_id] FOREIGN KEY ([evidence_attachment_id]) REFERENCES [chat].[Attachment] ([attachment_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberVerification_evidence_attachment_id' AND is_not_trusted = 1)
    ALTER TABLE [core].[MemberVerification] WITH CHECK CHECK CONSTRAINT [FK_MemberVerification_evidence_attachment_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberVerification_reviewed_by' AND parent_object_id = OBJECT_ID(N'[core].[MemberVerification]'))
    ALTER TABLE [core].[MemberVerification] WITH CHECK ADD CONSTRAINT [FK_MemberVerification_reviewed_by] FOREIGN KEY ([reviewed_by]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberVerification_reviewed_by' AND is_not_trusted = 1)
    ALTER TABLE [core].[MemberVerification] WITH CHECK CHECK CONSTRAINT [FK_MemberVerification_reviewed_by];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberConsent_member_id' AND parent_object_id = OBJECT_ID(N'[consent].[MemberConsent]'))
    ALTER TABLE [consent].[MemberConsent] WITH CHECK ADD CONSTRAINT [FK_MemberConsent_member_id] FOREIGN KEY ([member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberConsent_member_id' AND is_not_trusted = 1)
    ALTER TABLE [consent].[MemberConsent] WITH CHECK CHECK CONSTRAINT [FK_MemberConsent_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberConsent_policy_id' AND parent_object_id = OBJECT_ID(N'[consent].[MemberConsent]'))
    ALTER TABLE [consent].[MemberConsent] WITH CHECK ADD CONSTRAINT [FK_MemberConsent_policy_id] FOREIGN KEY ([policy_id]) REFERENCES [consent].[ConsentPolicy] ([policy_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberConsent_policy_id' AND is_not_trusted = 1)
    ALTER TABLE [consent].[MemberConsent] WITH CHECK CHECK CONSTRAINT [FK_MemberConsent_policy_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_PrivacyRequest_member_id' AND parent_object_id = OBJECT_ID(N'[consent].[PrivacyRequest]'))
    ALTER TABLE [consent].[PrivacyRequest] WITH CHECK ADD CONSTRAINT [FK_PrivacyRequest_member_id] FOREIGN KEY ([member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_PrivacyRequest_member_id' AND is_not_trusted = 1)
    ALTER TABLE [consent].[PrivacyRequest] WITH CHECK CHECK CONSTRAINT [FK_PrivacyRequest_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_PrivacyRequest_result_attachment_id' AND parent_object_id = OBJECT_ID(N'[consent].[PrivacyRequest]'))
    ALTER TABLE [consent].[PrivacyRequest] WITH CHECK ADD CONSTRAINT [FK_PrivacyRequest_result_attachment_id] FOREIGN KEY ([result_attachment_id]) REFERENCES [chat].[Attachment] ([attachment_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_PrivacyRequest_result_attachment_id' AND is_not_trusted = 1)
    ALTER TABLE [consent].[PrivacyRequest] WITH CHECK CHECK CONSTRAINT [FK_PrivacyRequest_result_attachment_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Event_community_id' AND parent_object_id = OBJECT_ID(N'[event].[Event]'))
    ALTER TABLE [event].[Event] WITH CHECK ADD CONSTRAINT [FK_Event_community_id] FOREIGN KEY ([community_id]) REFERENCES [core].[Community] ([community_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Event_community_id' AND is_not_trusted = 1)
    ALTER TABLE [event].[Event] WITH CHECK CHECK CONSTRAINT [FK_Event_community_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Event_venue_id' AND parent_object_id = OBJECT_ID(N'[event].[Event]'))
    ALTER TABLE [event].[Event] WITH CHECK ADD CONSTRAINT [FK_Event_venue_id] FOREIGN KEY ([venue_id]) REFERENCES [event].[Venue] ([venue_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Event_venue_id' AND is_not_trusted = 1)
    ALTER TABLE [event].[Event] WITH CHECK CHECK CONSTRAINT [FK_Event_venue_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_EventMatchingPolicy_event_id' AND parent_object_id = OBJECT_ID(N'[event].[EventMatchingPolicy]'))
    ALTER TABLE [event].[EventMatchingPolicy] WITH CHECK ADD CONSTRAINT [FK_EventMatchingPolicy_event_id] FOREIGN KEY ([event_id]) REFERENCES [event].[Event] ([event_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_EventMatchingPolicy_event_id' AND is_not_trusted = 1)
    ALTER TABLE [event].[EventMatchingPolicy] WITH CHECK CHECK CONSTRAINT [FK_EventMatchingPolicy_event_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_EventRegistration_event_id' AND parent_object_id = OBJECT_ID(N'[event].[EventRegistration]'))
    ALTER TABLE [event].[EventRegistration] WITH CHECK ADD CONSTRAINT [FK_EventRegistration_event_id] FOREIGN KEY ([event_id]) REFERENCES [event].[Event] ([event_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_EventRegistration_event_id' AND is_not_trusted = 1)
    ALTER TABLE [event].[EventRegistration] WITH CHECK CHECK CONSTRAINT [FK_EventRegistration_event_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_EventRegistration_member_id' AND parent_object_id = OBJECT_ID(N'[event].[EventRegistration]'))
    ALTER TABLE [event].[EventRegistration] WITH CHECK ADD CONSTRAINT [FK_EventRegistration_member_id] FOREIGN KEY ([member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_EventRegistration_member_id' AND is_not_trusted = 1)
    ALTER TABLE [event].[EventRegistration] WITH CHECK CHECK CONSTRAINT [FK_EventRegistration_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_LiveModeSession_event_id' AND parent_object_id = OBJECT_ID(N'[event].[LiveModeSession]'))
    ALTER TABLE [event].[LiveModeSession] WITH CHECK ADD CONSTRAINT [FK_LiveModeSession_event_id] FOREIGN KEY ([event_id]) REFERENCES [event].[Event] ([event_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_LiveModeSession_event_id' AND is_not_trusted = 1)
    ALTER TABLE [event].[LiveModeSession] WITH CHECK CHECK CONSTRAINT [FK_LiveModeSession_event_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_LiveModeSession_member_id' AND parent_object_id = OBJECT_ID(N'[event].[LiveModeSession]'))
    ALTER TABLE [event].[LiveModeSession] WITH CHECK ADD CONSTRAINT [FK_LiveModeSession_member_id] FOREIGN KEY ([member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_LiveModeSession_member_id' AND is_not_trusted = 1)
    ALTER TABLE [event].[LiveModeSession] WITH CHECK CHECK CONSTRAINT [FK_LiveModeSession_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_LiveModeSession_consent_record_id' AND parent_object_id = OBJECT_ID(N'[event].[LiveModeSession]'))
    ALTER TABLE [event].[LiveModeSession] WITH CHECK ADD CONSTRAINT [FK_LiveModeSession_consent_record_id] FOREIGN KEY ([consent_record_id]) REFERENCES [consent].[MemberConsent] ([member_consent_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_LiveModeSession_consent_record_id' AND is_not_trusted = 1)
    ALTER TABLE [event].[LiveModeSession] WITH CHECK CHECK CONSTRAINT [FK_LiveModeSession_consent_record_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_EventPresence_live_session_id' AND parent_object_id = OBJECT_ID(N'[event].[EventPresence]'))
    ALTER TABLE [event].[EventPresence] WITH CHECK ADD CONSTRAINT [FK_EventPresence_live_session_id] FOREIGN KEY ([live_session_id]) REFERENCES [event].[LiveModeSession] ([live_session_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_EventPresence_live_session_id' AND is_not_trusted = 1)
    ALTER TABLE [event].[EventPresence] WITH CHECK CHECK CONSTRAINT [FK_EventPresence_live_session_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ConnectionRequest_sender_member_id' AND parent_object_id = OBJECT_ID(N'[social].[ConnectionRequest]'))
    ALTER TABLE [social].[ConnectionRequest] WITH CHECK ADD CONSTRAINT [FK_ConnectionRequest_sender_member_id] FOREIGN KEY ([sender_member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ConnectionRequest_sender_member_id' AND is_not_trusted = 1)
    ALTER TABLE [social].[ConnectionRequest] WITH CHECK CHECK CONSTRAINT [FK_ConnectionRequest_sender_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ConnectionRequest_recipient_member_id' AND parent_object_id = OBJECT_ID(N'[social].[ConnectionRequest]'))
    ALTER TABLE [social].[ConnectionRequest] WITH CHECK ADD CONSTRAINT [FK_ConnectionRequest_recipient_member_id] FOREIGN KEY ([recipient_member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ConnectionRequest_recipient_member_id' AND is_not_trusted = 1)
    ALTER TABLE [social].[ConnectionRequest] WITH CHECK CHECK CONSTRAINT [FK_ConnectionRequest_recipient_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ConnectionRequest_match_result_id' AND parent_object_id = OBJECT_ID(N'[social].[ConnectionRequest]'))
    ALTER TABLE [social].[ConnectionRequest] WITH CHECK ADD CONSTRAINT [FK_ConnectionRequest_match_result_id] FOREIGN KEY ([match_result_id]) REFERENCES [nlp].[NlpMatchResult] ([match_result_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ConnectionRequest_match_result_id' AND is_not_trusted = 1)
    ALTER TABLE [social].[ConnectionRequest] WITH CHECK CHECK CONSTRAINT [FK_ConnectionRequest_match_result_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Connection_member_low_id' AND parent_object_id = OBJECT_ID(N'[social].[Connection]'))
    ALTER TABLE [social].[Connection] WITH CHECK ADD CONSTRAINT [FK_Connection_member_low_id] FOREIGN KEY ([member_low_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Connection_member_low_id' AND is_not_trusted = 1)
    ALTER TABLE [social].[Connection] WITH CHECK CHECK CONSTRAINT [FK_Connection_member_low_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Connection_member_high_id' AND parent_object_id = OBJECT_ID(N'[social].[Connection]'))
    ALTER TABLE [social].[Connection] WITH CHECK ADD CONSTRAINT [FK_Connection_member_high_id] FOREIGN KEY ([member_high_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Connection_member_high_id' AND is_not_trusted = 1)
    ALTER TABLE [social].[Connection] WITH CHECK CHECK CONSTRAINT [FK_Connection_member_high_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Connection_accepted_request_id' AND parent_object_id = OBJECT_ID(N'[social].[Connection]'))
    ALTER TABLE [social].[Connection] WITH CHECK ADD CONSTRAINT [FK_Connection_accepted_request_id] FOREIGN KEY ([accepted_request_id]) REFERENCES [social].[ConnectionRequest] ([connection_request_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Connection_accepted_request_id' AND is_not_trusted = 1)
    ALTER TABLE [social].[Connection] WITH CHECK CHECK CONSTRAINT [FK_Connection_accepted_request_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberBlock_blocker_member_id' AND parent_object_id = OBJECT_ID(N'[social].[MemberBlock]'))
    ALTER TABLE [social].[MemberBlock] WITH CHECK ADD CONSTRAINT [FK_MemberBlock_blocker_member_id] FOREIGN KEY ([blocker_member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberBlock_blocker_member_id' AND is_not_trusted = 1)
    ALTER TABLE [social].[MemberBlock] WITH CHECK CHECK CONSTRAINT [FK_MemberBlock_blocker_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberBlock_blocked_member_id' AND parent_object_id = OBJECT_ID(N'[social].[MemberBlock]'))
    ALTER TABLE [social].[MemberBlock] WITH CHECK ADD CONSTRAINT [FK_MemberBlock_blocked_member_id] FOREIGN KEY ([blocked_member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberBlock_blocked_member_id' AND is_not_trusted = 1)
    ALTER TABLE [social].[MemberBlock] WITH CHECK CHECK CONSTRAINT [FK_MemberBlock_blocked_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberReport_reporter_member_id' AND parent_object_id = OBJECT_ID(N'[social].[MemberReport]'))
    ALTER TABLE [social].[MemberReport] WITH CHECK ADD CONSTRAINT [FK_MemberReport_reporter_member_id] FOREIGN KEY ([reporter_member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberReport_reporter_member_id' AND is_not_trusted = 1)
    ALTER TABLE [social].[MemberReport] WITH CHECK CHECK CONSTRAINT [FK_MemberReport_reporter_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberReport_reported_member_id' AND parent_object_id = OBJECT_ID(N'[social].[MemberReport]'))
    ALTER TABLE [social].[MemberReport] WITH CHECK ADD CONSTRAINT [FK_MemberReport_reported_member_id] FOREIGN KEY ([reported_member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberReport_reported_member_id' AND is_not_trusted = 1)
    ALTER TABLE [social].[MemberReport] WITH CHECK CHECK CONSTRAINT [FK_MemberReport_reported_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Conversation_connection_id' AND parent_object_id = OBJECT_ID(N'[chat].[Conversation]'))
    ALTER TABLE [chat].[Conversation] WITH CHECK ADD CONSTRAINT [FK_Conversation_connection_id] FOREIGN KEY ([connection_id]) REFERENCES [social].[Connection] ([connection_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Conversation_connection_id' AND is_not_trusted = 1)
    ALTER TABLE [chat].[Conversation] WITH CHECK CHECK CONSTRAINT [FK_Conversation_connection_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ConversationParticipant_conversation_id' AND parent_object_id = OBJECT_ID(N'[chat].[ConversationParticipant]'))
    ALTER TABLE [chat].[ConversationParticipant] WITH CHECK ADD CONSTRAINT [FK_ConversationParticipant_conversation_id] FOREIGN KEY ([conversation_id]) REFERENCES [chat].[Conversation] ([conversation_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ConversationParticipant_conversation_id' AND is_not_trusted = 1)
    ALTER TABLE [chat].[ConversationParticipant] WITH CHECK CHECK CONSTRAINT [FK_ConversationParticipant_conversation_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ConversationParticipant_member_id' AND parent_object_id = OBJECT_ID(N'[chat].[ConversationParticipant]'))
    ALTER TABLE [chat].[ConversationParticipant] WITH CHECK ADD CONSTRAINT [FK_ConversationParticipant_member_id] FOREIGN KEY ([member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ConversationParticipant_member_id' AND is_not_trusted = 1)
    ALTER TABLE [chat].[ConversationParticipant] WITH CHECK CHECK CONSTRAINT [FK_ConversationParticipant_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ConversationParticipant_last_read_message_id' AND parent_object_id = OBJECT_ID(N'[chat].[ConversationParticipant]'))
    ALTER TABLE [chat].[ConversationParticipant] WITH CHECK ADD CONSTRAINT [FK_ConversationParticipant_last_read_message_id] FOREIGN KEY ([last_read_message_id]) REFERENCES [chat].[Message] ([message_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ConversationParticipant_last_read_message_id' AND is_not_trusted = 1)
    ALTER TABLE [chat].[ConversationParticipant] WITH CHECK CHECK CONSTRAINT [FK_ConversationParticipant_last_read_message_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Message_conversation_id' AND parent_object_id = OBJECT_ID(N'[chat].[Message]'))
    ALTER TABLE [chat].[Message] WITH CHECK ADD CONSTRAINT [FK_Message_conversation_id] FOREIGN KEY ([conversation_id]) REFERENCES [chat].[Conversation] ([conversation_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Message_conversation_id' AND is_not_trusted = 1)
    ALTER TABLE [chat].[Message] WITH CHECK CHECK CONSTRAINT [FK_Message_conversation_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Message_sender_member_id' AND parent_object_id = OBJECT_ID(N'[chat].[Message]'))
    ALTER TABLE [chat].[Message] WITH CHECK ADD CONSTRAINT [FK_Message_sender_member_id] FOREIGN KEY ([sender_member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Message_sender_member_id' AND is_not_trusted = 1)
    ALTER TABLE [chat].[Message] WITH CHECK CHECK CONSTRAINT [FK_Message_sender_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Attachment_message_id' AND parent_object_id = OBJECT_ID(N'[chat].[Attachment]'))
    ALTER TABLE [chat].[Attachment] WITH CHECK ADD CONSTRAINT [FK_Attachment_message_id] FOREIGN KEY ([message_id]) REFERENCES [chat].[Message] ([message_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Attachment_message_id' AND is_not_trusted = 1)
    ALTER TABLE [chat].[Attachment] WITH CHECK CHECK CONSTRAINT [FK_Attachment_message_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Attachment_owner_member_id' AND parent_object_id = OBJECT_ID(N'[chat].[Attachment]'))
    ALTER TABLE [chat].[Attachment] WITH CHECK ADD CONSTRAINT [FK_Attachment_owner_member_id] FOREIGN KEY ([owner_member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Attachment_owner_member_id' AND is_not_trusted = 1)
    ALTER TABLE [chat].[Attachment] WITH CHECK CHECK CONSTRAINT [FK_Attachment_owner_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MessageReceipt_message_id' AND parent_object_id = OBJECT_ID(N'[chat].[MessageReceipt]'))
    ALTER TABLE [chat].[MessageReceipt] WITH CHECK ADD CONSTRAINT [FK_MessageReceipt_message_id] FOREIGN KEY ([message_id]) REFERENCES [chat].[Message] ([message_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MessageReceipt_message_id' AND is_not_trusted = 1)
    ALTER TABLE [chat].[MessageReceipt] WITH CHECK CHECK CONSTRAINT [FK_MessageReceipt_message_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MessageReceipt_member_id' AND parent_object_id = OBJECT_ID(N'[chat].[MessageReceipt]'))
    ALTER TABLE [chat].[MessageReceipt] WITH CHECK ADD CONSTRAINT [FK_MessageReceipt_member_id] FOREIGN KEY ([member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MessageReceipt_member_id' AND is_not_trusted = 1)
    ALTER TABLE [chat].[MessageReceipt] WITH CHECK CHECK CONSTRAINT [FK_MessageReceipt_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NotificationPolicy_community_id' AND parent_object_id = OBJECT_ID(N'[notification].[NotificationPolicy]'))
    ALTER TABLE [notification].[NotificationPolicy] WITH CHECK ADD CONSTRAINT [FK_NotificationPolicy_community_id] FOREIGN KEY ([community_id]) REFERENCES [core].[Community] ([community_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NotificationPolicy_community_id' AND is_not_trusted = 1)
    ALTER TABLE [notification].[NotificationPolicy] WITH CHECK CHECK CONSTRAINT [FK_NotificationPolicy_community_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NotificationPreference_member_id' AND parent_object_id = OBJECT_ID(N'[notification].[NotificationPreference]'))
    ALTER TABLE [notification].[NotificationPreference] WITH CHECK ADD CONSTRAINT [FK_NotificationPreference_member_id] FOREIGN KEY ([member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NotificationPreference_member_id' AND is_not_trusted = 1)
    ALTER TABLE [notification].[NotificationPreference] WITH CHECK CHECK CONSTRAINT [FK_NotificationPreference_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_PushToken_device_id' AND parent_object_id = OBJECT_ID(N'[notification].[PushToken]'))
    ALTER TABLE [notification].[PushToken] WITH CHECK ADD CONSTRAINT [FK_PushToken_device_id] FOREIGN KEY ([device_id]) REFERENCES [iam].[MemberDevice] ([device_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_PushToken_device_id' AND is_not_trusted = 1)
    ALTER TABLE [notification].[PushToken] WITH CHECK CHECK CONSTRAINT [FK_PushToken_device_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Notification_member_id' AND parent_object_id = OBJECT_ID(N'[notification].[Notification]'))
    ALTER TABLE [notification].[Notification] WITH CHECK ADD CONSTRAINT [FK_Notification_member_id] FOREIGN KEY ([member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Notification_member_id' AND is_not_trusted = 1)
    ALTER TABLE [notification].[Notification] WITH CHECK CHECK CONSTRAINT [FK_Notification_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Notification_notification_policy_id' AND parent_object_id = OBJECT_ID(N'[notification].[Notification]'))
    ALTER TABLE [notification].[Notification] WITH CHECK ADD CONSTRAINT [FK_Notification_notification_policy_id] FOREIGN KEY ([notification_policy_id]) REFERENCES [notification].[NotificationPolicy] ([notification_policy_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Notification_notification_policy_id' AND is_not_trusted = 1)
    ALTER TABLE [notification].[Notification] WITH CHECK CHECK CONSTRAINT [FK_Notification_notification_policy_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Notification_event_matching_policy_id' AND parent_object_id = OBJECT_ID(N'[notification].[Notification]'))
    ALTER TABLE [notification].[Notification] WITH CHECK ADD CONSTRAINT [FK_Notification_event_matching_policy_id] FOREIGN KEY ([event_matching_policy_id]) REFERENCES [event].[EventMatchingPolicy] ([event_matching_policy_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Notification_event_matching_policy_id' AND is_not_trusted = 1)
    ALTER TABLE [notification].[Notification] WITH CHECK CHECK CONSTRAINT [FK_Notification_event_matching_policy_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NotificationDeliveryAttempt_notification_id' AND parent_object_id = OBJECT_ID(N'[notification].[NotificationDeliveryAttempt]'))
    ALTER TABLE [notification].[NotificationDeliveryAttempt] WITH CHECK ADD CONSTRAINT [FK_NotificationDeliveryAttempt_notification_id] FOREIGN KEY ([notification_id]) REFERENCES [notification].[Notification] ([notification_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NotificationDeliveryAttempt_notification_id' AND is_not_trusted = 1)
    ALTER TABLE [notification].[NotificationDeliveryAttempt] WITH CHECK CHECK CONSTRAINT [FK_NotificationDeliveryAttempt_notification_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NotificationDeliveryAttempt_push_token_id' AND parent_object_id = OBJECT_ID(N'[notification].[NotificationDeliveryAttempt]'))
    ALTER TABLE [notification].[NotificationDeliveryAttempt] WITH CHECK ADD CONSTRAINT [FK_NotificationDeliveryAttempt_push_token_id] FOREIGN KEY ([push_token_id]) REFERENCES [notification].[PushToken] ([push_token_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NotificationDeliveryAttempt_push_token_id' AND is_not_trusted = 1)
    ALTER TABLE [notification].[NotificationDeliveryAttempt] WITH CHECK CHECK CONSTRAINT [FK_NotificationDeliveryAttempt_push_token_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpIntent_member_id' AND parent_object_id = OBJECT_ID(N'[nlp].[NlpIntent]'))
    ALTER TABLE [nlp].[NlpIntent] WITH CHECK ADD CONSTRAINT [FK_NlpIntent_member_id] FOREIGN KEY ([member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpIntent_member_id' AND is_not_trusted = 1)
    ALTER TABLE [nlp].[NlpIntent] WITH CHECK CHECK CONSTRAINT [FK_NlpIntent_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpEmbedding_intent_id' AND parent_object_id = OBJECT_ID(N'[nlp].[NlpEmbedding]'))
    ALTER TABLE [nlp].[NlpEmbedding] WITH CHECK ADD CONSTRAINT [FK_NlpEmbedding_intent_id] FOREIGN KEY ([intent_id]) REFERENCES [nlp].[NlpIntent] ([intent_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpEmbedding_intent_id' AND is_not_trusted = 1)
    ALTER TABLE [nlp].[NlpEmbedding] WITH CHECK CHECK CONSTRAINT [FK_NlpEmbedding_intent_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpEmbedding_model_version' AND parent_object_id = OBJECT_ID(N'[nlp].[NlpEmbedding]'))
    ALTER TABLE [nlp].[NlpEmbedding] WITH CHECK ADD CONSTRAINT [FK_NlpEmbedding_model_version] FOREIGN KEY ([model_version]) REFERENCES [nlp].[NlpModelVersion] ([model_version]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpEmbedding_model_version' AND is_not_trusted = 1)
    ALTER TABLE [nlp].[NlpEmbedding] WITH CHECK CHECK CONSTRAINT [FK_NlpEmbedding_model_version];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpProcessingJob_intent_id' AND parent_object_id = OBJECT_ID(N'[nlp].[NlpProcessingJob]'))
    ALTER TABLE [nlp].[NlpProcessingJob] WITH CHECK ADD CONSTRAINT [FK_NlpProcessingJob_intent_id] FOREIGN KEY ([intent_id]) REFERENCES [nlp].[NlpIntent] ([intent_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpProcessingJob_intent_id' AND is_not_trusted = 1)
    ALTER TABLE [nlp].[NlpProcessingJob] WITH CHECK CHECK CONSTRAINT [FK_NlpProcessingJob_intent_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MatchRequest_requester_id' AND parent_object_id = OBJECT_ID(N'[nlp].[MatchRequest]'))
    ALTER TABLE [nlp].[MatchRequest] WITH CHECK ADD CONSTRAINT [FK_MatchRequest_requester_id] FOREIGN KEY ([requester_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MatchRequest_requester_id' AND is_not_trusted = 1)
    ALTER TABLE [nlp].[MatchRequest] WITH CHECK CHECK CONSTRAINT [FK_MatchRequest_requester_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MatchRequest_intent_id' AND parent_object_id = OBJECT_ID(N'[nlp].[MatchRequest]'))
    ALTER TABLE [nlp].[MatchRequest] WITH CHECK ADD CONSTRAINT [FK_MatchRequest_intent_id] FOREIGN KEY ([intent_id]) REFERENCES [nlp].[NlpIntent] ([intent_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MatchRequest_intent_id' AND is_not_trusted = 1)
    ALTER TABLE [nlp].[MatchRequest] WITH CHECK CHECK CONSTRAINT [FK_MatchRequest_intent_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MatchRequest_model_version' AND parent_object_id = OBJECT_ID(N'[nlp].[MatchRequest]'))
    ALTER TABLE [nlp].[MatchRequest] WITH CHECK ADD CONSTRAINT [FK_MatchRequest_model_version] FOREIGN KEY ([model_version]) REFERENCES [nlp].[NlpModelVersion] ([model_version]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MatchRequest_model_version' AND is_not_trusted = 1)
    ALTER TABLE [nlp].[MatchRequest] WITH CHECK CHECK CONSTRAINT [FK_MatchRequest_model_version];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MatchRequest_ranking_version' AND parent_object_id = OBJECT_ID(N'[nlp].[MatchRequest]'))
    ALTER TABLE [nlp].[MatchRequest] WITH CHECK ADD CONSTRAINT [FK_MatchRequest_ranking_version] FOREIGN KEY ([ranking_version]) REFERENCES [nlp].[NlpRankingConfig] ([ranking_version]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MatchRequest_ranking_version' AND is_not_trusted = 1)
    ALTER TABLE [nlp].[MatchRequest] WITH CHECK CHECK CONSTRAINT [FK_MatchRequest_ranking_version];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpMatchResult_request_id' AND parent_object_id = OBJECT_ID(N'[nlp].[NlpMatchResult]'))
    ALTER TABLE [nlp].[NlpMatchResult] WITH CHECK ADD CONSTRAINT [FK_NlpMatchResult_request_id] FOREIGN KEY ([request_id]) REFERENCES [nlp].[MatchRequest] ([request_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpMatchResult_request_id' AND is_not_trusted = 1)
    ALTER TABLE [nlp].[NlpMatchResult] WITH CHECK CHECK CONSTRAINT [FK_NlpMatchResult_request_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpMatchResult_requester_id' AND parent_object_id = OBJECT_ID(N'[nlp].[NlpMatchResult]'))
    ALTER TABLE [nlp].[NlpMatchResult] WITH CHECK ADD CONSTRAINT [FK_NlpMatchResult_requester_id] FOREIGN KEY ([requester_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpMatchResult_requester_id' AND is_not_trusted = 1)
    ALTER TABLE [nlp].[NlpMatchResult] WITH CHECK CHECK CONSTRAINT [FK_NlpMatchResult_requester_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpMatchResult_candidate_id' AND parent_object_id = OBJECT_ID(N'[nlp].[NlpMatchResult]'))
    ALTER TABLE [nlp].[NlpMatchResult] WITH CHECK ADD CONSTRAINT [FK_NlpMatchResult_candidate_id] FOREIGN KEY ([candidate_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpMatchResult_candidate_id' AND is_not_trusted = 1)
    ALTER TABLE [nlp].[NlpMatchResult] WITH CHECK CHECK CONSTRAINT [FK_NlpMatchResult_candidate_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpMatchResult_model_version' AND parent_object_id = OBJECT_ID(N'[nlp].[NlpMatchResult]'))
    ALTER TABLE [nlp].[NlpMatchResult] WITH CHECK ADD CONSTRAINT [FK_NlpMatchResult_model_version] FOREIGN KEY ([model_version]) REFERENCES [nlp].[NlpModelVersion] ([model_version]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpMatchResult_model_version' AND is_not_trusted = 1)
    ALTER TABLE [nlp].[NlpMatchResult] WITH CHECK CHECK CONSTRAINT [FK_NlpMatchResult_model_version];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpMatchResult_ranking_version' AND parent_object_id = OBJECT_ID(N'[nlp].[NlpMatchResult]'))
    ALTER TABLE [nlp].[NlpMatchResult] WITH CHECK ADD CONSTRAINT [FK_NlpMatchResult_ranking_version] FOREIGN KEY ([ranking_version]) REFERENCES [nlp].[NlpRankingConfig] ([ranking_version]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpMatchResult_ranking_version' AND is_not_trusted = 1)
    ALTER TABLE [nlp].[NlpMatchResult] WITH CHECK CHECK CONSTRAINT [FK_NlpMatchResult_ranking_version];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpFeedback_supersedes_feedback_id' AND parent_object_id = OBJECT_ID(N'[nlp].[NlpFeedback]'))
    ALTER TABLE [nlp].[NlpFeedback] WITH CHECK ADD CONSTRAINT [FK_NlpFeedback_supersedes_feedback_id] FOREIGN KEY ([supersedes_feedback_id]) REFERENCES [nlp].[NlpFeedback] ([feedback_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpFeedback_supersedes_feedback_id' AND is_not_trusted = 1)
    ALTER TABLE [nlp].[NlpFeedback] WITH CHECK CHECK CONSTRAINT [FK_NlpFeedback_supersedes_feedback_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpFeedback_match_result_id' AND parent_object_id = OBJECT_ID(N'[nlp].[NlpFeedback]'))
    ALTER TABLE [nlp].[NlpFeedback] WITH CHECK ADD CONSTRAINT [FK_NlpFeedback_match_result_id] FOREIGN KEY ([match_result_id]) REFERENCES [nlp].[NlpMatchResult] ([match_result_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpFeedback_match_result_id' AND is_not_trusted = 1)
    ALTER TABLE [nlp].[NlpFeedback] WITH CHECK CHECK CONSTRAINT [FK_NlpFeedback_match_result_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpFeedback_request_id' AND parent_object_id = OBJECT_ID(N'[nlp].[NlpFeedback]'))
    ALTER TABLE [nlp].[NlpFeedback] WITH CHECK ADD CONSTRAINT [FK_NlpFeedback_request_id] FOREIGN KEY ([request_id]) REFERENCES [nlp].[MatchRequest] ([request_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpFeedback_request_id' AND is_not_trusted = 1)
    ALTER TABLE [nlp].[NlpFeedback] WITH CHECK CHECK CONSTRAINT [FK_NlpFeedback_request_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpFeedback_requester_id' AND parent_object_id = OBJECT_ID(N'[nlp].[NlpFeedback]'))
    ALTER TABLE [nlp].[NlpFeedback] WITH CHECK ADD CONSTRAINT [FK_NlpFeedback_requester_id] FOREIGN KEY ([requester_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpFeedback_requester_id' AND is_not_trusted = 1)
    ALTER TABLE [nlp].[NlpFeedback] WITH CHECK CHECK CONSTRAINT [FK_NlpFeedback_requester_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpFeedback_candidate_id' AND parent_object_id = OBJECT_ID(N'[nlp].[NlpFeedback]'))
    ALTER TABLE [nlp].[NlpFeedback] WITH CHECK ADD CONSTRAINT [FK_NlpFeedback_candidate_id] FOREIGN KEY ([candidate_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_NlpFeedback_candidate_id' AND is_not_trusted = 1)
    ALTER TABLE [nlp].[NlpFeedback] WITH CHECK CHECK CONSTRAINT [FK_NlpFeedback_candidate_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MatchSuppression_member_id' AND parent_object_id = OBJECT_ID(N'[nlp].[MatchSuppression]'))
    ALTER TABLE [nlp].[MatchSuppression] WITH CHECK ADD CONSTRAINT [FK_MatchSuppression_member_id] FOREIGN KEY ([member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MatchSuppression_member_id' AND is_not_trusted = 1)
    ALTER TABLE [nlp].[MatchSuppression] WITH CHECK CHECK CONSTRAINT [FK_MatchSuppression_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MatchSuppression_intent_id' AND parent_object_id = OBJECT_ID(N'[nlp].[MatchSuppression]'))
    ALTER TABLE [nlp].[MatchSuppression] WITH CHECK ADD CONSTRAINT [FK_MatchSuppression_intent_id] FOREIGN KEY ([intent_id]) REFERENCES [nlp].[NlpIntent] ([intent_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MatchSuppression_intent_id' AND is_not_trusted = 1)
    ALTER TABLE [nlp].[MatchSuppression] WITH CHECK CHECK CONSTRAINT [FK_MatchSuppression_intent_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MatchSuppression_created_by' AND parent_object_id = OBJECT_ID(N'[nlp].[MatchSuppression]'))
    ALTER TABLE [nlp].[MatchSuppression] WITH CHECK ADD CONSTRAINT [FK_MatchSuppression_created_by] FOREIGN KEY ([created_by]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MatchSuppression_created_by' AND is_not_trusted = 1)
    ALTER TABLE [nlp].[MatchSuppression] WITH CHECK CHECK CONSTRAINT [FK_MatchSuppression_created_by];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_EvaluationDataset_approved_by' AND parent_object_id = OBJECT_ID(N'[nlp].[EvaluationDataset]'))
    ALTER TABLE [nlp].[EvaluationDataset] WITH CHECK ADD CONSTRAINT [FK_EvaluationDataset_approved_by] FOREIGN KEY ([approved_by]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_EvaluationDataset_approved_by' AND is_not_trusted = 1)
    ALTER TABLE [nlp].[EvaluationDataset] WITH CHECK CHECK CONSTRAINT [FK_EvaluationDataset_approved_by];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_EvaluationPair_dataset_id' AND parent_object_id = OBJECT_ID(N'[nlp].[EvaluationPair]'))
    ALTER TABLE [nlp].[EvaluationPair] WITH CHECK ADD CONSTRAINT [FK_EvaluationPair_dataset_id] FOREIGN KEY ([dataset_id]) REFERENCES [nlp].[EvaluationDataset] ([dataset_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_EvaluationPair_dataset_id' AND is_not_trusted = 1)
    ALTER TABLE [nlp].[EvaluationPair] WITH CHECK CHECK CONSTRAINT [FK_EvaluationPair_dataset_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_EvaluationRun_dataset_id' AND parent_object_id = OBJECT_ID(N'[nlp].[EvaluationRun]'))
    ALTER TABLE [nlp].[EvaluationRun] WITH CHECK ADD CONSTRAINT [FK_EvaluationRun_dataset_id] FOREIGN KEY ([dataset_id]) REFERENCES [nlp].[EvaluationDataset] ([dataset_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_EvaluationRun_dataset_id' AND is_not_trusted = 1)
    ALTER TABLE [nlp].[EvaluationRun] WITH CHECK CHECK CONSTRAINT [FK_EvaluationRun_dataset_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_EvaluationRun_model_version' AND parent_object_id = OBJECT_ID(N'[nlp].[EvaluationRun]'))
    ALTER TABLE [nlp].[EvaluationRun] WITH CHECK ADD CONSTRAINT [FK_EvaluationRun_model_version] FOREIGN KEY ([model_version]) REFERENCES [nlp].[NlpModelVersion] ([model_version]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_EvaluationRun_model_version' AND is_not_trusted = 1)
    ALTER TABLE [nlp].[EvaluationRun] WITH CHECK CHECK CONSTRAINT [FK_EvaluationRun_model_version];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_EvaluationRun_ranking_version' AND parent_object_id = OBJECT_ID(N'[nlp].[EvaluationRun]'))
    ALTER TABLE [nlp].[EvaluationRun] WITH CHECK ADD CONSTRAINT [FK_EvaluationRun_ranking_version] FOREIGN KEY ([ranking_version]) REFERENCES [nlp].[NlpRankingConfig] ([ranking_version]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_EvaluationRun_ranking_version' AND is_not_trusted = 1)
    ALTER TABLE [nlp].[EvaluationRun] WITH CHECK CHECK CONSTRAINT [FK_EvaluationRun_ranking_version];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ModerationCase_subject_member_id' AND parent_object_id = OBJECT_ID(N'[moderation].[ModerationCase]'))
    ALTER TABLE [moderation].[ModerationCase] WITH CHECK ADD CONSTRAINT [FK_ModerationCase_subject_member_id] FOREIGN KEY ([subject_member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ModerationCase_subject_member_id' AND is_not_trusted = 1)
    ALTER TABLE [moderation].[ModerationCase] WITH CHECK CHECK CONSTRAINT [FK_ModerationCase_subject_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ModerationCase_assigned_to' AND parent_object_id = OBJECT_ID(N'[moderation].[ModerationCase]'))
    ALTER TABLE [moderation].[ModerationCase] WITH CHECK ADD CONSTRAINT [FK_ModerationCase_assigned_to] FOREIGN KEY ([assigned_to]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ModerationCase_assigned_to' AND is_not_trusted = 1)
    ALTER TABLE [moderation].[ModerationCase] WITH CHECK CHECK CONSTRAINT [FK_ModerationCase_assigned_to];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ModerationAction_moderation_case_id' AND parent_object_id = OBJECT_ID(N'[moderation].[ModerationAction]'))
    ALTER TABLE [moderation].[ModerationAction] WITH CHECK ADD CONSTRAINT [FK_ModerationAction_moderation_case_id] FOREIGN KEY ([moderation_case_id]) REFERENCES [moderation].[ModerationCase] ([moderation_case_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ModerationAction_moderation_case_id' AND is_not_trusted = 1)
    ALTER TABLE [moderation].[ModerationAction] WITH CHECK CHECK CONSTRAINT [FK_ModerationAction_moderation_case_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ModerationAction_actor_member_id' AND parent_object_id = OBJECT_ID(N'[moderation].[ModerationAction]'))
    ALTER TABLE [moderation].[ModerationAction] WITH CHECK ADD CONSTRAINT [FK_ModerationAction_actor_member_id] FOREIGN KEY ([actor_member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ModerationAction_actor_member_id' AND is_not_trusted = 1)
    ALTER TABLE [moderation].[ModerationAction] WITH CHECK CHECK CONSTRAINT [FK_ModerationAction_actor_member_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ContentRule_created_by' AND parent_object_id = OBJECT_ID(N'[moderation].[ContentRule]'))
    ALTER TABLE [moderation].[ContentRule] WITH CHECK ADD CONSTRAINT [FK_ContentRule_created_by] FOREIGN KEY ([created_by]) REFERENCES [iam].[Member] ([member_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ContentRule_created_by' AND is_not_trusted = 1)
    ALTER TABLE [moderation].[ContentRule] WITH CHECK CHECK CONSTRAINT [FK_ContentRule_created_by];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ProductEvent_community_id' AND parent_object_id = OBJECT_ID(N'[analytics].[ProductEvent]'))
    ALTER TABLE [analytics].[ProductEvent] WITH CHECK ADD CONSTRAINT [FK_ProductEvent_community_id] FOREIGN KEY ([community_id]) REFERENCES [core].[Community] ([community_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ProductEvent_community_id' AND is_not_trusted = 1)
    ALTER TABLE [analytics].[ProductEvent] WITH CHECK CHECK CONSTRAINT [FK_ProductEvent_community_id];
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Member_status' AND parent_object_id = OBJECT_ID(N'[iam].[Member]'))
    ALTER TABLE [iam].[Member] WITH CHECK ADD CONSTRAINT [CK_Member_status] CHECK ([status] IN (N'PENDING',N'ACTIVE',N'SUSPENDED',N'DELETED'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_MemberDevice_platform' AND parent_object_id = OBJECT_ID(N'[iam].[MemberDevice]'))
    ALTER TABLE [iam].[MemberDevice] WITH CHECK ADD CONSTRAINT [CK_MemberDevice_platform] CHECK ([platform] IN (N'IOS',N'ANDROID'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_MemberDevice_status' AND parent_object_id = OBJECT_ID(N'[iam].[MemberDevice]'))
    ALTER TABLE [iam].[MemberDevice] WITH CHECK ADD CONSTRAINT [CK_MemberDevice_status] CHECK ([status] IN (N'ACTIVE',N'REVOKED'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_MemberProfile_profile_status' AND parent_object_id = OBJECT_ID(N'[core].[MemberProfile]'))
    ALTER TABLE [core].[MemberProfile] WITH CHECK ADD CONSTRAINT [CK_MemberProfile_profile_status] CHECK ([profile_status] IN (N'DRAFT',N'ACTIVE',N'HIDDEN'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_MemberProfile_visibility' AND parent_object_id = OBJECT_ID(N'[core].[MemberProfile]'))
    ALTER TABLE [core].[MemberProfile] WITH CHECK ADD CONSTRAINT [CK_MemberProfile_visibility] CHECK ([visibility] IN (N'PUBLIC',N'MEMBERS',N'CONNECTED',N'HIDDEN'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_MemberConsent_decision' AND parent_object_id = OBJECT_ID(N'[consent].[MemberConsent]'))
    ALTER TABLE [consent].[MemberConsent] WITH CHECK ADD CONSTRAINT [CK_MemberConsent_decision] CHECK ([decision] IN (N'GRANTED',N'DENIED',N'WITHDRAWN'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Event_status' AND parent_object_id = OBJECT_ID(N'[event].[Event]'))
    ALTER TABLE [event].[Event] WITH CHECK ADD CONSTRAINT [CK_Event_status] CHECK ([status] IN (N'DRAFT',N'PUBLISHED',N'ACTIVE',N'COMPLETED',N'CANCELLED'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_EventMatchingPolicy_status' AND parent_object_id = OBJECT_ID(N'[event].[EventMatchingPolicy]'))
    ALTER TABLE [event].[EventMatchingPolicy] WITH CHECK ADD CONSTRAINT [CK_EventMatchingPolicy_status] CHECK ([status] IN (N'DRAFT',N'ACTIVE',N'RETIRED'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_EventMatchingPolicy_proximity_mode' AND parent_object_id = OBJECT_ID(N'[event].[EventMatchingPolicy]'))
    ALTER TABLE [event].[EventMatchingPolicy] WITH CHECK ADD CONSTRAINT [CK_EventMatchingPolicy_proximity_mode] CHECK ([proximity_mode] IN (N'NONE',N'VENUE',N'COARSE_CELL'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_EventRegistration_status' AND parent_object_id = OBJECT_ID(N'[event].[EventRegistration]'))
    ALTER TABLE [event].[EventRegistration] WITH CHECK ADD CONSTRAINT [CK_EventRegistration_status] CHECK ([status] IN (N'INVITED',N'REGISTERED',N'CHECKED_IN',N'CANCELLED'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_LiveModeSession_status' AND parent_object_id = OBJECT_ID(N'[event].[LiveModeSession]'))
    ALTER TABLE [event].[LiveModeSession] WITH CHECK ADD CONSTRAINT [CK_LiveModeSession_status] CHECK ([status] IN (N'ACTIVE',N'DISABLED',N'EXPIRED'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_ConnectionRequest_status' AND parent_object_id = OBJECT_ID(N'[social].[ConnectionRequest]'))
    ALTER TABLE [social].[ConnectionRequest] WITH CHECK ADD CONSTRAINT [CK_ConnectionRequest_status] CHECK ([status] IN (N'PENDING',N'ACCEPTED',N'DECLINED',N'WITHDRAWN',N'EXPIRED'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Connection_status' AND parent_object_id = OBJECT_ID(N'[social].[Connection]'))
    ALTER TABLE [social].[Connection] WITH CHECK ADD CONSTRAINT [CK_Connection_status] CHECK ([status] IN (N'ACTIVE',N'DISCONNECTED'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Conversation_status' AND parent_object_id = OBJECT_ID(N'[chat].[Conversation]'))
    ALTER TABLE [chat].[Conversation] WITH CHECK ADD CONSTRAINT [CK_Conversation_status] CHECK ([status] IN (N'ACTIVE',N'CLOSED',N'RESTRICTED'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Message_message_type' AND parent_object_id = OBJECT_ID(N'[chat].[Message]'))
    ALTER TABLE [chat].[Message] WITH CHECK ADD CONSTRAINT [CK_Message_message_type] CHECK ([message_type] IN (N'TEXT',N'FILE',N'SYSTEM'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Attachment_scan_status' AND parent_object_id = OBJECT_ID(N'[chat].[Attachment]'))
    ALTER TABLE [chat].[Attachment] WITH CHECK ADD CONSTRAINT [CK_Attachment_scan_status] CHECK ([scan_status] IN (N'PENDING',N'CLEAN',N'REJECTED',N'ERROR'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_NotificationPolicy_channel' AND parent_object_id = OBJECT_ID(N'[notification].[NotificationPolicy]'))
    ALTER TABLE [notification].[NotificationPolicy] WITH CHECK ADD CONSTRAINT [CK_NotificationPolicy_channel] CHECK ([channel] IN (N'PUSH',N'EMAIL',N'IN_APP'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_NotificationPolicy_status' AND parent_object_id = OBJECT_ID(N'[notification].[NotificationPolicy]'))
    ALTER TABLE [notification].[NotificationPolicy] WITH CHECK ADD CONSTRAINT [CK_NotificationPolicy_status] CHECK ([status] IN (N'DRAFT',N'ACTIVE',N'RETIRED'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_NotificationPolicy_quiet_hours_behavior' AND parent_object_id = OBJECT_ID(N'[notification].[NotificationPolicy]'))
    ALTER TABLE [notification].[NotificationPolicy] WITH CHECK ADD CONSTRAINT [CK_NotificationPolicy_quiet_hours_behavior] CHECK ([quiet_hours_behavior] IN (N'DEFER',N'SUPPRESS',N'BYPASS'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_PushToken_provider' AND parent_object_id = OBJECT_ID(N'[notification].[PushToken]'))
    ALTER TABLE [notification].[PushToken] WITH CHECK ADD CONSTRAINT [CK_PushToken_provider] CHECK ([provider] IN (N'APNS',N'FCM'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_PushToken_status' AND parent_object_id = OBJECT_ID(N'[notification].[PushToken]'))
    ALTER TABLE [notification].[PushToken] WITH CHECK ADD CONSTRAINT [CK_PushToken_status] CHECK ([status] IN (N'ACTIVE',N'INVALID'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Notification_channel' AND parent_object_id = OBJECT_ID(N'[notification].[Notification]'))
    ALTER TABLE [notification].[Notification] WITH CHECK ADD CONSTRAINT [CK_Notification_channel] CHECK ([channel] IN (N'PUSH',N'EMAIL',N'IN_APP'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Notification_status' AND parent_object_id = OBJECT_ID(N'[notification].[Notification]'))
    ALTER TABLE [notification].[Notification] WITH CHECK ADD CONSTRAINT [CK_Notification_status] CHECK ([status] IN (N'PENDING',N'SENT',N'DELIVERED',N'FAILED',N'SUPPRESSED'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_NotificationDeliveryAttempt_status' AND parent_object_id = OBJECT_ID(N'[notification].[NotificationDeliveryAttempt]'))
    ALTER TABLE [notification].[NotificationDeliveryAttempt] WITH CHECK ADD CONSTRAINT [CK_NotificationDeliveryAttempt_status] CHECK ([status] IN (N'STARTED',N'ACCEPTED',N'DELIVERED',N'FAILED',N'EXPIRED'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_NlpIntent_intent_type' AND parent_object_id = OBJECT_ID(N'[nlp].[NlpIntent]'))
    ALTER TABLE [nlp].[NlpIntent] WITH CHECK ADD CONSTRAINT [CK_NlpIntent_intent_type] CHECK ([intent_type] IN (N'WANT',N'OFFER'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_NlpIntent_status' AND parent_object_id = OBJECT_ID(N'[nlp].[NlpIntent]'))
    ALTER TABLE [nlp].[NlpIntent] WITH CHECK ADD CONSTRAINT [CK_NlpIntent_status] CHECK ([status] IN (N'PROCESSING',N'MATCH_READY',N'FAILED',N'INACTIVE'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_NlpEmbedding_status' AND parent_object_id = OBJECT_ID(N'[nlp].[NlpEmbedding]'))
    ALTER TABLE [nlp].[NlpEmbedding] WITH CHECK ADD CONSTRAINT [CK_NlpEmbedding_status] CHECK ([status] IN (N'ACTIVE',N'SUPERSEDED',N'FAILED'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_NlpModelVersion_status' AND parent_object_id = OBJECT_ID(N'[nlp].[NlpModelVersion]'))
    ALTER TABLE [nlp].[NlpModelVersion] WITH CHECK ADD CONSTRAINT [CK_NlpModelVersion_status] CHECK ([status] IN (N'CANDIDATE',N'ACTIVE',N'RETIRED',N'ROLLED_BACK'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_NlpProcessingJob_job_type' AND parent_object_id = OBJECT_ID(N'[nlp].[NlpProcessingJob]'))
    ALTER TABLE [nlp].[NlpProcessingJob] WITH CHECK ADD CONSTRAINT [CK_NlpProcessingJob_job_type] CHECK ([job_type] IN (N'EMBED',N'REEMBED'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_NlpProcessingJob_status' AND parent_object_id = OBJECT_ID(N'[nlp].[NlpProcessingJob]'))
    ALTER TABLE [nlp].[NlpProcessingJob] WITH CHECK ADD CONSTRAINT [CK_NlpProcessingJob_status] CHECK ([status] IN (N'PENDING',N'RUNNING',N'SUCCEEDED',N'FAILED',N'DEAD'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_MatchRequest_status' AND parent_object_id = OBJECT_ID(N'[nlp].[MatchRequest]'))
    ALTER TABLE [nlp].[MatchRequest] WITH CHECK ADD CONSTRAINT [CK_MatchRequest_status] CHECK ([status] IN (N'PROCESSING',N'COMPLETED',N'FAILED'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_NlpFeedback_label' AND parent_object_id = OBJECT_ID(N'[nlp].[NlpFeedback]'))
    ALTER TABLE [nlp].[NlpFeedback] WITH CHECK ADD CONSTRAINT [CK_NlpFeedback_label] CHECK ([label] IN (N'USEFUL',N'NOT_USEFUL',N'INAPPROPRIATE'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_MemberProfile_Completeness' AND parent_object_id = OBJECT_ID(N'[core].[MemberProfile]'))
    ALTER TABLE [core].[MemberProfile] WITH CHECK ADD CONSTRAINT [CK_MemberProfile_Completeness] CHECK ([completeness_score] BETWEEN 0 AND 100);
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Event_DateRange' AND parent_object_id = OBJECT_ID(N'[event].[Event]'))
    ALTER TABLE [event].[Event] WITH CHECK ADD CONSTRAINT [CK_Event_DateRange] CHECK ([ends_at] > [starts_at]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_EventMatchingPolicy_Thresholds' AND parent_object_id = OBJECT_ID(N'[event].[EventMatchingPolicy]'))
    ALTER TABLE [event].[EventMatchingPolicy] WITH CHECK ADD CONSTRAINT [CK_EventMatchingPolicy_Thresholds] CHECK (([match_threshold_override] IS NULL OR [match_threshold_override] BETWEEN 0 AND 1) AND [alert_confidence_threshold] BETWEEN 0 AND 1);
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_EventMatchingPolicy_Limits' AND parent_object_id = OBJECT_ID(N'[event].[EventMatchingPolicy]'))
    ALTER TABLE [event].[EventMatchingPolicy] WITH CHECK ADD CONSTRAINT [CK_EventMatchingPolicy_Limits] CHECK ([max_match_alerts_per_hour] >= 0 AND [max_match_alerts_per_event] >= 0 AND [minimum_alert_interval_minutes] >= 0 AND ([effective_to] IS NULL OR [effective_to] > [effective_from]));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_EventMatchingPolicy_Proximity' AND parent_object_id = OBJECT_ID(N'[event].[EventMatchingPolicy]'))
    ALTER TABLE [event].[EventMatchingPolicy] WITH CHECK ADD CONSTRAINT [CK_EventMatchingPolicy_Proximity] CHECK ([check_in_required] = 0 OR [registration_required] = 1);
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_ConnectionRequest_Members' AND parent_object_id = OBJECT_ID(N'[social].[ConnectionRequest]'))
    ALTER TABLE [social].[ConnectionRequest] WITH CHECK ADD CONSTRAINT [CK_ConnectionRequest_Members] CHECK ([sender_member_id] <> [recipient_member_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_ConnectionRequest_Expiry' AND parent_object_id = OBJECT_ID(N'[social].[ConnectionRequest]'))
    ALTER TABLE [social].[ConnectionRequest] WITH CHECK ADD CONSTRAINT [CK_ConnectionRequest_Expiry] CHECK ([expires_at] > [created_at]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Connection_CanonicalPair' AND parent_object_id = OBJECT_ID(N'[social].[Connection]'))
    ALTER TABLE [social].[Connection] WITH CHECK ADD CONSTRAINT [CK_Connection_CanonicalPair] CHECK ([member_low_id] < [member_high_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_MemberBlock_Members' AND parent_object_id = OBJECT_ID(N'[social].[MemberBlock]'))
    ALTER TABLE [social].[MemberBlock] WITH CHECK ADD CONSTRAINT [CK_MemberBlock_Members] CHECK ([blocker_member_id] <> [blocked_member_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_NotificationPolicy_Limits' AND parent_object_id = OBJECT_ID(N'[notification].[NotificationPolicy]'))
    ALTER TABLE [notification].[NotificationPolicy] WITH CHECK ADD CONSTRAINT [CK_NotificationPolicy_Limits] CHECK ([dedupe_window_seconds] > 0 AND [max_per_hour] > 0 AND [max_per_day] > 0 AND [max_attempts] > 0 AND [ttl_minutes] > 0 AND ([effective_to] IS NULL OR [effective_to] > [effective_from]));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Notification_Confidence' AND parent_object_id = OBJECT_ID(N'[notification].[Notification]'))
    ALTER TABLE [notification].[Notification] WITH CHECK ADD CONSTRAINT [CK_Notification_Confidence] CHECK ([source_confidence] IS NULL OR [source_confidence] BETWEEN 0 AND 1);
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Notification_Expiry' AND parent_object_id = OBJECT_ID(N'[notification].[Notification]'))
    ALTER TABLE [notification].[Notification] WITH CHECK ADD CONSTRAINT [CK_Notification_Expiry] CHECK ([expires_at] > [created_at]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_NotificationDeliveryAttempt_Attempt' AND parent_object_id = OBJECT_ID(N'[notification].[NotificationDeliveryAttempt]'))
    ALTER TABLE [notification].[NotificationDeliveryAttempt] WITH CHECK ADD CONSTRAINT [CK_NotificationDeliveryAttempt_Attempt] CHECK ([attempt_number] > 0 AND ([duration_ms] IS NULL OR [duration_ms] >= 0));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_NlpRankingConfig_Weights' AND parent_object_id = OBJECT_ID(N'[nlp].[NlpRankingConfig]'))
    ALTER TABLE [nlp].[NlpRankingConfig] WITH CHECK ADD CONSTRAINT [CK_NlpRankingConfig_Weights] CHECK ([semantic_weight] BETWEEN 0 AND 1 AND [category_weight] BETWEEN 0 AND 1 AND [industry_weight] BETWEEN 0 AND 1 AND [geography_weight] BETWEEN 0 AND 1 AND [freshness_weight] BETWEEN 0 AND 1 AND [event_weight] BETWEEN 0 AND 1 AND [threshold] BETWEEN 0 AND 1);
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_MatchRequest_Limit' AND parent_object_id = OBJECT_ID(N'[nlp].[MatchRequest]'))
    ALTER TABLE [nlp].[MatchRequest] WITH CHECK ADD CONSTRAINT [CK_MatchRequest_Limit] CHECK ([requested_limit] BETWEEN 3 AND 7);
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_NlpMatchResult_Scores' AND parent_object_id = OBJECT_ID(N'[nlp].[NlpMatchResult]'))
    ALTER TABLE [nlp].[NlpMatchResult] WITH CHECK ADD CONSTRAINT [CK_NlpMatchResult_Scores] CHECK ([semantic_score] BETWEEN 0 AND 1 AND ([reciprocal_score] IS NULL OR [reciprocal_score] BETWEEN 0 AND 1) AND [final_score] BETWEEN 0 AND 1 AND [rank] > 0);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[Community]') AND name = N'UX_Community_Name')
    CREATE UNIQUE INDEX [UX_Community_Name] ON [core].[Community] ([name]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[iam].[MemberIdentity]') AND name = N'UX_MemberIdentity_ProviderSubject')
    CREATE UNIQUE INDEX [UX_MemberIdentity_ProviderSubject] ON [iam].[MemberIdentity] ([provider], [provider_subject]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[iam].[MemberIdentity]') AND name = N'UX_MemberIdentity_Primary')
    CREATE UNIQUE INDEX [UX_MemberIdentity_Primary] ON [iam].[MemberIdentity] ([member_id]) WHERE is_primary = 1;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[iam].[Role]') AND name = N'UX_Role_Name')
    CREATE UNIQUE INDEX [UX_Role_Name] ON [iam].[Role] ([name]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[Organization]') AND name = N'UX_Organization_CommunityName')
    CREATE UNIQUE INDEX [UX_Organization_CommunityName] ON [core].[Organization] ([community_id], [normalized_name]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[OrganizationMember]') AND name = N'UX_OrganizationMember_Active')
    CREATE UNIQUE INDEX [UX_OrganizationMember_Active] ON [core].[OrganizationMember] ([organization_id], [member_id]) WHERE ended_on IS NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[MemberSector]') AND name = N'UX_MemberSector_Primary')
    CREATE UNIQUE INDEX [UX_MemberSector_Primary] ON [core].[MemberSector] ([member_id]) WHERE is_primary = 1;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[MemberGeography]') AND name = N'UX_MemberGeography_Primary')
    CREATE UNIQUE INDEX [UX_MemberGeography_Primary] ON [core].[MemberGeography] ([member_id]) WHERE is_primary = 1;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[consent].[ConsentPolicy]') AND name = N'UX_ConsentPolicy_PurposeVersionLocale')
    CREATE UNIQUE INDEX [UX_ConsentPolicy_PurposeVersionLocale] ON [consent].[ConsentPolicy] ([purpose_code], [version], [locale]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[event].[EventMatchingPolicy]') AND name = N'UX_EventMatchingPolicy_Version')
    CREATE UNIQUE INDEX [UX_EventMatchingPolicy_Version] ON [event].[EventMatchingPolicy] ([event_id], [policy_version]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[event].[EventMatchingPolicy]') AND name = N'UX_EventMatchingPolicy_Active')
    CREATE UNIQUE INDEX [UX_EventMatchingPolicy_Active] ON [event].[EventMatchingPolicy] ([event_id]) WHERE status = 'ACTIVE';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[event].[EventRegistration]') AND name = N'UX_EventRegistration_EventMember')
    CREATE UNIQUE INDEX [UX_EventRegistration_EventMember] ON [event].[EventRegistration] ([event_id], [member_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[event].[LiveModeSession]') AND name = N'UX_LiveModeSession_Active')
    CREATE UNIQUE INDEX [UX_LiveModeSession_Active] ON [event].[LiveModeSession] ([event_id], [member_id]) WHERE status = 'ACTIVE';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[social].[ConnectionRequest]') AND name = N'UX_ConnectionRequest_OpenPair')
    CREATE UNIQUE INDEX [UX_ConnectionRequest_OpenPair] ON [social].[ConnectionRequest] ([sender_member_id], [recipient_member_id]) WHERE status = 'PENDING';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[social].[Connection]') AND name = N'UX_Connection_Pair')
    CREATE UNIQUE INDEX [UX_Connection_Pair] ON [social].[Connection] ([member_low_id], [member_high_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[social].[Connection]') AND name = N'UX_Connection_AcceptedRequest')
    CREATE UNIQUE INDEX [UX_Connection_AcceptedRequest] ON [social].[Connection] ([accepted_request_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[social].[MemberBlock]') AND name = N'UX_MemberBlock_Active')
    CREATE UNIQUE INDEX [UX_MemberBlock_Active] ON [social].[MemberBlock] ([blocker_member_id], [blocked_member_id]) WHERE removed_at IS NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[chat].[Conversation]') AND name = N'UX_Conversation_Connection')
    CREATE UNIQUE INDEX [UX_Conversation_Connection] ON [chat].[Conversation] ([connection_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[chat].[Message]') AND name = N'UX_Message_ConversationMessage')
    CREATE UNIQUE INDEX [UX_Message_ConversationMessage] ON [chat].[Message] ([conversation_id], [message_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[chat].[Attachment]') AND name = N'UX_Attachment_BlobPathHash')
    CREATE UNIQUE INDEX [UX_Attachment_BlobPathHash] ON [chat].[Attachment] ([blob_path_hash]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[notification].[NotificationPolicy]') AND name = N'UX_NotificationPolicy_Version')
    CREATE UNIQUE INDEX [UX_NotificationPolicy_Version] ON [notification].[NotificationPolicy] ([community_id], [purpose_code], [channel], [policy_version]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[notification].[NotificationPolicy]') AND name = N'UX_NotificationPolicy_Active')
    CREATE UNIQUE INDEX [UX_NotificationPolicy_Active] ON [notification].[NotificationPolicy] ([community_id], [purpose_code], [channel]) WHERE status = 'ACTIVE';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[notification].[PushToken]') AND name = N'UX_PushToken_Fingerprint')
    CREATE UNIQUE INDEX [UX_PushToken_Fingerprint] ON [notification].[PushToken] ([token_fingerprint]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[notification].[Notification]') AND name = N'UX_Notification_Dedupe')
    CREATE UNIQUE INDEX [UX_Notification_Dedupe] ON [notification].[Notification] ([member_id], [channel], [dedupe_key], [dedupe_bucket_start]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[notification].[NotificationDeliveryAttempt]') AND name = N'UX_NotificationAttempt_Number')
    CREATE UNIQUE INDEX [UX_NotificationAttempt_Number] ON [notification].[NotificationDeliveryAttempt] ([notification_id], [attempt_number]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[NlpEmbedding]') AND name = N'UX_NlpEmbedding_HashModel')
    CREATE UNIQUE INDEX [UX_NlpEmbedding_HashModel] ON [nlp].[NlpEmbedding] ([intent_id], [normalized_hash], [model_version]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[NlpModelVersion]') AND name = N'UX_NlpModelVersion_Active')
    CREATE UNIQUE INDEX [UX_NlpModelVersion_Active] ON [nlp].[NlpModelVersion] ([status]) WHERE status = 'ACTIVE';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[NlpRankingConfig]') AND name = N'UX_NlpRankingConfig_Active')
    CREATE UNIQUE INDEX [UX_NlpRankingConfig_Active] ON [nlp].[NlpRankingConfig] ([active_to]) WHERE active_to IS NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[NlpProcessingJob]') AND name = N'UX_NlpProcessingJob_Active')
    CREATE UNIQUE INDEX [UX_NlpProcessingJob_Active] ON [nlp].[NlpProcessingJob] ([intent_id], [job_type]) WHERE status IN ('PENDING','RUNNING');
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[NlpMatchResult]') AND name = N'UX_NlpMatchResult_RequestCandidate')
    CREATE UNIQUE INDEX [UX_NlpMatchResult_RequestCandidate] ON [nlp].[NlpMatchResult] ([request_id], [candidate_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[NlpMatchResult]') AND name = N'UX_NlpMatchResult_RequestRank')
    CREATE UNIQUE INDEX [UX_NlpMatchResult_RequestRank] ON [nlp].[NlpMatchResult] ([request_id], [rank]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[NlpFeedback]') AND name = N'UX_NlpFeedback_Original')
    CREATE UNIQUE INDEX [UX_NlpFeedback_Original] ON [nlp].[NlpFeedback] ([match_result_id], [requester_id]) WHERE supersedes_feedback_id IS NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[NlpFeedback]') AND name = N'UX_NlpFeedback_Superseded')
    CREATE UNIQUE INDEX [UX_NlpFeedback_Superseded] ON [nlp].[NlpFeedback] ([supersedes_feedback_id]) WHERE supersedes_feedback_id IS NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[EvaluationDataset]') AND name = N'UX_EvaluationDataset_NameVersion')
    CREATE UNIQUE INDEX [UX_EvaluationDataset_NameVersion] ON [nlp].[EvaluationDataset] ([name], [version]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[iam].[Member]') AND name = N'IX_Member_CommunityStatus')
    CREATE INDEX [IX_Member_CommunityStatus] ON [iam].[Member] ([community_id], [status]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[MemberProfile]') AND name = N'IX_MemberProfile_Discovery')
    CREATE INDEX [IX_MemberProfile_Discovery] ON [core].[MemberProfile] ([profile_status], [visibility], [updated_at]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[event].[Event]') AND name = N'IX_Event_CommunityStatusStart')
    CREATE INDEX [IX_Event_CommunityStatusStart] ON [event].[Event] ([community_id], [status], [starts_at]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[event].[EventPresence]') AND name = N'IX_EventPresence_CellExpiry')
    CREATE INDEX [IX_EventPresence_CellExpiry] ON [event].[EventPresence] ([coarse_cell], [expires_at]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[social].[ConnectionRequest]') AND name = N'IX_ConnectionRequest_RecipientStatusExpiry')
    CREATE INDEX [IX_ConnectionRequest_RecipientStatusExpiry] ON [social].[ConnectionRequest] ([recipient_member_id], [status], [expires_at], [created_at]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[chat].[Message]') AND name = N'IX_Message_ConversationSequence')
    CREATE INDEX [IX_Message_ConversationSequence] ON [chat].[Message] ([conversation_id], [server_sequence]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[notification].[Notification]') AND name = N'IX_Notification_Due')
    CREATE INDEX [IX_Notification_Due] ON [notification].[Notification] ([status], [scheduled_at], [expires_at]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[notification].[Notification]') AND name = N'IX_Notification_RateLimit')
    CREATE INDEX [IX_Notification_RateLimit] ON [notification].[Notification] ([member_id], [notification_policy_id], [created_at]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[notification].[Notification]') AND name = N'IX_Notification_EventLimit')
    CREATE INDEX [IX_Notification_EventLimit] ON [notification].[Notification] ([member_id], [event_matching_policy_id], [context_id], [created_at]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[notification].[NotificationDeliveryAttempt]') AND name = N'IX_NotificationAttempt_Retry')
    CREATE INDEX [IX_NotificationAttempt_Retry] ON [notification].[NotificationDeliveryAttempt] ([status], [next_attempt_at]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[NlpIntent]') AND name = N'IX_NlpIntent_ContextTypeStatusExpiry')
    CREATE INDEX [IX_NlpIntent_ContextTypeStatusExpiry] ON [nlp].[NlpIntent] ([context_id], [intent_type], [status], [expires_at]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[MatchRequest]') AND name = N'IX_MatchRequest_RequesterCreated')
    CREATE INDEX [IX_MatchRequest_RequesterCreated] ON [nlp].[MatchRequest] ([requester_id], [created_at]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[NlpMatchResult]') AND name = N'IX_NlpMatchResult_CandidateCreated')
    CREATE INDEX [IX_NlpMatchResult_CandidateCreated] ON [nlp].[NlpMatchResult] ([candidate_id], [created_at]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[ops].[OutboxEvent]') AND name = N'IX_OutboxEvent_Due')
    CREATE INDEX [IX_OutboxEvent_Due] ON [ops].[OutboxEvent] ([published_at], [next_attempt_at]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[ops].[BackgroundJob]') AND name = N'IX_BackgroundJob_Due')
    CREATE INDEX [IX_BackgroundJob_Due] ON [ops].[BackgroundJob] ([status], [available_at]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[ops].[IdempotencyRecord]') AND name = N'IX_IdempotencyRecord_Expiry')
    CREATE INDEX [IX_IdempotencyRecord_Expiry] ON [ops].[IdempotencyRecord] ([expires_at]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[analytics].[ProductEvent]') AND name = N'IX_ProductEvent_NameOccurred')
    CREATE INDEX [IX_ProductEvent_NameOccurred] ON [analytics].[ProductEvent] ([event_name], [occurred_at]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[iam].[MemberRole]') AND name = N'IX_MemberRole_member_id')
    CREATE INDEX [IX_MemberRole_member_id] ON [iam].[MemberRole] ([member_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[iam].[MemberRole]') AND name = N'IX_MemberRole_role_code')
    CREATE INDEX [IX_MemberRole_role_code] ON [iam].[MemberRole] ([role_code]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[iam].[MemberRole]') AND name = N'IX_MemberRole_granted_by')
    CREATE INDEX [IX_MemberRole_granted_by] ON [iam].[MemberRole] ([granted_by]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[iam].[MemberDevice]') AND name = N'IX_MemberDevice_member_id')
    CREATE INDEX [IX_MemberDevice_member_id] ON [iam].[MemberDevice] ([member_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[OrganizationMember]') AND name = N'IX_OrganizationMember_member_id')
    CREATE INDEX [IX_OrganizationMember_member_id] ON [core].[OrganizationMember] ([member_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[MemberProfile]') AND name = N'IX_MemberProfile_member_id')
    CREATE INDEX [IX_MemberProfile_member_id] ON [core].[MemberProfile] ([member_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[Sector]') AND name = N'IX_Sector_parent_sector_code')
    CREATE INDEX [IX_Sector_parent_sector_code] ON [core].[Sector] ([parent_sector_code]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[MemberSector]') AND name = N'IX_MemberSector_sector_code')
    CREATE INDEX [IX_MemberSector_sector_code] ON [core].[MemberSector] ([sector_code]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[ProfileFieldVisibility]') AND name = N'IX_ProfileFieldVisibility_member_id')
    CREATE INDEX [IX_ProfileFieldVisibility_member_id] ON [core].[ProfileFieldVisibility] ([member_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[MemberVerification]') AND name = N'IX_MemberVerification_member_id')
    CREATE INDEX [IX_MemberVerification_member_id] ON [core].[MemberVerification] ([member_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[MemberVerification]') AND name = N'IX_MemberVerification_evidence_attachment_id')
    CREATE INDEX [IX_MemberVerification_evidence_attachment_id] ON [core].[MemberVerification] ([evidence_attachment_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[MemberVerification]') AND name = N'IX_MemberVerification_reviewed_by')
    CREATE INDEX [IX_MemberVerification_reviewed_by] ON [core].[MemberVerification] ([reviewed_by]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[consent].[MemberConsent]') AND name = N'IX_MemberConsent_member_id')
    CREATE INDEX [IX_MemberConsent_member_id] ON [consent].[MemberConsent] ([member_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[consent].[MemberConsent]') AND name = N'IX_MemberConsent_policy_id')
    CREATE INDEX [IX_MemberConsent_policy_id] ON [consent].[MemberConsent] ([policy_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[consent].[PrivacyRequest]') AND name = N'IX_PrivacyRequest_member_id')
    CREATE INDEX [IX_PrivacyRequest_member_id] ON [consent].[PrivacyRequest] ([member_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[consent].[PrivacyRequest]') AND name = N'IX_PrivacyRequest_result_attachment_id')
    CREATE INDEX [IX_PrivacyRequest_result_attachment_id] ON [consent].[PrivacyRequest] ([result_attachment_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[event].[Event]') AND name = N'IX_Event_venue_id')
    CREATE INDEX [IX_Event_venue_id] ON [event].[Event] ([venue_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[event].[EventRegistration]') AND name = N'IX_EventRegistration_member_id')
    CREATE INDEX [IX_EventRegistration_member_id] ON [event].[EventRegistration] ([member_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[event].[LiveModeSession]') AND name = N'IX_LiveModeSession_member_id')
    CREATE INDEX [IX_LiveModeSession_member_id] ON [event].[LiveModeSession] ([member_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[event].[LiveModeSession]') AND name = N'IX_LiveModeSession_consent_record_id')
    CREATE INDEX [IX_LiveModeSession_consent_record_id] ON [event].[LiveModeSession] ([consent_record_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[event].[EventPresence]') AND name = N'IX_EventPresence_live_session_id')
    CREATE INDEX [IX_EventPresence_live_session_id] ON [event].[EventPresence] ([live_session_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[social].[ConnectionRequest]') AND name = N'IX_ConnectionRequest_match_result_id')
    CREATE INDEX [IX_ConnectionRequest_match_result_id] ON [social].[ConnectionRequest] ([match_result_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[social].[Connection]') AND name = N'IX_Connection_member_high_id')
    CREATE INDEX [IX_Connection_member_high_id] ON [social].[Connection] ([member_high_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[social].[MemberBlock]') AND name = N'IX_MemberBlock_blocked_member_id')
    CREATE INDEX [IX_MemberBlock_blocked_member_id] ON [social].[MemberBlock] ([blocked_member_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[social].[MemberReport]') AND name = N'IX_MemberReport_reporter_member_id')
    CREATE INDEX [IX_MemberReport_reporter_member_id] ON [social].[MemberReport] ([reporter_member_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[social].[MemberReport]') AND name = N'IX_MemberReport_reported_member_id')
    CREATE INDEX [IX_MemberReport_reported_member_id] ON [social].[MemberReport] ([reported_member_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[chat].[ConversationParticipant]') AND name = N'IX_ConversationParticipant_conversation_id')
    CREATE INDEX [IX_ConversationParticipant_conversation_id] ON [chat].[ConversationParticipant] ([conversation_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[chat].[ConversationParticipant]') AND name = N'IX_ConversationParticipant_member_id')
    CREATE INDEX [IX_ConversationParticipant_member_id] ON [chat].[ConversationParticipant] ([member_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[chat].[ConversationParticipant]') AND name = N'IX_ConversationParticipant_last_read_message_id')
    CREATE INDEX [IX_ConversationParticipant_last_read_message_id] ON [chat].[ConversationParticipant] ([last_read_message_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[chat].[Message]') AND name = N'IX_Message_sender_member_id')
    CREATE INDEX [IX_Message_sender_member_id] ON [chat].[Message] ([sender_member_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[chat].[Attachment]') AND name = N'IX_Attachment_message_id')
    CREATE INDEX [IX_Attachment_message_id] ON [chat].[Attachment] ([message_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[chat].[Attachment]') AND name = N'IX_Attachment_owner_member_id')
    CREATE INDEX [IX_Attachment_owner_member_id] ON [chat].[Attachment] ([owner_member_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[chat].[MessageReceipt]') AND name = N'IX_MessageReceipt_message_id')
    CREATE INDEX [IX_MessageReceipt_message_id] ON [chat].[MessageReceipt] ([message_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[chat].[MessageReceipt]') AND name = N'IX_MessageReceipt_member_id')
    CREATE INDEX [IX_MessageReceipt_member_id] ON [chat].[MessageReceipt] ([member_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[notification].[NotificationPreference]') AND name = N'IX_NotificationPreference_member_id')
    CREATE INDEX [IX_NotificationPreference_member_id] ON [notification].[NotificationPreference] ([member_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[notification].[PushToken]') AND name = N'IX_PushToken_device_id')
    CREATE INDEX [IX_PushToken_device_id] ON [notification].[PushToken] ([device_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[notification].[Notification]') AND name = N'IX_Notification_notification_policy_id')
    CREATE INDEX [IX_Notification_notification_policy_id] ON [notification].[Notification] ([notification_policy_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[notification].[Notification]') AND name = N'IX_Notification_event_matching_policy_id')
    CREATE INDEX [IX_Notification_event_matching_policy_id] ON [notification].[Notification] ([event_matching_policy_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[notification].[NotificationDeliveryAttempt]') AND name = N'IX_NotificationDeliveryAttempt_push_token_id')
    CREATE INDEX [IX_NotificationDeliveryAttempt_push_token_id] ON [notification].[NotificationDeliveryAttempt] ([push_token_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[NlpIntent]') AND name = N'IX_NlpIntent_member_id')
    CREATE INDEX [IX_NlpIntent_member_id] ON [nlp].[NlpIntent] ([member_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[NlpEmbedding]') AND name = N'IX_NlpEmbedding_model_version')
    CREATE INDEX [IX_NlpEmbedding_model_version] ON [nlp].[NlpEmbedding] ([model_version]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[MatchRequest]') AND name = N'IX_MatchRequest_intent_id')
    CREATE INDEX [IX_MatchRequest_intent_id] ON [nlp].[MatchRequest] ([intent_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[MatchRequest]') AND name = N'IX_MatchRequest_model_version')
    CREATE INDEX [IX_MatchRequest_model_version] ON [nlp].[MatchRequest] ([model_version]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[MatchRequest]') AND name = N'IX_MatchRequest_ranking_version')
    CREATE INDEX [IX_MatchRequest_ranking_version] ON [nlp].[MatchRequest] ([ranking_version]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[NlpMatchResult]') AND name = N'IX_NlpMatchResult_requester_id')
    CREATE INDEX [IX_NlpMatchResult_requester_id] ON [nlp].[NlpMatchResult] ([requester_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[NlpMatchResult]') AND name = N'IX_NlpMatchResult_model_version')
    CREATE INDEX [IX_NlpMatchResult_model_version] ON [nlp].[NlpMatchResult] ([model_version]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[NlpMatchResult]') AND name = N'IX_NlpMatchResult_ranking_version')
    CREATE INDEX [IX_NlpMatchResult_ranking_version] ON [nlp].[NlpMatchResult] ([ranking_version]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[NlpFeedback]') AND name = N'IX_NlpFeedback_request_id')
    CREATE INDEX [IX_NlpFeedback_request_id] ON [nlp].[NlpFeedback] ([request_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[NlpFeedback]') AND name = N'IX_NlpFeedback_requester_id')
    CREATE INDEX [IX_NlpFeedback_requester_id] ON [nlp].[NlpFeedback] ([requester_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[NlpFeedback]') AND name = N'IX_NlpFeedback_candidate_id')
    CREATE INDEX [IX_NlpFeedback_candidate_id] ON [nlp].[NlpFeedback] ([candidate_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[MatchSuppression]') AND name = N'IX_MatchSuppression_member_id')
    CREATE INDEX [IX_MatchSuppression_member_id] ON [nlp].[MatchSuppression] ([member_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[MatchSuppression]') AND name = N'IX_MatchSuppression_intent_id')
    CREATE INDEX [IX_MatchSuppression_intent_id] ON [nlp].[MatchSuppression] ([intent_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[MatchSuppression]') AND name = N'IX_MatchSuppression_created_by')
    CREATE INDEX [IX_MatchSuppression_created_by] ON [nlp].[MatchSuppression] ([created_by]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[EvaluationDataset]') AND name = N'IX_EvaluationDataset_approved_by')
    CREATE INDEX [IX_EvaluationDataset_approved_by] ON [nlp].[EvaluationDataset] ([approved_by]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[EvaluationPair]') AND name = N'IX_EvaluationPair_dataset_id')
    CREATE INDEX [IX_EvaluationPair_dataset_id] ON [nlp].[EvaluationPair] ([dataset_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[EvaluationRun]') AND name = N'IX_EvaluationRun_dataset_id')
    CREATE INDEX [IX_EvaluationRun_dataset_id] ON [nlp].[EvaluationRun] ([dataset_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[EvaluationRun]') AND name = N'IX_EvaluationRun_model_version')
    CREATE INDEX [IX_EvaluationRun_model_version] ON [nlp].[EvaluationRun] ([model_version]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[EvaluationRun]') AND name = N'IX_EvaluationRun_ranking_version')
    CREATE INDEX [IX_EvaluationRun_ranking_version] ON [nlp].[EvaluationRun] ([ranking_version]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[moderation].[ModerationCase]') AND name = N'IX_ModerationCase_subject_member_id')
    CREATE INDEX [IX_ModerationCase_subject_member_id] ON [moderation].[ModerationCase] ([subject_member_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[moderation].[ModerationCase]') AND name = N'IX_ModerationCase_assigned_to')
    CREATE INDEX [IX_ModerationCase_assigned_to] ON [moderation].[ModerationCase] ([assigned_to]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[moderation].[ModerationAction]') AND name = N'IX_ModerationAction_moderation_case_id')
    CREATE INDEX [IX_ModerationAction_moderation_case_id] ON [moderation].[ModerationAction] ([moderation_case_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[moderation].[ModerationAction]') AND name = N'IX_ModerationAction_actor_member_id')
    CREATE INDEX [IX_ModerationAction_actor_member_id] ON [moderation].[ModerationAction] ([actor_member_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[moderation].[ContentRule]') AND name = N'IX_ContentRule_created_by')
    CREATE INDEX [IX_ContentRule_created_by] ON [moderation].[ContentRule] ([created_by]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[analytics].[ProductEvent]') AND name = N'IX_ProductEvent_community_id')
    CREATE INDEX [IX_ProductEvent_community_id] ON [analytics].[ProductEvent] ([community_id]);
GO
