/*
OLGA Connect Release 1 - Azure SQL full database setup
Architecture baseline: Database Architecture and Table-Level Design v2.2
Target: a new, empty Azure SQL Database

This script is additive and does not drop objects. Provisional QA notification-policy
seeding is disabled in the seed section (IF 0=1) until product/security approval.
*/

-- ======================== SCHEMAS AND SEQUENCE ========================
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF SCHEMA_ID(N'core') IS NULL EXEC(N'CREATE SCHEMA [core] AUTHORIZATION dbo');
GO
IF SCHEMA_ID(N'iam') IS NULL EXEC(N'CREATE SCHEMA [iam] AUTHORIZATION dbo');
GO
IF SCHEMA_ID(N'consent') IS NULL EXEC(N'CREATE SCHEMA [consent] AUTHORIZATION dbo');
GO
IF SCHEMA_ID(N'event') IS NULL EXEC(N'CREATE SCHEMA [event] AUTHORIZATION dbo');
GO
IF SCHEMA_ID(N'social') IS NULL EXEC(N'CREATE SCHEMA [social] AUTHORIZATION dbo');
GO
IF SCHEMA_ID(N'chat') IS NULL EXEC(N'CREATE SCHEMA [chat] AUTHORIZATION dbo');
GO
IF SCHEMA_ID(N'notification') IS NULL EXEC(N'CREATE SCHEMA [notification] AUTHORIZATION dbo');
GO
IF SCHEMA_ID(N'nlp') IS NULL EXEC(N'CREATE SCHEMA [nlp] AUTHORIZATION dbo');
GO
IF SCHEMA_ID(N'moderation') IS NULL EXEC(N'CREATE SCHEMA [moderation] AUTHORIZATION dbo');
GO
IF SCHEMA_ID(N'ops') IS NULL EXEC(N'CREATE SCHEMA [ops] AUTHORIZATION dbo');
GO
IF SCHEMA_ID(N'analytics') IS NULL EXEC(N'CREATE SCHEMA [analytics] AUTHORIZATION dbo');
GO
IF SCHEMA_ID(N'admin') IS NULL EXEC(N'CREATE SCHEMA [admin] AUTHORIZATION dbo');
GO

IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = N'MessageSequence' AND schema_id = SCHEMA_ID(N'chat'))
    EXEC(N'CREATE SEQUENCE chat.MessageSequence AS bigint START WITH 1 INCREMENT BY 1 CACHE 100');
GO


-- ======================== TABLES ========================
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO

-- core.Community: Network/community boundary; one OLGA row in Release 1.
IF OBJECT_ID(N'[core].[Community]', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[Community] (
        [community_id] varchar(64) NOT NULL -- Stable API identifier.,
        [name] nvarchar(200) NOT NULL -- Display name.,
        [status] varchar(24) NOT NULL CONSTRAINT [DF_Community_status] DEFAULT ('ACTIVE') -- ACTIVE, SUSPENDED or CLOSED.,
        [default_locale] varchar(16) NOT NULL CONSTRAINT [DF_Community_default_locale] DEFAULT ('en') -- BCP-47 default locale.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Community_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Community_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_Community_] PRIMARY KEY ([community_id])
    );
END;
GO

-- iam.Member: Authoritative member account and lifecycle state.
IF OBJECT_ID(N'[iam].[Member]', N'U') IS NULL
BEGIN
    CREATE TABLE [iam].[Member] (
        [member_id] varchar(64) NOT NULL -- Opaque identifier; use GUID/ULID string.,
        [community_id] varchar(64) NOT NULL -- FK core.Community.,
        [status] varchar(24) NOT NULL CONSTRAINT [DF_Member_status] DEFAULT ('PENDING') -- PENDING, ACTIVE, SUSPENDED, ANONYMIZED, DELETED.,
        [locale] varchar(16) NOT NULL CONSTRAINT [DF_Member_locale] DEFAULT ('en') -- Preferred locale.,
        [verified_at] datetimeoffset(7) NULL -- First completed account verification.,
        [suspended_at] datetimeoffset(7) NULL -- Administrative suspension time.,
        [deleted_at] datetimeoffset(7) NULL -- Deletion/anonymization workflow start.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Member_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Member_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_Member_] PRIMARY KEY ([member_id])
    );
END;
GO

-- iam.MemberIdentity: Email/mobile/passwordless/Entra identity mapping.
IF OBJECT_ID(N'[iam].[MemberIdentity]', N'U') IS NULL
BEGIN
    CREATE TABLE [iam].[MemberIdentity] (
        [member_identity_id] bigint IDENTITY(1,1) NOT NULL -- Internal key.,
        [member_id] varchar(64) NOT NULL -- FK iam.Member.,
        [provider] varchar(32) NOT NULL -- EMAIL, PHONE, ENTRA or approved provider.,
        [provider_subject] nvarchar(320) NOT NULL -- Normalized email/mobile or external subject; encrypt/tokenize if required.,
        [is_primary] bit NOT NULL CONSTRAINT [DF_MemberIdentity_is_primary] DEFAULT (0) -- Primary sign-in identity flag.,
        [verified_at] datetimeoffset(7) NULL -- Verification completion.,
        [last_login_at] datetimeoffset(7) NULL -- Security/account support signal.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberIdentity_created_at] DEFAULT (SYSUTCDATETIME()) -- Creation time.,
        CONSTRAINT [PK_MemberIdentity_] PRIMARY KEY ([member_identity_id])
    );
END;
GO

-- iam.Role: Controlled role catalog for member and administrator authorization.
IF OBJECT_ID(N'[iam].[Role]', N'U') IS NULL
BEGIN
    CREATE TABLE [iam].[Role] (
        [role_code] varchar(64) NOT NULL -- MEMBER, ADMIN, MODERATOR, NLP_EVALUATOR.,
        [name] nvarchar(100) NOT NULL -- Display name.,
        [description] nvarchar(500) NULL -- Scope and intended use.,
        [is_privileged] bit NOT NULL CONSTRAINT [DF_Role_is_privileged] DEFAULT (0) -- Requires elevated authentication and audit.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Role_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Role_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_Role_] PRIMARY KEY ([role_code])
    );
END;
GO

-- iam.MemberRole: Role assignment with optional expiry.
IF OBJECT_ID(N'[iam].[MemberRole]', N'U') IS NULL
BEGIN
    CREATE TABLE [iam].[MemberRole] (
        [member_id] varchar(64) NOT NULL -- FK iam.Member.,
        [role_code] varchar(64) NOT NULL -- FK iam.Role.,
        [granted_by] varchar(64) NULL -- Administrator member ID.,
        [granted_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberRole_granted_at] DEFAULT (SYSUTCDATETIME()) -- Grant time.,
        [expires_at] datetimeoffset(7) NULL -- Optional expiry.,
        [revoked_at] datetimeoffset(7) NULL -- Revocation time.,
        CONSTRAINT [PK_MemberRole_] PRIMARY KEY ([member_id], [role_code])
    );
END;
GO

-- iam.MemberDevice: Registered mobile installation and security state.
IF OBJECT_ID(N'[iam].[MemberDevice]', N'U') IS NULL
BEGIN
    CREATE TABLE [iam].[MemberDevice] (
        [device_id] varchar(64) NOT NULL -- Client installation identifier, rotated on reinstall.,
        [member_id] varchar(64) NOT NULL -- FK iam.Member.,
        [platform] varchar(16) NOT NULL -- IOS or ANDROID.,
        [app_version] varchar(32) NOT NULL -- Last reported app version.,
        [status] varchar(20) NOT NULL CONSTRAINT [DF_MemberDevice_status] DEFAULT ('ACTIVE') -- ACTIVE or REVOKED.,
        [last_seen_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberDevice_last_seen_at] DEFAULT (SYSUTCDATETIME()) -- Last authenticated request.,
        [revoked_at] datetimeoffset(7) NULL -- Remote logout/device loss handling.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberDevice_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberDevice_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_MemberDevice_] PRIMARY KEY ([device_id])
    );
END;
GO

-- core.Organization: Professional organization represented in profiles.
IF OBJECT_ID(N'[core].[Organization]', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[Organization] (
        [organization_id] varchar(64) NOT NULL -- Stable identifier.,
        [community_id] varchar(64) NOT NULL -- FK core.Community.,
        [name] nvarchar(250) NOT NULL -- Canonical organization name.,
        [normalized_name] nvarchar(250) NOT NULL -- Search/deduplication form.,
        [website_domain] nvarchar(255) NULL -- Verified domain when available.,
        [industry_code] varchar(64) NULL -- Reference taxonomy.,
        [verification_status] varchar(24) NOT NULL CONSTRAINT [DF_Organization_verification_status] DEFAULT ('UNVERIFIED') -- UNVERIFIED, PENDING, VERIFIED, REJECTED.,
        [status] varchar(20) NOT NULL CONSTRAINT [DF_Organization_status] DEFAULT ('ACTIVE') -- Lifecycle state.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Organization_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Organization_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_Organization_] PRIMARY KEY ([organization_id])
    );
END;
GO

-- core.OrganizationMember: Member affiliation, title and organization-level role.
IF OBJECT_ID(N'[core].[OrganizationMember]', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[OrganizationMember] (
        [organization_member_id] bigint IDENTITY(1,1) NOT NULL -- Internal key.,
        [organization_id] varchar(64) NOT NULL -- FK core.Organization.,
        [member_id] varchar(64) NOT NULL -- FK iam.Member.,
        [job_title] nvarchar(200) NULL -- Professional title.,
        [department] nvarchar(150) NULL -- Optional function/department.,
        [is_primary] bit NOT NULL CONSTRAINT [DF_OrganizationMember_is_primary] DEFAULT (0) -- Primary current affiliation.,
        [started_on] date NULL -- Optional month/day precision per product policy.,
        [ended_on] date NULL -- Null for current affiliation.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_OrganizationMember_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_OrganizationMember_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_OrganizationMember_] PRIMARY KEY ([organization_member_id])
    );
END;
GO

-- core.MemberProfile: Searchable professional profile and visibility state.
IF OBJECT_ID(N'[core].[MemberProfile]', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[MemberProfile] (
        [member_id] varchar(64) NOT NULL -- One-to-one FK iam.Member.,
        [display_name] nvarchar(150) NOT NULL -- Member-facing name.,
        [headline] nvarchar(240) NULL -- Short professional headline.,
        [professional_summary] nvarchar(2000) NULL -- Member-authored summary.,
        [role_category] varchar(64) NULL -- Controlled role/function code.,
        [profile_status] varchar(24) NOT NULL CONSTRAINT [DF_MemberProfile_profile_status] DEFAULT ('DRAFT') -- DRAFT, PENDING_REVIEW, ACTIVE, HIDDEN.,
        [visibility] varchar(20) NOT NULL CONSTRAINT [DF_MemberProfile_visibility] DEFAULT ('MEMBERS') -- PRIVATE, MEMBERS or CONTEXT_ONLY.,
        [completeness_score] decimal(5,2) NOT NULL CONSTRAINT [DF_MemberProfile_completeness_score] DEFAULT (0) -- Derived profile completeness percentage.,
        [published_at] datetimeoffset(7) NULL -- First/current publication time.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberProfile_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberProfile_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_MemberProfile_] PRIMARY KEY ([member_id])
    );
END;
GO

-- core.Sector: Controlled sector/industry taxonomy.
IF OBJECT_ID(N'[core].[Sector]', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[Sector] (
        [sector_code] varchar(64) NOT NULL -- Stable taxonomy code.,
        [parent_sector_code] varchar(64) NULL -- Self-referencing hierarchy.,
        [name] nvarchar(150) NOT NULL -- Display label.,
        [status] varchar(16) NOT NULL CONSTRAINT [DF_Sector_status] DEFAULT ('ACTIVE') -- ACTIVE or RETIRED.,
        [sort_order] int NOT NULL CONSTRAINT [DF_Sector_sort_order] DEFAULT (0) -- Presentation order.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Sector_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Sector_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_Sector_] PRIMARY KEY ([sector_code])
    );
END;
GO

-- core.MemberSector: Many-to-many profile sector selection.
IF OBJECT_ID(N'[core].[MemberSector]', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[MemberSector] (
        [member_id] varchar(64) NOT NULL -- FK MemberProfile.,
        [sector_code] varchar(64) NOT NULL -- FK Sector.,
        [is_primary] bit NOT NULL CONSTRAINT [DF_MemberSector_is_primary] DEFAULT (0) -- Primary sector flag.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberSector_created_at] DEFAULT (SYSUTCDATETIME()) -- Assignment time.,
        CONSTRAINT [PK_MemberSector_] PRIMARY KEY ([member_id], [sector_code])
    );
END;
GO

-- core.MemberGeography: Member operating markets; not live location.
IF OBJECT_ID(N'[core].[MemberGeography]', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[MemberGeography] (
        [member_geography_id] bigint IDENTITY(1,1) NOT NULL -- Internal key.,
        [member_id] varchar(64) NOT NULL -- FK MemberProfile.,
        [country_code] char(2) NOT NULL -- ISO 3166-1 alpha-2.,
        [region] nvarchar(120) NULL -- State/region.,
        [city] nvarchar(120) NULL -- Operating city.,
        [is_primary] bit NOT NULL CONSTRAINT [DF_MemberGeography_is_primary] DEFAULT (0) -- Primary market.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberGeography_created_at] DEFAULT (SYSUTCDATETIME()) -- Creation time.,
        CONSTRAINT [PK_MemberGeography_] PRIMARY KEY ([member_geography_id])
    );
END;
GO

-- core.ProfileFieldVisibility: Per-field exposure before/after connection.
IF OBJECT_ID(N'[core].[ProfileFieldVisibility]', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[ProfileFieldVisibility] (
        [member_id] varchar(64) NOT NULL -- FK MemberProfile.,
        [field_code] varchar(64) NOT NULL -- PROFILE_SUMMARY, ORGANIZATION, GEOGRAPHY, etc.,
        [audience] varchar(24) NOT NULL CONSTRAINT [DF_ProfileFieldVisibility_audience] DEFAULT ('CONNECTED') -- PRIVATE, MATCHED, CONNECTED, MEMBERS.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_ProfileFieldVisibility_updated_at] DEFAULT (SYSUTCDATETIME()) -- Last preference change.,
        [row_version] rowversion NOT NULL -- Concurrency token.,
        CONSTRAINT [PK_ProfileFieldVisibility_] PRIMARY KEY ([member_id], [field_code])
    );
END;
GO

-- core.MemberVerification: Administrator/member verification workflow.
IF OBJECT_ID(N'[core].[MemberVerification]', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[MemberVerification] (
        [verification_id] varchar(64) NOT NULL -- Case identifier.,
        [member_id] varchar(64) NOT NULL -- FK iam.Member.,
        [verification_type] varchar(32) NOT NULL -- EMAIL, PHONE, ORGANIZATION or MANUAL.,
        [status] varchar(24) NOT NULL CONSTRAINT [DF_MemberVerification_status] DEFAULT ('PENDING') -- PENDING, APPROVED, REJECTED, EXPIRED.,
        [evidence_attachment_id] varchar(64) NULL -- Private attachment reference, if policy permits.,
        [reviewed_by] varchar(64) NULL -- Administrator member ID.,
        [reviewed_at] datetimeoffset(7) NULL -- Review completion.,
        [reason_code] varchar(64) NULL -- Controlled result reason.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberVerification_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberVerification_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_MemberVerification_] PRIMARY KEY ([verification_id])
    );
END;
GO

-- consent.ConsentPolicy: Versioned consent purpose and legal/community text.
IF OBJECT_ID(N'[consent].[ConsentPolicy]', N'U') IS NULL
BEGIN
    CREATE TABLE [consent].[ConsentPolicy] (
        [policy_id] varchar(64) NOT NULL -- Stable policy version ID.,
        [purpose_code] varchar(64) NOT NULL -- TERMS, LOCATION, LIVE_MODE, NOTIFICATIONS, ANALYTICS.,
        [version] varchar(32) NOT NULL -- Human-readable version.,
        [locale] varchar(16) NOT NULL CONSTRAINT [DF_ConsentPolicy_locale] DEFAULT ('en') -- Text locale.,
        [content_hash] char(64) NOT NULL -- SHA-256 of presented content.,
        [effective_from] datetimeoffset(7) NOT NULL -- Activation time.,
        [retired_at] datetimeoffset(7) NULL -- Retirement time.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_ConsentPolicy_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_ConsentPolicy_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_ConsentPolicy_] PRIMARY KEY ([policy_id])
    );
END;
GO

-- consent.MemberConsent: Authoritative grant/withdrawal evidence by purpose.
IF OBJECT_ID(N'[consent].[MemberConsent]', N'U') IS NULL
BEGIN
    CREATE TABLE [consent].[MemberConsent] (
        [member_consent_id] bigint IDENTITY(1,1) NOT NULL -- Evidence record.,
        [member_id] varchar(64) NOT NULL -- FK iam.Member.,
        [policy_id] varchar(64) NOT NULL -- FK ConsentPolicy.,
        [decision] varchar(16) NOT NULL -- GRANTED or DENIED.,
        [captured_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberConsent_captured_at] DEFAULT (SYSUTCDATETIME()) -- Decision time.,
        [withdrawn_at] datetimeoffset(7) NULL -- Withdrawal time.,
        [capture_channel] varchar(24) NOT NULL -- MOBILE, WEB_ADMIN or SUPPORT.,
        [evidence_json] nvarchar(1000) NULL -- Bounded device/app/version evidence; no secrets.,
        CONSTRAINT [PK_MemberConsent_] PRIMARY KEY ([member_consent_id])
    );
END;
GO

-- consent.PrivacyRequest: Member data access, correction, deletion or consent-support case.
IF OBJECT_ID(N'[consent].[PrivacyRequest]', N'U') IS NULL
BEGIN
    CREATE TABLE [consent].[PrivacyRequest] (
        [privacy_request_id] varchar(64) NOT NULL -- Case identifier.,
        [member_id] varchar(64) NOT NULL -- Requesting member.,
        [request_type] varchar(24) NOT NULL -- ACCESS, CORRECT, DELETE, EXPORT, CONSENT_SUPPORT.,
        [status] varchar(24) NOT NULL CONSTRAINT [DF_PrivacyRequest_status] DEFAULT ('OPEN') -- OPEN, VERIFIED, PROCESSING, COMPLETED, REJECTED.,
        [verified_at] datetimeoffset(7) NULL -- Identity verification.,
        [due_at] datetimeoffset(7) NULL -- Policy deadline.,
        [completed_at] datetimeoffset(7) NULL -- Completion time.,
        [result_attachment_id] varchar(64) NULL -- Private export package reference.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_PrivacyRequest_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_PrivacyRequest_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_PrivacyRequest_] PRIMARY KEY ([privacy_request_id])
    );
END;
GO

-- event.Venue: Admin-configured venue and coarse proximity boundary.
IF OBJECT_ID(N'[event].[Venue]', N'U') IS NULL
BEGIN
    CREATE TABLE [event].[Venue] (
        [venue_id] varchar(64) NOT NULL -- Venue identifier.,
        [name] nvarchar(200) NOT NULL -- Venue name.,
        [country_code] char(2) NOT NULL -- ISO country.,
        [region] nvarchar(120) NULL -- Region/state.,
        [city] nvarchar(120) NULL -- City.,
        [coarse_geo_cell] varchar(32) NULL -- Venue-level geohash/H3 cell; not member location.,
        [timezone_id] varchar(64) NOT NULL -- IANA/Windows mapping controlled by service.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Venue_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Venue_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_Venue_] PRIMARY KEY ([venue_id])
    );
END;
GO

-- event.Event: Event/context used for registration, Live Mode and matching.
IF OBJECT_ID(N'[event].[Event]', N'U') IS NULL
BEGIN
    CREATE TABLE [event].[Event] (
        [event_id] varchar(64) NOT NULL -- Also used as matching context_id.,
        [community_id] varchar(64) NOT NULL -- FK Community.,
        [venue_id] varchar(64) NULL -- FK Venue.,
        [name] nvarchar(250) NOT NULL -- Event name.,
        [description] nvarchar(2000) NULL -- Admin-managed description.,
        [starts_at] datetimeoffset(7) NOT NULL -- UTC start.,
        [ends_at] datetimeoffset(7) NOT NULL -- UTC end.,
        [status] varchar(24) NOT NULL CONSTRAINT [DF_Event_status] DEFAULT ('DRAFT') -- DRAFT, PUBLISHED, ACTIVE, COMPLETED, CANCELLED.,
        [live_mode_enabled] bit NOT NULL CONSTRAINT [DF_Event_live_mode_enabled] DEFAULT (0) -- Event allows Live Mode.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Event_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Event_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_Event_] PRIMARY KEY ([event_id])
    );
END;
GO

-- event.EventMatchingPolicy: Versioned event-level eligibility, proximity, ranking and match-alert controls.
IF OBJECT_ID(N'[event].[EventMatchingPolicy]', N'U') IS NULL
BEGIN
    CREATE TABLE [event].[EventMatchingPolicy] (
        [event_matching_policy_id] bigint IDENTITY(1,1) NOT NULL -- Immutable policy version identifier.,
        [event_id] varchar(64) NOT NULL -- FK Event; policy applies only to this event/context.,
        [policy_version] smallint NOT NULL CONSTRAINT [DF_EventMatchingPolicy_policy_version] DEFAULT (1) -- Monotonic version within the event.,
        [status] varchar(16) NOT NULL CONSTRAINT [DF_EventMatchingPolicy_status] DEFAULT ('DRAFT') -- DRAFT, ACTIVE or RETIRED.,
        [registration_required] bit NOT NULL CONSTRAINT [DF_EventMatchingPolicy_registration_required] DEFAULT (1) -- Member must hold an eligible EventRegistration.,
        [check_in_required] bit NOT NULL CONSTRAINT [DF_EventMatchingPolicy_check_in_required] DEFAULT (0) -- Member must be checked in before event matching.,
        [live_mode_required] bit NOT NULL CONSTRAINT [DF_EventMatchingPolicy_live_mode_required] DEFAULT (1) -- Active consent-backed LiveModeSession required.,
        [proximity_mode] varchar(24) NOT NULL CONSTRAINT [DF_EventMatchingPolicy_proximity_mode] DEFAULT ('VENUE') -- NONE, VENUE or COARSE_CELL.,
        [max_presence_age_minutes] smallint NULL CONSTRAINT [DF_EventMatchingPolicy_max_presence_age_minutes] DEFAULT (15) -- Maximum age of coarse presence when proximity is used.,
        [match_threshold_override] decimal(6,5) NULL -- Optional override of active NLP ranking threshold.,
        [alert_confidence_threshold] decimal(6,5) NOT NULL CONSTRAINT [DF_EventMatchingPolicy_alert_confidence_threshold] DEFAULT (0.70) -- Minimum final score before a proactive match alert is eligible.,
        [max_match_alerts_per_hour] smallint NOT NULL CONSTRAINT [DF_EventMatchingPolicy_max_match_alerts_per_hour] DEFAULT (2) -- Event-specific hourly cap per member.,
        [max_match_alerts_per_event] smallint NOT NULL CONSTRAINT [DF_EventMatchingPolicy_max_match_alerts_per_event] DEFAULT (10) -- Event-lifetime cap per member.,
        [minimum_alert_interval_minutes] smallint NOT NULL CONSTRAINT [DF_EventMatchingPolicy_minimum_alert_interval_minutes] DEFAULT (30) -- Minimum spacing between event match alerts.,
        [effective_from] datetimeoffset(7) NOT NULL -- Start of policy applicability.,
        [effective_to] datetimeoffset(7) NULL -- Optional retirement time.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_EventMatchingPolicy_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_EventMatchingPolicy_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_EventMatchingPolicy_] PRIMARY KEY ([event_matching_policy_id])
    );
END;
GO

-- event.EventRegistration: Member eligibility/check-in relationship to an event.
IF OBJECT_ID(N'[event].[EventRegistration]', N'U') IS NULL
BEGIN
    CREATE TABLE [event].[EventRegistration] (
        [event_registration_id] bigint IDENTITY(1,1) NOT NULL -- Internal key.,
        [event_id] varchar(64) NOT NULL -- FK Event.,
        [member_id] varchar(64) NOT NULL -- FK Member.,
        [status] varchar(24) NOT NULL CONSTRAINT [DF_EventRegistration_status] DEFAULT ('REGISTERED') -- INVITED, REGISTERED, CHECKED_IN, CANCELLED.,
        [registered_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_EventRegistration_registered_at] DEFAULT (SYSUTCDATETIME()) -- Registration time.,
        [checked_in_at] datetimeoffset(7) NULL -- Event check-in time.,
        [source] varchar(24) NOT NULL CONSTRAINT [DF_EventRegistration_source] DEFAULT ('APP') -- APP, ADMIN, IMPORT.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_EventRegistration_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_EventRegistration_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_EventRegistration_] PRIMARY KEY ([event_registration_id])
    );
END;
GO

-- event.LiveModeSession: Bounded, revocable member discovery session.
IF OBJECT_ID(N'[event].[LiveModeSession]', N'U') IS NULL
BEGIN
    CREATE TABLE [event].[LiveModeSession] (
        [live_session_id] varchar(64) NOT NULL -- Session identifier.,
        [event_id] varchar(64) NOT NULL -- FK Event.,
        [member_id] varchar(64) NOT NULL -- FK Member.,
        [consent_record_id] bigint NOT NULL -- Valid Live Mode consent evidence.,
        [status] varchar(16) NOT NULL CONSTRAINT [DF_LiveModeSession_status] DEFAULT ('ACTIVE') -- ACTIVE, DISABLED, EXPIRED.,
        [activated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_LiveModeSession_activated_at] DEFAULT (SYSUTCDATETIME()) -- Activation time.,
        [active_until] datetimeoffset(7) NOT NULL -- Hard expiry bounded by event.,
        [disabled_at] datetimeoffset(7) NULL -- Immediate revocation time.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_LiveModeSession_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_LiveModeSession_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_LiveModeSession_] PRIMARY KEY ([live_session_id])
    );
END;
GO

-- event.EventPresence: Coarse, short-lived evidence used for nearby matching.
IF OBJECT_ID(N'[event].[EventPresence]', N'U') IS NULL
BEGIN
    CREATE TABLE [event].[EventPresence] (
        [presence_id] bigint IDENTITY(1,1) NOT NULL -- Internal key.,
        [live_session_id] varchar(64) NOT NULL -- FK LiveModeSession.,
        [coarse_cell] varchar(32) NOT NULL -- Approved coarse geohash/H3 cell.,
        [observed_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_EventPresence_observed_at] DEFAULT (SYSUTCDATETIME()) -- Observation time.,
        [expires_at] datetimeoffset(7) NOT NULL -- Automatic purge time.,
        [source] varchar(24) NOT NULL -- CHECK_IN, FOREGROUND_GEO or VENUE_ZONE.,
        CONSTRAINT [PK_EventPresence_] PRIMARY KEY ([presence_id])
    );
END;
GO

-- social.ConnectionRequest: Consent gate before creating a connection/chat.
IF OBJECT_ID(N'[social].[ConnectionRequest]', N'U') IS NULL
BEGIN
    CREATE TABLE [social].[ConnectionRequest] (
        [connection_request_id] varchar(64) NOT NULL -- Request identifier.,
        [sender_member_id] varchar(64) NOT NULL -- Requester.,
        [recipient_member_id] varchar(64) NOT NULL -- Recipient.,
        [context_id] varchar(64) NULL -- Event or general matching context.,
        [match_result_id] bigint NULL -- Recommendation that led to request.,
        [note] nvarchar(500) NULL -- Optional introduction note; moderate as content.,
        [status] varchar(24) NOT NULL CONSTRAINT [DF_ConnectionRequest_status] DEFAULT ('PENDING') -- PENDING, ACCEPTED, DECLINED, WITHDRAWN, EXPIRED.,
        [expires_at] datetimeoffset(7) NOT NULL -- Policy-calculated expiry for a pending request.,
        [responded_at] datetimeoffset(7) NULL -- Terminal response time.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_ConnectionRequest_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_ConnectionRequest_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_ConnectionRequest_] PRIMARY KEY ([connection_request_id])
    );
END;
GO

-- social.Connection: Mutually accepted member relationship.
IF OBJECT_ID(N'[social].[Connection]', N'U') IS NULL
BEGIN
    CREATE TABLE [social].[Connection] (
        [connection_id] varchar(64) NOT NULL -- Connection identifier.,
        [member_low_id] varchar(64) NOT NULL -- Lexicographically lower member ID.,
        [member_high_id] varchar(64) NOT NULL -- Lexicographically higher member ID.,
        [accepted_request_id] varchar(64) NOT NULL -- Accepted ConnectionRequest.,
        [status] varchar(20) NOT NULL CONSTRAINT [DF_Connection_status] DEFAULT ('ACTIVE') -- ACTIVE or DISCONNECTED.,
        [connected_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Connection_connected_at] DEFAULT (SYSUTCDATETIME()) -- Acceptance time.,
        [disconnected_at] datetimeoffset(7) NULL -- Relationship end.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Connection_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Connection_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_Connection_] PRIMARY KEY ([connection_id])
    );
END;
GO

-- social.MemberBlock: Directional block that suppresses discovery and communication both ways.
IF OBJECT_ID(N'[social].[MemberBlock]', N'U') IS NULL
BEGIN
    CREATE TABLE [social].[MemberBlock] (
        [block_id] bigint IDENTITY(1,1) NOT NULL -- Internal key.,
        [blocker_member_id] varchar(64) NOT NULL -- Member initiating block.,
        [blocked_member_id] varchar(64) NOT NULL -- Blocked member.,
        [reason_code] varchar(64) NULL -- Private controlled reason.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberBlock_created_at] DEFAULT (SYSUTCDATETIME()) -- Effective immediately.,
        [removed_at] datetimeoffset(7) NULL -- Optional unblock.,
        CONSTRAINT [PK_MemberBlock_] PRIMARY KEY ([block_id])
    );
END;
GO

-- social.MemberReport: Member-submitted safety/report workflow trigger.
IF OBJECT_ID(N'[social].[MemberReport]', N'U') IS NULL
BEGIN
    CREATE TABLE [social].[MemberReport] (
        [report_id] varchar(64) NOT NULL -- Report identifier.,
        [reporter_member_id] varchar(64) NOT NULL -- Reporter.,
        [reported_member_id] varchar(64) NOT NULL -- Subject.,
        [resource_type] varchar(32) NULL -- PROFILE, REQUEST, MESSAGE, ATTACHMENT.,
        [resource_id] varchar(64) NULL -- Reported object.,
        [category] varchar(64) NOT NULL -- Controlled report category.,
        [description] nvarchar(2000) NULL -- Reporter description.,
        [status] varchar(24) NOT NULL CONSTRAINT [DF_MemberReport_status] DEFAULT ('OPEN') -- OPEN, TRIAGED, RESOLVED, DISMISSED.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberReport_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberReport_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_MemberReport_] PRIMARY KEY ([report_id])
    );
END;
GO

-- chat.Conversation: Accepted-connection one-to-one chat container.
IF OBJECT_ID(N'[chat].[Conversation]', N'U') IS NULL
BEGIN
    CREATE TABLE [chat].[Conversation] (
        [conversation_id] varchar(64) NOT NULL -- Conversation identifier.,
        [connection_id] varchar(64) NOT NULL -- One conversation per accepted connection.,
        [status] varchar(20) NOT NULL CONSTRAINT [DF_Conversation_status] DEFAULT ('ACTIVE') -- ACTIVE, CLOSED, RESTRICTED.,
        [last_message_at] datetimeoffset(7) NULL -- Conversation list ordering.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Conversation_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Conversation_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_Conversation_] PRIMARY KEY ([conversation_id])
    );
END;
GO

-- chat.ConversationParticipant: Per-member chat state and authorization projection.
IF OBJECT_ID(N'[chat].[ConversationParticipant]', N'U') IS NULL
BEGIN
    CREATE TABLE [chat].[ConversationParticipant] (
        [conversation_id] varchar(64) NOT NULL -- FK Conversation.,
        [member_id] varchar(64) NOT NULL -- Participant.,
        [joined_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_ConversationParticipant_joined_at] DEFAULT (SYSUTCDATETIME()) -- Participation start.,
        [last_read_message_id] varchar(64) NULL -- Read cursor.,
        [muted_until] datetimeoffset(7) NULL -- Notification suppression.,
        [left_at] datetimeoffset(7) NULL -- Closure/disconnect projection.,
        CONSTRAINT [PK_ConversationParticipant_] PRIMARY KEY ([conversation_id], [member_id])
    );
END;
GO

-- chat.Message: Durable one-to-one message.
IF OBJECT_ID(N'[chat].[Message]', N'U') IS NULL
BEGIN
    CREATE TABLE [chat].[Message] (
        [message_id] varchar(64) NOT NULL -- Client-generated ID supports idempotency.,
        [conversation_id] varchar(64) NOT NULL -- FK Conversation.,
        [sender_member_id] varchar(64) NOT NULL -- Authorized participant.,
        [message_type] varchar(20) NOT NULL CONSTRAINT [DF_Message_message_type] DEFAULT ('TEXT') -- TEXT, FILE, SYSTEM.,
        [body] nvarchar(max) NULL -- Text content; sanitize for display.,
        [client_sent_at] datetimeoffset(7) NULL -- Client timestamp for UX only.,
        [server_sequence] bigint NOT NULL CONSTRAINT [DF_Message_server_sequence] DEFAULT (NEXT VALUE FOR chat.MessageSequence) -- Monotonic per conversation or global stream.,
        [moderation_status] varchar(24) NOT NULL CONSTRAINT [DF_Message_moderation_status] DEFAULT ('PENDING_OR_CLEAR') -- Safety state.,
        [deleted_at] datetimeoffset(7) NULL -- Logical removal time.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Message_created_at] DEFAULT (SYSUTCDATETIME()) -- Authoritative send time.,
        [row_version] rowversion NOT NULL -- Concurrency token.,
        CONSTRAINT [PK_Message_] PRIMARY KEY ([message_id])
    );
END;
GO

-- chat.Attachment: Blob metadata and malware-scan lifecycle.
IF OBJECT_ID(N'[chat].[Attachment]', N'U') IS NULL
BEGIN
    CREATE TABLE [chat].[Attachment] (
        [attachment_id] varchar(64) NOT NULL -- Attachment identifier.,
        [message_id] varchar(64) NULL -- Message after finalize; null during upload.,
        [owner_member_id] varchar(64) NOT NULL -- Uploader.,
        [blob_path] nvarchar(1024) NOT NULL -- Private container path; never store SAS URL.,
        [file_name] nvarchar(255) NOT NULL -- Sanitized display name.,
        [media_type] varchar(128) NOT NULL -- Verified MIME type.,
        [size_bytes] bigint NOT NULL -- Validated size.,
        [sha256] char(64) NOT NULL -- Integrity/deduplication hash.,
        [scan_status] varchar(24) NOT NULL CONSTRAINT [DF_Attachment_scan_status] DEFAULT ('PENDING') -- PENDING, CLEAN, REJECTED, ERROR.,
        [expires_at] datetimeoffset(7) NULL -- Orphan/temp purge time.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Attachment_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Attachment_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        [blob_path_hash] char(64) NOT NULL -- Stable SHA-256 hash supplied by the service to enforce blob-path uniqueness within Azure SQL index limits.,
        CONSTRAINT [PK_Attachment_] PRIMARY KEY ([attachment_id])
    );
END;
GO

-- chat.MessageReceipt: Message delivered/read evidence by participant.
IF OBJECT_ID(N'[chat].[MessageReceipt]', N'U') IS NULL
BEGIN
    CREATE TABLE [chat].[MessageReceipt] (
        [message_id] varchar(64) NOT NULL -- FK Message.,
        [member_id] varchar(64) NOT NULL -- Recipient participant.,
        [delivered_at] datetimeoffset(7) NULL -- First delivery.,
        [read_at] datetimeoffset(7) NULL -- First read.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MessageReceipt_updated_at] DEFAULT (SYSUTCDATETIME()) -- Last receipt update.,
        CONSTRAINT [PK_MessageReceipt_] PRIMARY KEY ([message_id], [member_id])
    );
END;
GO

-- notification.NotificationPolicy: Versioned channel, frequency, quiet-hours, retry and expiry controls by notification purpose.
IF OBJECT_ID(N'[notification].[NotificationPolicy]', N'U') IS NULL
BEGIN
    CREATE TABLE [notification].[NotificationPolicy] (
        [notification_policy_id] bigint IDENTITY(1,1) NOT NULL -- Immutable policy version identifier.,
        [community_id] varchar(64) NULL -- Optional community scope; null is platform default.,
        [purpose_code] varchar(64) NOT NULL -- MATCH, REQUEST, CHAT, EVENT, SAFETY or ACCOUNT.,
        [channel] varchar(16) NOT NULL -- PUSH, EMAIL or IN_APP.,
        [policy_version] smallint NOT NULL CONSTRAINT [DF_NotificationPolicy_policy_version] DEFAULT (1) -- Monotonic version for scope/purpose/channel.,
        [status] varchar(16) NOT NULL CONSTRAINT [DF_NotificationPolicy_status] DEFAULT ('DRAFT') -- DRAFT, ACTIVE or RETIRED.,
        [member_opt_out_allowed] bit NOT NULL CONSTRAINT [DF_NotificationPolicy_member_opt_out_allowed] DEFAULT (1) -- Whether member preference may disable this notification.,
        [quiet_hours_behavior] varchar(16) NOT NULL CONSTRAINT [DF_NotificationPolicy_quiet_hours_behavior] DEFAULT ('DEFER') -- DEFER, SUPPRESS or BYPASS.,
        [dedupe_window_seconds] int NOT NULL CONSTRAINT [DF_NotificationPolicy_dedupe_window_seconds] DEFAULT (300) -- Duplicate suppression window for the same dedupe key.,
        [max_per_hour] smallint NOT NULL CONSTRAINT [DF_NotificationPolicy_max_per_hour] DEFAULT (6) -- Maximum queued/sent notifications per member and policy each hour.,
        [max_per_day] smallint NOT NULL CONSTRAINT [DF_NotificationPolicy_max_per_day] DEFAULT (30) -- Maximum queued/sent notifications per member and policy each day.,
        [max_attempts] smallint NOT NULL CONSTRAINT [DF_NotificationPolicy_max_attempts] DEFAULT (3) -- Bounded provider delivery attempts.,
        [retry_schedule_seconds] varchar(128) NOT NULL CONSTRAINT [DF_NotificationPolicy_retry_schedule_seconds] DEFAULT ('60,300,1800') -- Validated comma-separated retry delays.,
        [ttl_minutes] int NOT NULL CONSTRAINT [DF_NotificationPolicy_ttl_minutes] DEFAULT (1440) -- Notification expiry after initial eligibility.,
        [effective_from] datetimeoffset(7) NOT NULL -- Start of policy applicability.,
        [effective_to] datetimeoffset(7) NULL -- Optional retirement time.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NotificationPolicy_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NotificationPolicy_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_NotificationPolicy_] PRIMARY KEY ([notification_policy_id])
    );
END;
GO

-- notification.NotificationPreference: Member channel, quiet hours and purpose preferences.
IF OBJECT_ID(N'[notification].[NotificationPreference]', N'U') IS NULL
BEGIN
    CREATE TABLE [notification].[NotificationPreference] (
        [member_id] varchar(64) NOT NULL -- FK Member.,
        [purpose_code] varchar(64) NOT NULL -- MATCH, REQUEST, CHAT, EVENT, SAFETY or ACCOUNT.,
        [push_enabled] bit NOT NULL CONSTRAINT [DF_NotificationPreference_push_enabled] DEFAULT (1) -- Push channel preference.,
        [email_enabled] bit NOT NULL CONSTRAINT [DF_NotificationPreference_email_enabled] DEFAULT (0) -- Email channel preference.,
        [quiet_start_local] time NULL -- Optional local quiet start.,
        [quiet_end_local] time NULL -- Optional local quiet end.,
        [timezone_id] varchar(64) NULL -- Required when quiet hours set.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NotificationPreference_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NotificationPreference_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_NotificationPreference_] PRIMARY KEY ([member_id], [purpose_code])
    );
END;
GO

-- notification.PushToken: Provider push token mapped to a registered device.
IF OBJECT_ID(N'[notification].[PushToken]', N'U') IS NULL
BEGIN
    CREATE TABLE [notification].[PushToken] (
        [push_token_id] bigint IDENTITY(1,1) NOT NULL -- Internal key.,
        [device_id] varchar(64) NOT NULL -- FK MemberDevice.,
        [provider] varchar(24) NOT NULL -- APNS or FCM.,
        [token_ciphertext] varbinary(max) NOT NULL -- Encrypted/tokenized push token.,
        [status] varchar(16) NOT NULL CONSTRAINT [DF_PushToken_status] DEFAULT ('ACTIVE') -- ACTIVE or INVALID.,
        [last_success_at] datetimeoffset(7) NULL -- Last accepted delivery.,
        [invalidated_at] datetimeoffset(7) NULL -- Provider rejection/revocation.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_PushToken_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_PushToken_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        [token_fingerprint] char(64) NOT NULL -- Stable SHA-256 fingerprint supplied by the service for uniqueness without indexing ciphertext.,
        CONSTRAINT [PK_PushToken_] PRIMARY KEY ([push_token_id])
    );
END;
GO

-- notification.Notification: Policy-resolved, rate-limited delivery intent and aggregate outcome.
IF OBJECT_ID(N'[notification].[Notification]', N'U') IS NULL
BEGIN
    CREATE TABLE [notification].[Notification] (
        [notification_id] varchar(64) NOT NULL -- Delivery identifier.,
        [member_id] varchar(64) NOT NULL -- Recipient.,
        [notification_policy_id] bigint NOT NULL -- Immutable NotificationPolicy version applied.,
        [event_matching_policy_id] bigint NULL -- EventMatchingPolicy applied to an event match alert.,
        [purpose_code] varchar(64) NOT NULL -- Notification purpose.,
        [channel] varchar(16) NOT NULL -- Resolved PUSH, EMAIL or IN_APP channel.,
        [resource_type] varchar(32) NULL -- MATCH, REQUEST, MESSAGE, EVENT.,
        [resource_id] varchar(64) NULL -- Deep-link resource.,
        [template_code] varchar(64) NOT NULL -- Versioned content template.,
        [dedupe_key] varchar(160) NOT NULL -- Stable purpose/member/resource key used for duplicate suppression.,
        [dedupe_bucket_start] datetimeoffset(7) NOT NULL -- Start of the policy-derived deduplication window.,
        [source_confidence] decimal(6,5) NULL -- Match confidence captured when threshold-based notification is used.,
        [context_id] varchar(64) NULL -- Event ID or GENERAL context used for event-lifetime caps.,
        [status] varchar(20) NOT NULL CONSTRAINT [DF_Notification_status] DEFAULT ('PENDING') -- PENDING, SENT, DELIVERED, FAILED, SUPPRESSED.,
        [scheduled_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Notification_scheduled_at] DEFAULT (SYSUTCDATETIME()) -- Quiet-hours-aware schedule.,
        [expires_at] datetimeoffset(7) NOT NULL -- Policy-calculated time after which delivery is suppressed.,
        [attempt_count] smallint NOT NULL CONSTRAINT [DF_Notification_attempt_count] DEFAULT (0) -- Aggregate count of append-only delivery attempts.,
        [sent_at] datetimeoffset(7) NULL -- Provider acceptance time.,
        [delivered_at] datetimeoffset(7) NULL -- Provider delivery acknowledgment when available.,
        [suppression_reason] varchar(64) NULL -- OPT_OUT, QUIET_HOURS, RATE_LIMIT, DUPLICATE, EXPIRED, BELOW_THRESHOLD or POLICY.,
        [failure_code] varchar(64) NULL -- Sanitized provider failure.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Notification_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Notification_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_Notification_] PRIMARY KEY ([notification_id])
    );
END;
GO

-- notification.NotificationDeliveryAttempt: Append-only provider attempt and acknowledgment history.
IF OBJECT_ID(N'[notification].[NotificationDeliveryAttempt]', N'U') IS NULL
BEGIN
    CREATE TABLE [notification].[NotificationDeliveryAttempt] (
        [delivery_attempt_id] bigint IDENTITY(1,1) NOT NULL -- Attempt identifier.,
        [notification_id] varchar(64) NOT NULL -- FK Notification.,
        [attempt_number] smallint NOT NULL -- One-based attempt number.,
        [provider] varchar(32) NOT NULL -- APNS, FCM, EMAIL_PROVIDER or IN_APP.,
        [push_token_id] bigint NULL -- PushToken used; null for non-push channels.,
        [provider_message_id] nvarchar(256) NULL -- Provider correlation ID; never a credential.,
        [status] varchar(20) NOT NULL CONSTRAINT [DF_NotificationDeliveryAttempt_status] DEFAULT ('STARTED') -- STARTED, ACCEPTED, DELIVERED, FAILED or EXPIRED.,
        [attempted_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NotificationDeliveryAttempt_attempted_at] DEFAULT (SYSUTCDATETIME()) -- Attempt start time.,
        [acknowledged_at] datetimeoffset(7) NULL -- Provider acknowledgment time.,
        [next_attempt_at] datetimeoffset(7) NULL -- Next policy-derived retry time.,
        [duration_ms] int NULL -- Provider request duration.,
        [failure_code] varchar(64) NULL -- Sanitized failure category.,
        CONSTRAINT [PK_NotificationDeliveryAttempt_] PRIMARY KEY ([delivery_attempt_id])
    );
END;
GO

-- nlp.NlpIntent: Current WANT/OFFER text and structured matching metadata.
IF OBJECT_ID(N'[nlp].[NlpIntent]', N'U') IS NULL
BEGIN
    CREATE TABLE [nlp].[NlpIntent] (
        [intent_id] varchar(64) NOT NULL -- Matches existing API contract.,
        [member_id] varchar(64) NOT NULL -- Authoritative FK iam.Member.,
        [context_id] varchar(64) NOT NULL -- Event ID or GENERAL context.,
        [intent_type] varchar(16) NOT NULL -- WANT or OFFER.,
        [original_text] nvarchar(4000) NOT NULL -- Member-authored display text.,
        [normalized_text] nvarchar(4000) NOT NULL -- PII-minimized normalization.,
        [normalized_hash] char(64) NOT NULL -- Content hash for idempotent embedding.,
        [language_code] varchar(16) NOT NULL CONSTRAINT [DF_NlpIntent_language_code] DEFAULT ('en') -- Detected/approved language.,
        [contains_pii] bit NOT NULL CONSTRAINT [DF_NlpIntent_contains_pii] DEFAULT (0) -- Preprocessing signal.,
        [status] varchar(32) NOT NULL CONSTRAINT [DF_NlpIntent_status] DEFAULT ('PROCESSING') -- PROCESSING, MATCH_READY, FAILED, INACTIVE.,
        [category] nvarchar(128) NULL -- Structured category.,
        [industry] nvarchar(128) NULL -- Structured industry.,
        [geography] nvarchar(128) NULL -- Business geography, not live location.,
        [expires_at] datetimeoffset(7) NOT NULL -- Freshness/eligibility expiry.,
        [preprocessing_version] varchar(128) NOT NULL -- Normalizer version.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NlpIntent_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NlpIntent_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_NlpIntent_] PRIMARY KEY ([intent_id])
    );
END;
GO

-- nlp.NlpEmbedding: Versioned vector for a normalized intent.
IF OBJECT_ID(N'[nlp].[NlpEmbedding]', N'U') IS NULL
BEGIN
    CREATE TABLE [nlp].[NlpEmbedding] (
        [intent_id] varchar(64) NOT NULL -- FK NlpIntent.,
        [model_version] varchar(128) NOT NULL -- FK NlpModelVersion.,
        [dimensions] int NOT NULL -- Vector dimensions.,
        [normalized_hash] char(64) NOT NULL -- Text version embedded.,
        [embedding] varbinary(max) NOT NULL -- Existing varbinary baseline; native vector after target validation.,
        [status] varchar(20) NOT NULL CONSTRAINT [DF_NlpEmbedding_status] DEFAULT ('ACTIVE') -- ACTIVE, SUPERSEDED, FAILED.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NlpEmbedding_created_at] DEFAULT (SYSUTCDATETIME()) -- Creation time.,
        CONSTRAINT [PK_NlpEmbedding_] PRIMARY KEY ([intent_id], [model_version])
    );
END;
GO

-- nlp.NlpModelVersion: Embedding provider/deployment and preprocessing compatibility.
IF OBJECT_ID(N'[nlp].[NlpModelVersion]', N'U') IS NULL
BEGIN
    CREATE TABLE [nlp].[NlpModelVersion] (
        [model_version] varchar(128) NOT NULL -- Stable version.,
        [provider] varchar(64) NOT NULL -- Approved provider.,
        [deployment_name] varchar(128) NOT NULL -- Configuration reference, not secret.,
        [dimensions] int NOT NULL -- Expected vector length.,
        [preprocessing_version] varchar(128) NOT NULL -- Compatible preprocessing.,
        [status] varchar(20) NOT NULL CONSTRAINT [DF_NlpModelVersion_status] DEFAULT ('CANDIDATE') -- CANDIDATE, ACTIVE, RETIRED, ROLLED_BACK.,
        [activated_at] datetimeoffset(7) NULL -- Promotion time.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NlpModelVersion_created_at] DEFAULT (SYSUTCDATETIME()) -- Registration time.,
        CONSTRAINT [PK_NlpModelVersion_] PRIMARY KEY ([model_version])
    );
END;
GO

-- nlp.NlpRankingConfig: Versioned ranking weights, threshold and policy switches.
IF OBJECT_ID(N'[nlp].[NlpRankingConfig]', N'U') IS NULL
BEGIN
    CREATE TABLE [nlp].[NlpRankingConfig] (
        [ranking_version] varchar(128) NOT NULL -- Stable configuration version.,
        [semantic_weight] decimal(6,5) NOT NULL CONSTRAINT [DF_NlpRankingConfig_semantic_weight] DEFAULT (0.40) -- Semantic/reciprocal weight.,
        [category_weight] decimal(6,5) NOT NULL CONSTRAINT [DF_NlpRankingConfig_category_weight] DEFAULT (0.25) -- Category compatibility.,
        [industry_weight] decimal(6,5) NOT NULL CONSTRAINT [DF_NlpRankingConfig_industry_weight] DEFAULT (0.15) -- Industry compatibility.,
        [geography_weight] decimal(6,5) NOT NULL CONSTRAINT [DF_NlpRankingConfig_geography_weight] DEFAULT (0.10) -- Business geography fit.,
        [freshness_weight] decimal(6,5) NOT NULL CONSTRAINT [DF_NlpRankingConfig_freshness_weight] DEFAULT (0.10) -- Intent freshness.,
        [event_weight] decimal(6,5) NOT NULL CONSTRAINT [DF_NlpRankingConfig_event_weight] DEFAULT (0) -- Optional event context after evaluation.,
        [threshold] decimal(6,5) NOT NULL CONSTRAINT [DF_NlpRankingConfig_threshold] DEFAULT (0.35) -- Display threshold.,
        [active_from] datetimeoffset(7) NOT NULL -- Effective time.,
        [active_to] datetimeoffset(7) NULL -- Retirement time.,
        [config_json] nvarchar(2000) NULL -- Bounded extra rule settings.,
        CONSTRAINT [PK_NlpRankingConfig_] PRIMARY KEY ([ranking_version])
    );
END;
GO

-- nlp.NlpProcessingJob: Intent embedding and re-embedding retry state.
IF OBJECT_ID(N'[nlp].[NlpProcessingJob]', N'U') IS NULL
BEGIN
    CREATE TABLE [nlp].[NlpProcessingJob] (
        [job_id] varchar(64) NOT NULL -- Job identifier.,
        [intent_id] varchar(64) NOT NULL -- Target intent.,
        [job_type] varchar(24) NOT NULL CONSTRAINT [DF_NlpProcessingJob_job_type] DEFAULT ('EMBED') -- EMBED or REEMBED. Normalization is synchronous for MVP.,
        [status] varchar(20) NOT NULL CONSTRAINT [DF_NlpProcessingJob_status] DEFAULT ('PENDING') -- PENDING, RUNNING, SUCCEEDED, FAILED, DEAD.,
        [attempt_count] int NOT NULL CONSTRAINT [DF_NlpProcessingJob_attempt_count] DEFAULT (0) -- Bounded attempts.,
        [available_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NlpProcessingJob_available_at] DEFAULT (SYSUTCDATETIME()) -- Retry schedule.,
        [locked_until] datetimeoffset(7) NULL -- Worker lease.,
        [error_code] varchar(64) NULL -- Sanitized failure code.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NlpProcessingJob_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NlpProcessingJob_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_NlpProcessingJob_] PRIMARY KEY ([job_id])
    );
END;
GO

-- nlp.MatchRequest: Idempotent match-search execution envelope.
IF OBJECT_ID(N'[nlp].[MatchRequest]', N'U') IS NULL
BEGIN
    CREATE TABLE [nlp].[MatchRequest] (
        [request_id] varchar(64) NOT NULL -- Client/API idempotency key.,
        [request_hash] char(64) NOT NULL -- Canonical hash of matching inputs; detects idempotency-key reuse with different inputs.,
        [requester_id] varchar(64) NOT NULL -- Authenticated member.,
        [intent_id] varchar(64) NOT NULL -- Requester intent.,
        [context_id] varchar(64) NOT NULL -- Matching context.,
        [language_code] varchar(16) NOT NULL CONSTRAINT [DF_MatchRequest_language_code] DEFAULT ('en') -- Language snapshot used for this request.,
        [requested_limit] smallint NOT NULL CONSTRAINT [DF_MatchRequest_requested_limit] DEFAULT (7) -- Allowed 3-7.,
        [request_options_json] nvarchar(2000) NULL -- Validated bounded options snapshot; no free-form secrets or raw provider payloads.,
        [status] varchar(20) NOT NULL CONSTRAINT [DF_MatchRequest_status] DEFAULT ('PROCESSING') -- PROCESSING, COMPLETED, FAILED.,
        [preprocessing_version] varchar(128) NULL -- Resolved synchronous normalization version.,
        [model_version] varchar(128) NULL -- Resolved model version.,
        [ranking_version] varchar(128) NULL -- Resolved ranking version.,
        [ranking_threshold] decimal(6,5) NULL -- Immutable threshold snapshot applied to this execution.,
        [candidate_count] int NULL -- Eligible bounded candidates examined.,
        [completed_at] datetimeoffset(7) NULL -- Completion time.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MatchRequest_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MatchRequest_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_MatchRequest_] PRIMARY KEY ([request_id])
    );
END;
GO

-- nlp.NlpMatchResult: Ranked, explained recommendation returned for one request.
IF OBJECT_ID(N'[nlp].[NlpMatchResult]', N'U') IS NULL
BEGIN
    CREATE TABLE [nlp].[NlpMatchResult] (
        [match_result_id] bigint IDENTITY(1,1) NOT NULL -- Internal key.,
        [request_id] varchar(64) NOT NULL -- FK MatchRequest.,
        [requester_id] varchar(64) NOT NULL -- Requester.,
        [candidate_id] varchar(64) NOT NULL -- Candidate.,
        [rank] smallint NOT NULL -- 1-based result rank.,
        [semantic_score] decimal(8,7) NOT NULL -- Semantic score.,
        [reciprocal_score] decimal(8,7) NULL -- Bidirectional harmonic/approved score.,
        [final_score] decimal(8,7) NOT NULL -- Versioned final ranking score.,
        [label] varchar(32) NOT NULL -- STRONG_MATCH, PLAUSIBLE_MATCH, etc.,
        [reason_codes] nvarchar(1000) NOT NULL -- JSON array of approved codes.,
        [reason_text] nvarchar(2000) NOT NULL -- Deterministic explanation.,
        [model_version] varchar(128) NOT NULL -- Embedding version.,
        [preprocessing_version] varchar(128) NOT NULL -- Normalization version.,
        [ranking_version] varchar(128) NOT NULL -- Ranking configuration.,
        [policy_status] varchar(24) NOT NULL CONSTRAINT [DF_NlpMatchResult_policy_status] DEFAULT ('ELIGIBLE') -- ELIGIBLE or SUPPRESSED.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NlpMatchResult_created_at] DEFAULT (SYSUTCDATETIME()) -- Creation time.,
        CONSTRAINT [PK_NlpMatchResult_] PRIMARY KEY ([match_result_id])
    );
END;
GO

-- nlp.NlpFeedback: Useful/not useful/inappropriate signal for recommendation quality.
IF OBJECT_ID(N'[nlp].[NlpFeedback]', N'U') IS NULL
BEGIN
    CREATE TABLE [nlp].[NlpFeedback] (
        [feedback_id] bigint IDENTITY(1,1) NOT NULL -- Internal key.,
        [supersedes_feedback_id] bigint NULL -- Optional self-FK to the earlier feedback corrected by this row.,
        [match_result_id] bigint NOT NULL -- FK NlpMatchResult.,
        [request_id] varchar(64) NOT NULL -- Denormalized request for compatibility.,
        [requester_id] varchar(64) NOT NULL -- Authenticated feedback author.,
        [candidate_id] varchar(64) NOT NULL -- Candidate.,
        [label] varchar(64) NOT NULL -- USEFUL, NOT_USEFUL, INAPPROPRIATE.,
        [reason_code] varchar(64) NULL -- Controlled error category.,
        [reason] nvarchar(1000) NULL -- Optional free text, PII checked.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NlpFeedback_created_at] DEFAULT (SYSUTCDATETIME()) -- Feedback time.,
        CONSTRAINT [PK_NlpFeedback_] PRIMARY KEY ([feedback_id])
    );
END;
GO

-- nlp.MatchSuppression: Administrative or safety suppression independent of model score.
IF OBJECT_ID(N'[nlp].[MatchSuppression]', N'U') IS NULL
BEGIN
    CREATE TABLE [nlp].[MatchSuppression] (
        [suppression_id] bigint IDENTITY(1,1) NOT NULL -- Internal key.,
        [member_id] varchar(64) NULL -- Affected member.,
        [intent_id] varchar(64) NULL -- Affected intent.,
        [context_id] varchar(64) NULL -- Optional context.,
        [reason_code] varchar(64) NOT NULL -- Controlled reason.,
        [starts_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MatchSuppression_starts_at] DEFAULT (SYSUTCDATETIME()) -- Effective time.,
        [ends_at] datetimeoffset(7) NULL -- Optional expiry.,
        [created_by] varchar(64) NOT NULL -- Administrator/service actor.,
        CONSTRAINT [PK_MatchSuppression_] PRIMARY KEY ([suppression_id])
    );
END;
GO

-- nlp.EvaluationDataset: Versioned labelled-pair dataset metadata.
IF OBJECT_ID(N'[nlp].[EvaluationDataset]', N'U') IS NULL
BEGIN
    CREATE TABLE [nlp].[EvaluationDataset] (
        [dataset_id] varchar(64) NOT NULL -- Dataset version ID.,
        [name] nvarchar(200) NOT NULL -- Display name.,
        [version] varchar(32) NOT NULL -- Immutable version.,
        [description] nvarchar(1000) NULL -- Sampling/labeling notes.,
        [source_policy] nvarchar(500) NOT NULL -- De-identification/provenance statement.,
        [status] varchar(20) NOT NULL CONSTRAINT [DF_EvaluationDataset_status] DEFAULT ('DRAFT') -- DRAFT, APPROVED, RETIRED.,
        [approved_by] varchar(64) NULL -- Evaluator/admin.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_EvaluationDataset_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_EvaluationDataset_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_EvaluationDataset_] PRIMARY KEY ([dataset_id])
    );
END;
GO

-- nlp.EvaluationPair: One labelled reciprocal matching example.
IF OBJECT_ID(N'[nlp].[EvaluationPair]', N'U') IS NULL
BEGIN
    CREATE TABLE [nlp].[EvaluationPair] (
        [evaluation_pair_id] bigint IDENTITY(1,1) NOT NULL -- Pair identifier.,
        [dataset_id] varchar(64) NOT NULL -- FK EvaluationDataset.,
        [requester_intent_text] nvarchar(4000) NOT NULL -- De-identified requester sample.,
        [candidate_intent_text] nvarchar(4000) NOT NULL -- De-identified candidate sample.,
        [structured_features_json] nvarchar(2000) NULL -- Category/industry/geography features.,
        [gold_label] varchar(32) NOT NULL -- STRONG, PLAUSIBLE, WEAK, NONE, UNSAFE.,
        [split] varchar(16) NOT NULL -- TRAIN, VALIDATION or TEST.,
        [organization_group] varchar(64) NULL -- Leakage-prevention grouping, pseudonymous.,
        [label_reason] nvarchar(1000) NULL -- Evaluator rationale.,
        CONSTRAINT [PK_EvaluationPair_] PRIMARY KEY ([evaluation_pair_id])
    );
END;
GO

-- nlp.EvaluationRun: Reproducible quality evaluation output.
IF OBJECT_ID(N'[nlp].[EvaluationRun]', N'U') IS NULL
BEGIN
    CREATE TABLE [nlp].[EvaluationRun] (
        [evaluation_run_id] varchar(64) NOT NULL -- Run identifier.,
        [dataset_id] varchar(64) NOT NULL -- Dataset version.,
        [model_version] varchar(128) NOT NULL -- Model under test.,
        [ranking_version] varchar(128) NOT NULL -- Ranking config.,
        [status] varchar(20) NOT NULL CONSTRAINT [DF_EvaluationRun_status] DEFAULT ('RUNNING') -- RUNNING, PASSED, FAILED, ERROR.,
        [metrics_json] nvarchar(max) NULL -- Precision@5, Recall@20, reciprocal precision, coverage.,
        [error_report_blob_path] nvarchar(1024) NULL -- Private report artifact.,
        [started_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_EvaluationRun_started_at] DEFAULT (SYSUTCDATETIME()) -- Run start.,
        [completed_at] datetimeoffset(7) NULL -- Run completion.,
        CONSTRAINT [PK_EvaluationRun_] PRIMARY KEY ([evaluation_run_id])
    );
END;
GO

-- moderation.ModerationCase: Unified case for member reports, content flags and account review.
IF OBJECT_ID(N'[moderation].[ModerationCase]', N'U') IS NULL
BEGIN
    CREATE TABLE [moderation].[ModerationCase] (
        [moderation_case_id] varchar(64) NOT NULL -- Case identifier.,
        [source_type] varchar(32) NOT NULL -- MEMBER_REPORT, AUTO_SCAN, ADMIN_REVIEW.,
        [source_id] varchar(64) NULL -- Source record identifier.,
        [subject_member_id] varchar(64) NULL -- Member under review.,
        [resource_type] varchar(32) NULL -- PROFILE, MESSAGE, ATTACHMENT, INTENT.,
        [resource_id] varchar(64) NULL -- Reviewed resource.,
        [priority] varchar(16) NOT NULL CONSTRAINT [DF_ModerationCase_priority] DEFAULT ('NORMAL') -- LOW, NORMAL, HIGH, URGENT.,
        [status] varchar(24) NOT NULL CONSTRAINT [DF_ModerationCase_status] DEFAULT ('OPEN') -- OPEN, TRIAGED, ACTIONED, CLOSED.,
        [assigned_to] varchar(64) NULL -- Moderator.,
        [closed_at] datetimeoffset(7) NULL -- Closure time.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_ModerationCase_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_ModerationCase_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_ModerationCase_] PRIMARY KEY ([moderation_case_id])
    );
END;
GO

-- moderation.ModerationAction: Append-only action taken within a moderation case.
IF OBJECT_ID(N'[moderation].[ModerationAction]', N'U') IS NULL
BEGIN
    CREATE TABLE [moderation].[ModerationAction] (
        [moderation_action_id] bigint IDENTITY(1,1) NOT NULL -- Action identifier.,
        [moderation_case_id] varchar(64) NOT NULL -- FK ModerationCase.,
        [actor_member_id] varchar(64) NOT NULL -- Moderator/admin.,
        [action_type] varchar(64) NOT NULL -- WARN, HIDE, SUSPEND, REJECT_FILE, CLOSE, etc.,
        [reason_code] varchar(64) NOT NULL -- Controlled reason.,
        [notes] nvarchar(2000) NULL -- Restricted case notes.,
        [effective_until] datetimeoffset(7) NULL -- Temporary action expiry.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_ModerationAction_created_at] DEFAULT (SYSUTCDATETIME()) -- Action time.,
        CONSTRAINT [PK_ModerationAction_] PRIMARY KEY ([moderation_action_id])
    );
END;
GO

-- moderation.ContentRule: Versioned blocked-content and moderation configuration.
IF OBJECT_ID(N'[moderation].[ContentRule]', N'U') IS NULL
BEGIN
    CREATE TABLE [moderation].[ContentRule] (
        [content_rule_id] varchar(64) NOT NULL -- Rule ID.,
        [rule_type] varchar(32) NOT NULL -- FILE_TYPE, TERM, RATE, POLICY.,
        [version] varchar(32) NOT NULL -- Rule version.,
        [config_json] nvarchar(max) NOT NULL -- Validated rule configuration.,
        [status] varchar(16) NOT NULL CONSTRAINT [DF_ContentRule_status] DEFAULT ('DRAFT') -- DRAFT, ACTIVE, RETIRED.,
        [active_from] datetimeoffset(7) NULL -- Activation time.,
        [created_by] varchar(64) NOT NULL -- Administrator.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_ContentRule_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_ContentRule_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_ContentRule_] PRIMARY KEY ([content_rule_id])
    );
END;
GO

-- moderation.ContentScan: Malware/content scan result for files or text resources.
IF OBJECT_ID(N'[moderation].[ContentScan]', N'U') IS NULL
BEGIN
    CREATE TABLE [moderation].[ContentScan] (
        [content_scan_id] bigint IDENTITY(1,1) NOT NULL -- Scan record.,
        [resource_type] varchar(32) NOT NULL -- ATTACHMENT, PROFILE, INTENT, MESSAGE.,
        [resource_id] varchar(64) NOT NULL -- Target object.,
        [scanner] varchar(64) NOT NULL -- Scanner/provider ID.,
        [scanner_version] varchar(64) NULL -- Engine/signature version.,
        [result] varchar(24) NOT NULL -- CLEAN, FLAGGED, MALICIOUS, ERROR.,
        [reason_codes] nvarchar(1000) NULL -- Sanitized JSON reason codes.,
        [scanned_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_ContentScan_scanned_at] DEFAULT (SYSUTCDATETIME()) -- Scan time.,
        CONSTRAINT [PK_ContentScan_] PRIMARY KEY ([content_scan_id])
    );
END;
GO

-- ops.OutboxEvent: Transactional event publication without dual-write loss.
IF OBJECT_ID(N'[ops].[OutboxEvent]', N'U') IS NULL
BEGIN
    CREATE TABLE [ops].[OutboxEvent] (
        [outbox_event_id] varchar(64) NOT NULL -- Event ID/idempotency token.,
        [aggregate_type] varchar(64) NOT NULL -- MEMBER, CONNECTION, MESSAGE, INTENT.,
        [aggregate_id] varchar(64) NOT NULL -- Source aggregate.,
        [event_type] varchar(128) NOT NULL -- Versioned event name.,
        [payload_json] nvarchar(max) NOT NULL -- Minimal event payload; avoid raw content.,
        [occurred_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_OutboxEvent_occurred_at] DEFAULT (SYSUTCDATETIME()) -- Business event time.,
        [published_at] datetimeoffset(7) NULL -- Successful publish time.,
        [attempt_count] int NOT NULL CONSTRAINT [DF_OutboxEvent_attempt_count] DEFAULT (0) -- Publish attempts.,
        [next_attempt_at] datetimeoffset(7) NULL -- Retry schedule.,
        CONSTRAINT [PK_OutboxEvent_] PRIMARY KEY ([outbox_event_id])
    );
END;
GO

-- ops.IdempotencyRecord: Safe replay of mobile/API commands.
IF OBJECT_ID(N'[ops].[IdempotencyRecord]', N'U') IS NULL
BEGIN
    CREATE TABLE [ops].[IdempotencyRecord] (
        [scope] varchar(64) NOT NULL -- API/operation scope.,
        [idempotency_key] varchar(128) NOT NULL -- Client key.,
        [actor_id] varchar(64) NOT NULL -- Authenticated member/service.,
        [request_hash] char(64) NOT NULL -- Detect key reuse with different body.,
        [status_code] smallint NULL -- Cached response status.,
        [response_ref] nvarchar(1000) NULL -- Bounded response or resource reference.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_IdempotencyRecord_created_at] DEFAULT (SYSUTCDATETIME()) -- First request.,
        [expires_at] datetimeoffset(7) NOT NULL -- Purge time.,
        CONSTRAINT [PK_IdempotencyRecord_] PRIMARY KEY ([scope], [idempotency_key])
    );
END;
GO

-- ops.BackgroundJob: Non-NLP background task lifecycle.
IF OBJECT_ID(N'[ops].[BackgroundJob]', N'U') IS NULL
BEGIN
    CREATE TABLE [ops].[BackgroundJob] (
        [background_job_id] varchar(64) NOT NULL -- Job ID.,
        [job_type] varchar(64) NOT NULL -- SCAN_FILE, SEND_NOTIFICATION, PURGE_PRESENCE, etc.,
        [resource_type] varchar(32) NULL -- Target type.,
        [resource_id] varchar(64) NULL -- Target ID.,
        [payload_json] nvarchar(2000) NULL -- Minimal validated payload.,
        [status] varchar(20) NOT NULL CONSTRAINT [DF_BackgroundJob_status] DEFAULT ('PENDING') -- PENDING, RUNNING, SUCCEEDED, FAILED, DEAD.,
        [attempt_count] int NOT NULL CONSTRAINT [DF_BackgroundJob_attempt_count] DEFAULT (0) -- Attempts.,
        [available_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_BackgroundJob_available_at] DEFAULT (SYSUTCDATETIME()) -- Schedule/retry time.,
        [error_code] varchar(64) NULL -- Sanitized failure.,
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_BackgroundJob_created_at] DEFAULT (SYSUTCDATETIME()) -- UTC creation time.,
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_BackgroundJob_updated_at] DEFAULT (SYSUTCDATETIME()) -- UTC last material update time.,
        [row_version] rowversion NOT NULL -- Optimistic concurrency token; never client supplied.,
        CONSTRAINT [PK_BackgroundJob_] PRIMARY KEY ([background_job_id])
    );
END;
GO

-- ops.AuditEvent: Append-only evidence of sensitive/security/admin actions.
IF OBJECT_ID(N'[ops].[AuditEvent]', N'U') IS NULL
BEGIN
    CREATE TABLE [ops].[AuditEvent] (
        [audit_event_id] bigint IDENTITY(1,1) NOT NULL -- Monotonic audit key.,
        [actor_type] varchar(24) NOT NULL -- MEMBER, ADMIN, SERVICE, SYSTEM.,
        [actor_id] varchar(64) NULL -- Pseudonymous/service identity.,
        [action] varchar(128) NOT NULL -- Versioned action code.,
        [resource_type] varchar(64) NULL -- Affected type.,
        [resource_id] varchar(64) NULL -- Affected ID.,
        [outcome] varchar(16) NOT NULL -- SUCCESS or DENIED/FAILED.,
        [correlation_id] varchar(64) NOT NULL -- End-to-end trace ID.,
        [metadata_json] nvarchar(2000) NULL -- Allowlisted, content-free metadata.,
        [occurred_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_AuditEvent_occurred_at] DEFAULT (SYSUTCDATETIME()) -- Event time.,
        CONSTRAINT [PK_AuditEvent_] PRIMARY KEY ([audit_event_id])
    );
END;
GO

-- analytics.ProductEvent: Privacy-safe product funnel and match-quality analytics.
IF OBJECT_ID(N'[analytics].[ProductEvent]', N'U') IS NULL
BEGIN
    CREATE TABLE [analytics].[ProductEvent] (
        [product_event_id] varchar(64) NOT NULL -- Event ID.,
        [event_name] varchar(128) NOT NULL -- PROFILE_COMPLETED, MATCH_VIEWED, REQUEST_SENT, etc.,
        [member_pseudonym] char(64) NULL -- Environment-specific salted hash, not member_id.,
        [community_id] varchar(64) NOT NULL -- Aggregation boundary.,
        [context_type] varchar(32) NULL -- EVENT or GENERAL.,
        [context_id] varchar(64) NULL -- Allowed context reference.,
        [properties_json] nvarchar(2000) NULL -- Allowlisted non-content dimensions.,
        [occurred_at] datetimeoffset(7) NOT NULL -- Client/server event time.,
        [received_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_ProductEvent_received_at] DEFAULT (SYSUTCDATETIME()) -- Server receipt time.,
        CONSTRAINT [PK_ProductEvent_] PRIMARY KEY ([product_event_id])
    );
END;
GO


-- ======================== CONSTRAINTS AND INDEXES ========================
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


-- ======================== CONTROLLED VIEWS ========================
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


-- ======================== STORED PROCEDURES ========================
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


-- ======================== REFERENCE DATA ========================
SET XACT_ABORT ON;
GO

MERGE iam.Role AS target
USING (VALUES
    ('MEMBER','Member','Standard product member',0),
    ('EVENT_ADMIN','Event administrator','Manages events and event policies',1),
    ('MODERATOR','Moderator','Reviews reports and moderation cases',1),
    ('PRODUCT_ADMIN','Product administrator','Manages configuration and member status',1),
    ('NLP_EVALUATOR','NLP evaluator','Manages models, ranking and evaluation',1),
    ('SUPPORT','Support','Privacy and consent support with restricted access',1)
) AS source(role_code,name,description,is_privileged)
ON target.role_code=source.role_code
WHEN MATCHED THEN UPDATE SET name=source.name,description=source.description,is_privileged=source.is_privileged,updated_at=SYSUTCDATETIME()
WHEN NOT MATCHED THEN INSERT(role_code,name,description,is_privileged) VALUES(source.role_code,source.name,source.description,source.is_privileged);
GO

IF NOT EXISTS (SELECT 1 FROM nlp.NlpRankingConfig WHERE ranking_version='ranking-v1')
INSERT nlp.NlpRankingConfig(ranking_version,semantic_weight,category_weight,industry_weight,geography_weight,freshness_weight,event_weight,threshold,active_from)
VALUES('ranking-v1',0.40000,0.25000,0.15000,0.10000,0.10000,0.00000,0.35000,SYSUTCDATETIME());
GO

-- Optional QA defaults. Production activation requires product/security approval.
IF 0=1 AND NOT EXISTS (SELECT 1 FROM notification.NotificationPolicy)
BEGIN
    INSERT notification.NotificationPolicy(community_id,purpose_code,channel,policy_version,status,member_opt_out_allowed,quiet_hours_behavior,dedupe_window_seconds,max_per_hour,max_per_day,max_attempts,retry_schedule_seconds,ttl_minutes,effective_from)
    VALUES
      (NULL,'MATCH','PUSH',1,'ACTIVE',1,'DEFER',300,6,30,3,'60,300,1800',1440,SYSUTCDATETIME()),
      (NULL,'REQUEST','PUSH',1,'ACTIVE',1,'DEFER',300,12,50,3,'60,300,1800',1440,SYSUTCDATETIME()),
      (NULL,'CHAT','PUSH',1,'ACTIVE',1,'DEFER',60,30,200,3,'60,300,1800',1440,SYSUTCDATETIME()),
      (NULL,'EVENT','PUSH',1,'ACTIVE',1,'DEFER',300,8,40,3,'60,300,1800',1440,SYSUTCDATETIME()),
      (NULL,'SAFETY','PUSH',1,'ACTIVE',0,'BYPASS',60,20,100,5,'30,120,300,900,1800',2880,SYSUTCDATETIME()),
      (NULL,'ACCOUNT','EMAIL',1,'ACTIVE',0,'BYPASS',300,10,30,5,'60,300,1800,3600,7200',10080,SYSUTCDATETIME());
END;
GO


-- ======================== DATABASE ROLES AND GRANTS ========================
SET XACT_ABORT ON;
GO

DECLARE @Roles TABLE(role_name sysname, schema_name sysname);
INSERT @Roles VALUES
('olga_core_app','core'),('olga_identity_app','iam'),('olga_consent_app','consent'),('olga_event_app','event'),
('olga_social_app','social'),('olga_chat_app','chat'),('olga_notification_app','notification'),('olga_nlp_app','nlp'),
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
GO


-- ======================== POST-DEPLOYMENT VERIFICATION ========================
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
