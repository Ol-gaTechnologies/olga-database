/*
OLGA Connect Release 1 - Azure SQL full database setup
Architecture baseline: Database Architecture and Table-Level Design v2.3
Implementation baseline: MVP Architecture Implementation Guide v1.0
Target: a new, empty Azure SQL Database

This script is additive and does not drop objects. Provisional QA notification-policy
seeding is disabled in this standalone build until product and security approve it.
*/
-- ======================== SCHEMAS AND SEQUENCES ========================
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
IF SCHEMA_ID(N'storage') IS NULL EXEC(N'CREATE SCHEMA [storage] AUTHORIZATION dbo');
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

IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = N'SyncChangeSequence' AND schema_id = SCHEMA_ID(N'ops'))
    EXEC(N'CREATE SEQUENCE ops.SyncChangeSequence AS bigint START WITH 1 INCREMENT BY 1 CACHE 100');
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
        [community_id] varchar(64) NOT NULL, -- Stable API identifier.
        [name] nvarchar(200) NOT NULL, -- Display name.
        [status] varchar(24) NOT NULL CONSTRAINT [DF_Community_status] DEFAULT ('ACTIVE'), -- ACTIVE, SUSPENDED or CLOSED.
        [default_locale] varchar(16) NOT NULL CONSTRAINT [DF_Community_default_locale] DEFAULT ('en'), -- BCP-47 default locale.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Community_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Community_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_Community_] PRIMARY KEY ([community_id])
    );
END;
GO

-- iam.Member: Authoritative member account and lifecycle state.
IF OBJECT_ID(N'[iam].[Member]', N'U') IS NULL
BEGIN
    CREATE TABLE [iam].[Member] (
        [member_id] varchar(64) NOT NULL, -- Opaque identifier; use GUID/ULID string.
        [community_id] varchar(64) NOT NULL, -- FK core.Community.
        [status] varchar(24) NOT NULL CONSTRAINT [DF_Member_status] DEFAULT ('PENDING'), -- PENDING, ACTIVE, SUSPENDED, ANONYMIZED, DELETED.
        [locale] varchar(16) NOT NULL CONSTRAINT [DF_Member_locale] DEFAULT ('en'), -- Preferred locale.
        [verified_at] datetimeoffset(7) NULL, -- First completed account verification.
        [suspended_at] datetimeoffset(7) NULL, -- Administrative suspension time.
        [deleted_at] datetimeoffset(7) NULL, -- Deletion/anonymization workflow start.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Member_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Member_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_Member_] PRIMARY KEY ([member_id])
    );
END;
GO

-- iam.MemberIdentity: Email/mobile/passwordless/Entra identity mapping.
IF OBJECT_ID(N'[iam].[MemberIdentity]', N'U') IS NULL
BEGIN
    CREATE TABLE [iam].[MemberIdentity] (
        [member_identity_id] bigint IDENTITY(1,1) NOT NULL, -- Internal key.
        [member_id] varchar(64) NOT NULL, -- FK iam.Member.
        [provider] varchar(32) NOT NULL, -- EMAIL, PHONE, ENTRA or approved provider.
        [provider_subject_hash] char(64) NOT NULL, -- Keyed deterministic hash used for equality lookup and uniqueness.
        [provider_subject_ciphertext] varbinary(max) NOT NULL, -- Encrypted normalized email/mobile or external subject.
        [display_hint] nvarchar(80) NULL, -- Masked support hint; never authoritative.
        [is_primary] bit NOT NULL CONSTRAINT [DF_MemberIdentity_is_primary] DEFAULT (0), -- Primary sign-in identity flag.
        [verified_at] datetimeoffset(7) NULL, -- Verification completion.
        [last_login_at] datetimeoffset(7) NULL, -- Security/account support signal.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberIdentity_created_at] DEFAULT (SYSUTCDATETIME()), -- Creation time.
        CONSTRAINT [PK_MemberIdentity_] PRIMARY KEY ([member_identity_id])
    );
END;
GO

-- iam.Permission: Controlled application permission catalog used by API authorization policies.
IF OBJECT_ID(N'[iam].[Permission]', N'U') IS NULL
BEGIN
    CREATE TABLE [iam].[Permission] (
        [permission_code] varchar(96) NOT NULL, -- Stable application permission code.
        [resource_type] varchar(64) NOT NULL, -- Protected application resource.
        [action] varchar(32) NOT NULL, -- READ, CREATE, UPDATE, DELETE, APPROVE, EXPORT or CONFIGURE.
        [description] nvarchar(500) NULL, -- Human-readable authorization intent.
        [status] varchar(16) NOT NULL CONSTRAINT [DF_Permission_status] DEFAULT ('ACTIVE'), -- ACTIVE or RETIRED.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Permission_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Permission_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_Permission_] PRIMARY KEY ([permission_code])
    );
END;
GO

-- iam.RolePermission: Versioned mapping from application roles to permissions.
IF OBJECT_ID(N'[iam].[RolePermission]', N'U') IS NULL
BEGIN
    CREATE TABLE [iam].[RolePermission] (
        [role_code] varchar(64) NOT NULL, -- FK iam.Role.
        [permission_code] varchar(96) NOT NULL, -- FK iam.Permission.
        [granted_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_RolePermission_granted_at] DEFAULT (SYSUTCDATETIME()), -- Grant time.
        [granted_by] varchar(64) NULL, -- Administrator approving the grant.
        [revoked_at] datetimeoffset(7) NULL, -- Revocation time; null while active.
        CONSTRAINT [PK_RolePermission_] PRIMARY KEY ([role_code], [permission_code])
    );
END;
GO

-- iam.Role: Controlled role catalog for member and administrator authorization.
IF OBJECT_ID(N'[iam].[Role]', N'U') IS NULL
BEGIN
    CREATE TABLE [iam].[Role] (
        [role_code] varchar(64) NOT NULL, -- MEMBER, ADMIN, MODERATOR, NLP_EVALUATOR.
        [name] nvarchar(100) NOT NULL, -- Display name.
        [description] nvarchar(500) NULL, -- Scope and intended use.
        [is_privileged] bit NOT NULL CONSTRAINT [DF_Role_is_privileged] DEFAULT (0), -- Requires elevated authentication and audit.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Role_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Role_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_Role_] PRIMARY KEY ([role_code])
    );
END;
GO

-- iam.AuthSession: Application session binding and revocation state; no bearer or refresh tokens.
IF OBJECT_ID(N'[iam].[AuthSession]', N'U') IS NULL
BEGIN
    CREATE TABLE [iam].[AuthSession] (
        [session_id] varchar(64) NOT NULL, -- Opaque application session identifier.
        [member_id] varchar(64) NOT NULL, -- FK iam.Member.
        [device_id] varchar(64) NULL, -- Optional FK iam.MemberDevice.
        [identity_provider] varchar(32) NOT NULL, -- Approved CIAM provider.
        [provider_session_hash] char(64) NULL, -- Hash of provider session reference; never store tokens.
        [auth_strength] varchar(24) NOT NULL CONSTRAINT [DF_AuthSession_auth_strength] DEFAULT ('STANDARD'), -- STANDARD, MFA or STEP_UP.
        [issued_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_AuthSession_issued_at] DEFAULT (SYSUTCDATETIME()), -- Session issue time.
        [expires_at] datetimeoffset(7) NOT NULL, -- Hard application expiry.
        [last_seen_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_AuthSession_last_seen_at] DEFAULT (SYSUTCDATETIME()), -- Last validated request.
        [revoked_at] datetimeoffset(7) NULL, -- Immediate logout, deletion or compromise revocation.
        [revocation_reason] varchar(64) NULL, -- Controlled reason code.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_AuthSession_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_AuthSession_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_AuthSession_] PRIMARY KEY ([session_id])
    );
END;
GO

-- iam.MemberRole: Role assignment with optional expiry.
IF OBJECT_ID(N'[iam].[MemberRole]', N'U') IS NULL
BEGIN
    CREATE TABLE [iam].[MemberRole] (
        [member_id] varchar(64) NOT NULL, -- FK iam.Member.
        [role_code] varchar(64) NOT NULL, -- FK iam.Role.
        [granted_by] varchar(64) NULL, -- Administrator member ID.
        [granted_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberRole_granted_at] DEFAULT (SYSUTCDATETIME()), -- Grant time.
        [expires_at] datetimeoffset(7) NULL, -- Optional expiry.
        [revoked_at] datetimeoffset(7) NULL, -- Revocation time.
        CONSTRAINT [PK_MemberRole_] PRIMARY KEY ([member_id], [role_code])
    );
END;
GO

-- iam.MemberDevice: Registered mobile installation and security state.
IF OBJECT_ID(N'[iam].[MemberDevice]', N'U') IS NULL
BEGIN
    CREATE TABLE [iam].[MemberDevice] (
        [device_id] varchar(64) NOT NULL, -- Client installation identifier, rotated on reinstall.
        [member_id] varchar(64) NOT NULL, -- FK iam.Member.
        [platform] varchar(16) NOT NULL, -- IOS or ANDROID.
        [app_version] varchar(32) NOT NULL, -- Last reported app version.
        [status] varchar(20) NOT NULL CONSTRAINT [DF_MemberDevice_status] DEFAULT ('ACTIVE'), -- ACTIVE or REVOKED.
        [last_seen_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberDevice_last_seen_at] DEFAULT (SYSUTCDATETIME()), -- Last authenticated request.
        [revoked_at] datetimeoffset(7) NULL, -- Remote logout/device loss handling.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberDevice_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberDevice_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_MemberDevice_] PRIMARY KEY ([device_id])
    );
END;
GO

-- core.Organization: Professional organization represented in profiles.
IF OBJECT_ID(N'[core].[Organization]', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[Organization] (
        [organization_id] varchar(64) NOT NULL, -- Stable identifier.
        [community_id] varchar(64) NOT NULL, -- FK core.Community.
        [name] nvarchar(250) NOT NULL, -- Canonical organization name.
        [normalized_name] nvarchar(250) NOT NULL, -- Search/deduplication form.
        [website_domain] nvarchar(255) NULL, -- Verified domain when available.
        [industry_code] varchar(64) NULL, -- Reference taxonomy.
        [verification_status] varchar(24) NOT NULL CONSTRAINT [DF_Organization_verification_status] DEFAULT ('UNVERIFIED'), -- UNVERIFIED, PENDING, VERIFIED, REJECTED.
        [status] varchar(20) NOT NULL CONSTRAINT [DF_Organization_status] DEFAULT ('ACTIVE'), -- Lifecycle state.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Organization_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Organization_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_Organization_] PRIMARY KEY ([organization_id])
    );
END;
GO

-- core.OrganizationMember: Member affiliation, title and organization-level role.
IF OBJECT_ID(N'[core].[OrganizationMember]', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[OrganizationMember] (
        [organization_member_id] bigint IDENTITY(1,1) NOT NULL, -- Internal key.
        [organization_id] varchar(64) NOT NULL, -- FK core.Organization.
        [member_id] varchar(64) NOT NULL, -- FK iam.Member.
        [job_title] nvarchar(200) NULL, -- Professional title.
        [department] nvarchar(150) NULL, -- Optional function/department.
        [is_primary] bit NOT NULL CONSTRAINT [DF_OrganizationMember_is_primary] DEFAULT (0), -- Primary current affiliation.
        [started_on] date NULL, -- Optional month/day precision per product policy.
        [ended_on] date NULL, -- Null for current affiliation.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_OrganizationMember_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_OrganizationMember_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_OrganizationMember_] PRIMARY KEY ([organization_member_id])
    );
END;
GO

-- core.MemberProfile: Searchable professional profile and visibility state.
IF OBJECT_ID(N'[core].[MemberProfile]', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[MemberProfile] (
        [member_id] varchar(64) NOT NULL, -- One-to-one FK iam.Member.
        [display_name] nvarchar(150) NOT NULL, -- Member-facing name.
        [headline] nvarchar(240) NULL, -- Short professional headline.
        [professional_summary] nvarchar(2000) NULL, -- Member-authored summary.
        [role_category] varchar(64) NULL, -- Controlled role/function code.
        [profile_status] varchar(24) NOT NULL CONSTRAINT [DF_MemberProfile_profile_status] DEFAULT ('DRAFT'), -- DRAFT, PENDING_REVIEW, ACTIVE, HIDDEN.
        [visibility] varchar(20) NOT NULL CONSTRAINT [DF_MemberProfile_visibility] DEFAULT ('MEMBERS'), -- PRIVATE, MEMBERS or CONTEXT_ONLY.
        [completeness_score] decimal(5,2) NOT NULL CONSTRAINT [DF_MemberProfile_completeness_score] DEFAULT (0), -- Derived profile completeness percentage.
        [published_at] datetimeoffset(7) NULL, -- First/current publication time.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberProfile_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberProfile_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_MemberProfile_] PRIMARY KEY ([member_id])
    );
END;
GO

-- core.Sector: Controlled sector/industry taxonomy.
IF OBJECT_ID(N'[core].[Sector]', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[Sector] (
        [sector_code] varchar(64) NOT NULL, -- Stable taxonomy code.
        [parent_sector_code] varchar(64) NULL, -- Self-referencing hierarchy.
        [name] nvarchar(150) NOT NULL, -- Display label.
        [status] varchar(16) NOT NULL CONSTRAINT [DF_Sector_status] DEFAULT ('ACTIVE'), -- ACTIVE or RETIRED.
        [sort_order] int NOT NULL CONSTRAINT [DF_Sector_sort_order] DEFAULT (0), -- Presentation order.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Sector_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Sector_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_Sector_] PRIMARY KEY ([sector_code])
    );
END;
GO

-- core.MemberSector: Many-to-many profile sector selection.
IF OBJECT_ID(N'[core].[MemberSector]', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[MemberSector] (
        [member_id] varchar(64) NOT NULL, -- FK MemberProfile.
        [sector_code] varchar(64) NOT NULL, -- FK Sector.
        [is_primary] bit NOT NULL CONSTRAINT [DF_MemberSector_is_primary] DEFAULT (0), -- Primary sector flag.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberSector_created_at] DEFAULT (SYSUTCDATETIME()), -- Assignment time.
        CONSTRAINT [PK_MemberSector_] PRIMARY KEY ([member_id], [sector_code])
    );
END;
GO

-- core.MemberGeography: Member operating markets; not live location.
IF OBJECT_ID(N'[core].[MemberGeography]', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[MemberGeography] (
        [member_geography_id] bigint IDENTITY(1,1) NOT NULL, -- Internal key.
        [member_id] varchar(64) NOT NULL, -- FK MemberProfile.
        [country_code] char(2) NOT NULL, -- ISO 3166-1 alpha-2.
        [region] nvarchar(120) NULL, -- State/region.
        [city] nvarchar(120) NULL, -- Operating city.
        [is_primary] bit NOT NULL CONSTRAINT [DF_MemberGeography_is_primary] DEFAULT (0), -- Primary market.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberGeography_created_at] DEFAULT (SYSUTCDATETIME()), -- Creation time.
        CONSTRAINT [PK_MemberGeography_] PRIMARY KEY ([member_geography_id])
    );
END;
GO

-- core.ProfileFieldVisibility: Per-field exposure before/after connection.
IF OBJECT_ID(N'[core].[ProfileFieldVisibility]', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[ProfileFieldVisibility] (
        [member_id] varchar(64) NOT NULL, -- FK MemberProfile.
        [field_code] varchar(64) NOT NULL, -- PROFILE_SUMMARY, ORGANIZATION, GEOGRAPHY, etc.
        [audience] varchar(24) NOT NULL CONSTRAINT [DF_ProfileFieldVisibility_audience] DEFAULT ('CONNECTED'), -- PRIVATE, MATCHED, CONNECTED, MEMBERS.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_ProfileFieldVisibility_updated_at] DEFAULT (SYSUTCDATETIME()), -- Last preference change.
        [row_version] rowversion NOT NULL, -- Concurrency token.
        CONSTRAINT [PK_ProfileFieldVisibility_] PRIMARY KEY ([member_id], [field_code])
    );
END;
GO

-- core.MemberVerification: Administrator/member verification workflow.
IF OBJECT_ID(N'[core].[MemberVerification]', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[MemberVerification] (
        [verification_id] varchar(64) NOT NULL, -- Case identifier.
        [member_id] varchar(64) NOT NULL, -- FK iam.Member.
        [verification_type] varchar(32) NOT NULL, -- EMAIL, PHONE, ORGANIZATION or MANUAL.
        [status] varchar(24) NOT NULL CONSTRAINT [DF_MemberVerification_status] DEFAULT ('PENDING'), -- PENDING, APPROVED, REJECTED, EXPIRED.
        [evidence_file_asset_id] varchar(64) NULL, -- Private storage.FileAsset evidence reference, if policy permits.
        [reviewed_by] varchar(64) NULL, -- Administrator member ID.
        [reviewed_at] datetimeoffset(7) NULL, -- Review completion.
        [reason_code] varchar(64) NULL, -- Controlled result reason.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberVerification_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberVerification_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_MemberVerification_] PRIMARY KEY ([verification_id])
    );
END;
GO

-- consent.ConsentPolicy: Versioned consent purpose and legal/community text.
IF OBJECT_ID(N'[consent].[ConsentPolicy]', N'U') IS NULL
BEGIN
    CREATE TABLE [consent].[ConsentPolicy] (
        [policy_id] varchar(64) NOT NULL, -- Stable policy version ID.
        [purpose_code] varchar(64) NOT NULL, -- TERMS, LOCATION, LIVE_MODE, NOTIFICATIONS, ANALYTICS.
        [version] varchar(32) NOT NULL, -- Human-readable version.
        [locale] varchar(16) NOT NULL CONSTRAINT [DF_ConsentPolicy_locale] DEFAULT ('en'), -- Text locale.
        [content_hash] char(64) NOT NULL, -- SHA-256 of presented content.
        [effective_from] datetimeoffset(7) NOT NULL, -- Activation time.
        [retired_at] datetimeoffset(7) NULL, -- Retirement time.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_ConsentPolicy_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_ConsentPolicy_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_ConsentPolicy_] PRIMARY KEY ([policy_id])
    );
END;
GO

-- consent.MemberConsent: Authoritative grant/withdrawal evidence by purpose.
IF OBJECT_ID(N'[consent].[MemberConsent]', N'U') IS NULL
BEGIN
    CREATE TABLE [consent].[MemberConsent] (
        [member_consent_id] bigint IDENTITY(1,1) NOT NULL, -- Evidence record.
        [member_id] varchar(64) NOT NULL, -- FK iam.Member.
        [policy_id] varchar(64) NOT NULL, -- FK ConsentPolicy.
        [decision] varchar(16) NOT NULL, -- GRANTED or DENIED.
        [captured_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberConsent_captured_at] DEFAULT (SYSUTCDATETIME()), -- Decision time.
        [withdrawn_at] datetimeoffset(7) NULL, -- Withdrawal time.
        [capture_channel] varchar(24) NOT NULL, -- MOBILE, WEB_ADMIN or SUPPORT.
        [evidence_json] nvarchar(1000) NULL, -- Bounded device/app/version evidence; no secrets.
        CONSTRAINT [PK_MemberConsent_] PRIMARY KEY ([member_consent_id])
    );
END;
GO

-- consent.PrivacyRequest: Member data access, correction, deletion or consent-support case.
IF OBJECT_ID(N'[consent].[PrivacyRequest]', N'U') IS NULL
BEGIN
    CREATE TABLE [consent].[PrivacyRequest] (
        [privacy_request_id] varchar(64) NOT NULL, -- Case identifier.
        [member_id] varchar(64) NOT NULL, -- Requesting member.
        [request_type] varchar(24) NOT NULL, -- ACCESS, CORRECT, DELETE, EXPORT, CONSENT_SUPPORT.
        [status] varchar(24) NOT NULL CONSTRAINT [DF_PrivacyRequest_status] DEFAULT ('OPEN'), -- OPEN, VERIFIED, PROCESSING, COMPLETED, REJECTED.
        [verified_at] datetimeoffset(7) NULL, -- Identity verification.
        [due_at] datetimeoffset(7) NULL, -- Policy deadline.
        [completed_at] datetimeoffset(7) NULL, -- Completion time.
        [result_file_asset_id] varchar(64) NULL, -- Private storage.FileAsset export package reference.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_PrivacyRequest_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_PrivacyRequest_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_PrivacyRequest_] PRIMARY KEY ([privacy_request_id])
    );
END;
GO

-- consent.PrivacyRequestTask: Per-domain execution and evidence ledger for a privacy request.
IF OBJECT_ID(N'[consent].[PrivacyRequestTask]', N'U') IS NULL
BEGIN
    CREATE TABLE [consent].[PrivacyRequestTask] (
        [privacy_request_task_id] bigint IDENTITY(1,1) NOT NULL, -- Execution step identifier.
        [privacy_request_id] varchar(64) NOT NULL, -- FK consent.PrivacyRequest.
        [domain_code] varchar(32) NOT NULL, -- IAM, PROFILE, EVENT, SOCIAL, CHAT, STORAGE, NLP, ANALYTICS or AUDIT.
        [action_type] varchar(24) NOT NULL, -- EXPORT, CORRECT, ANONYMIZE, DELETE or RETAIN_EXCEPTION.
        [status] varchar(20) NOT NULL CONSTRAINT [DF_PrivacyRequestTask_status] DEFAULT ('PENDING'), -- PENDING, RUNNING, COMPLETED, FAILED or EXEMPTED.
        [attempt_count] smallint NOT NULL CONSTRAINT [DF_PrivacyRequestTask_attempt_count] DEFAULT (0), -- Execution attempts.
        [evidence_code] varchar(64) NULL, -- Controlled completion or exception evidence.
        [evidence_hash] char(64) NULL, -- Hash of generated evidence or result manifest.
        [started_at] datetimeoffset(7) NULL, -- First execution start.
        [completed_at] datetimeoffset(7) NULL, -- Successful or exempted completion.
        [last_error_code] varchar(64) NULL, -- Sanitized retryable/permanent error.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_PrivacyRequestTask_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_PrivacyRequestTask_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_PrivacyRequestTask_] PRIMARY KEY ([privacy_request_task_id])
    );
END;
GO

-- event.Venue: Admin-configured venue and coarse proximity boundary.
IF OBJECT_ID(N'[event].[Venue]', N'U') IS NULL
BEGIN
    CREATE TABLE [event].[Venue] (
        [venue_id] varchar(64) NOT NULL, -- Venue identifier.
        [name] nvarchar(200) NOT NULL, -- Venue name.
        [country_code] char(2) NOT NULL, -- ISO country.
        [region] nvarchar(120) NULL, -- Region/state.
        [city] nvarchar(120) NULL, -- City.
        [coarse_geo_cell] varchar(32) NULL, -- Venue-level geohash/H3 cell; not member location.
        [timezone_id] varchar(64) NOT NULL, -- IANA/Windows mapping controlled by service.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Venue_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Venue_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_Venue_] PRIMARY KEY ([venue_id])
    );
END;
GO

-- event.Event: Event/context used for registration, Live Mode and matching.
IF OBJECT_ID(N'[event].[Event]', N'U') IS NULL
BEGIN
    CREATE TABLE [event].[Event] (
        [event_id] varchar(64) NOT NULL, -- Also used as matching context_id.
        [community_id] varchar(64) NOT NULL, -- FK Community.
        [venue_id] varchar(64) NULL, -- FK Venue.
        [name] nvarchar(250) NOT NULL, -- Event name.
        [description] nvarchar(2000) NULL, -- Admin-managed description.
        [starts_at] datetimeoffset(7) NOT NULL, -- UTC start.
        [ends_at] datetimeoffset(7) NOT NULL, -- UTC end.
        [status] varchar(24) NOT NULL CONSTRAINT [DF_Event_status] DEFAULT ('DRAFT'), -- DRAFT, PUBLISHED, ACTIVE, COMPLETED, CANCELLED.
        [live_mode_enabled] bit NOT NULL CONSTRAINT [DF_Event_live_mode_enabled] DEFAULT (0), -- Event allows Live Mode.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Event_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Event_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_Event_] PRIMARY KEY ([event_id])
    );
END;
GO

-- event.EventMatchingPolicy: Versioned event-level eligibility, proximity, ranking and match-alert controls.
IF OBJECT_ID(N'[event].[EventMatchingPolicy]', N'U') IS NULL
BEGIN
    CREATE TABLE [event].[EventMatchingPolicy] (
        [event_matching_policy_id] bigint IDENTITY(1,1) NOT NULL, -- Immutable policy version identifier.
        [event_id] varchar(64) NOT NULL, -- FK Event; policy applies only to this event/context.
        [policy_version] smallint NOT NULL CONSTRAINT [DF_EventMatchingPolicy_policy_version] DEFAULT (1), -- Monotonic version within the event.
        [status] varchar(16) NOT NULL CONSTRAINT [DF_EventMatchingPolicy_status] DEFAULT ('DRAFT'), -- DRAFT, ACTIVE or RETIRED.
        [registration_required] bit NOT NULL CONSTRAINT [DF_EventMatchingPolicy_registration_required] DEFAULT (1), -- Member must hold an eligible EventRegistration.
        [check_in_required] bit NOT NULL CONSTRAINT [DF_EventMatchingPolicy_check_in_required] DEFAULT (0), -- Member must be checked in before event matching.
        [live_mode_required] bit NOT NULL CONSTRAINT [DF_EventMatchingPolicy_live_mode_required] DEFAULT (1), -- Active consent-backed LiveModeSession required.
        [proximity_mode] varchar(24) NOT NULL CONSTRAINT [DF_EventMatchingPolicy_proximity_mode] DEFAULT ('VENUE'), -- NONE, VENUE or COARSE_CELL.
        [max_presence_age_minutes] smallint NULL CONSTRAINT [DF_EventMatchingPolicy_max_presence_age_minutes] DEFAULT (15), -- Maximum age of coarse presence when proximity is used.
        [match_threshold_override] decimal(6,5) NULL, -- Optional override of active NLP ranking threshold.
        [alert_confidence_threshold] decimal(6,5) NOT NULL CONSTRAINT [DF_EventMatchingPolicy_alert_confidence_threshold] DEFAULT (0.70), -- Minimum final score before a proactive match alert is eligible.
        [max_match_alerts_per_hour] smallint NOT NULL CONSTRAINT [DF_EventMatchingPolicy_max_match_alerts_per_hour] DEFAULT (2), -- Event-specific hourly cap per member.
        [max_match_alerts_per_event] smallint NOT NULL CONSTRAINT [DF_EventMatchingPolicy_max_match_alerts_per_event] DEFAULT (10), -- Event-lifetime cap per member.
        [minimum_alert_interval_minutes] smallint NOT NULL CONSTRAINT [DF_EventMatchingPolicy_minimum_alert_interval_minutes] DEFAULT (30), -- Minimum spacing between event match alerts.
        [effective_from] datetimeoffset(7) NOT NULL, -- Start of policy applicability.
        [effective_to] datetimeoffset(7) NULL, -- Optional retirement time.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_EventMatchingPolicy_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_EventMatchingPolicy_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_EventMatchingPolicy_] PRIMARY KEY ([event_matching_policy_id])
    );
END;
GO

-- event.EventRegistration: Member eligibility/check-in relationship to an event.
IF OBJECT_ID(N'[event].[EventRegistration]', N'U') IS NULL
BEGIN
    CREATE TABLE [event].[EventRegistration] (
        [event_registration_id] bigint IDENTITY(1,1) NOT NULL, -- Internal key.
        [event_id] varchar(64) NOT NULL, -- FK Event.
        [member_id] varchar(64) NOT NULL, -- FK Member.
        [status] varchar(24) NOT NULL CONSTRAINT [DF_EventRegistration_status] DEFAULT ('REGISTERED'), -- INVITED, REGISTERED, CHECKED_IN, CANCELLED.
        [registered_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_EventRegistration_registered_at] DEFAULT (SYSUTCDATETIME()), -- Registration time.
        [checked_in_at] datetimeoffset(7) NULL, -- Event check-in time.
        [source] varchar(24) NOT NULL CONSTRAINT [DF_EventRegistration_source] DEFAULT ('APP'), -- APP, ADMIN, IMPORT.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_EventRegistration_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_EventRegistration_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_EventRegistration_] PRIMARY KEY ([event_registration_id])
    );
END;
GO

-- event.LiveModeSession: Bounded, revocable member discovery session.
IF OBJECT_ID(N'[event].[LiveModeSession]', N'U') IS NULL
BEGIN
    CREATE TABLE [event].[LiveModeSession] (
        [live_session_id] varchar(64) NOT NULL, -- Session identifier.
        [event_id] varchar(64) NOT NULL, -- FK Event.
        [member_id] varchar(64) NOT NULL, -- FK Member.
        [consent_record_id] bigint NOT NULL, -- Valid Live Mode consent evidence.
        [status] varchar(16) NOT NULL CONSTRAINT [DF_LiveModeSession_status] DEFAULT ('ACTIVE'), -- ACTIVE, DISABLED, EXPIRED.
        [activated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_LiveModeSession_activated_at] DEFAULT (SYSUTCDATETIME()), -- Activation time.
        [active_until] datetimeoffset(7) NOT NULL, -- Hard expiry bounded by event.
        [disabled_at] datetimeoffset(7) NULL, -- Immediate revocation time.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_LiveModeSession_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_LiveModeSession_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_LiveModeSession_] PRIMARY KEY ([live_session_id])
    );
END;
GO

-- event.EventPresence: Coarse, short-lived evidence used for nearby matching.
IF OBJECT_ID(N'[event].[EventPresence]', N'U') IS NULL
BEGIN
    CREATE TABLE [event].[EventPresence] (
        [presence_id] bigint IDENTITY(1,1) NOT NULL, -- Internal key.
        [live_session_id] varchar(64) NOT NULL, -- FK LiveModeSession.
        [coarse_cell] varchar(32) NOT NULL, -- Approved coarse geohash/H3 cell.
        [observed_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_EventPresence_observed_at] DEFAULT (SYSUTCDATETIME()), -- Observation time.
        [expires_at] datetimeoffset(7) NOT NULL, -- Automatic purge time.
        [source] varchar(24) NOT NULL, -- CHECK_IN, FOREGROUND_GEO or VENUE_ZONE.
        CONSTRAINT [PK_EventPresence_] PRIMARY KEY ([presence_id])
    );
END;
GO

-- social.ConnectionRequest: Consent gate before creating a connection/chat.
IF OBJECT_ID(N'[social].[ConnectionRequest]', N'U') IS NULL
BEGIN
    CREATE TABLE [social].[ConnectionRequest] (
        [connection_request_id] varchar(64) NOT NULL, -- Request identifier.
        [sender_member_id] varchar(64) NOT NULL, -- Requester.
        [recipient_member_id] varchar(64) NOT NULL, -- Recipient.
        [context_id] varchar(64) NULL, -- Event or general matching context.
        [match_result_id] bigint NULL, -- Recommendation that led to request.
        [note] nvarchar(500) NULL, -- Optional introduction note; moderate as content.
        [status] varchar(24) NOT NULL CONSTRAINT [DF_ConnectionRequest_status] DEFAULT ('PENDING'), -- PENDING, ACCEPTED, DECLINED, WITHDRAWN, EXPIRED.
        [expires_at] datetimeoffset(7) NOT NULL, -- Policy-calculated expiry for a pending request.
        [responded_at] datetimeoffset(7) NULL, -- Terminal response time.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_ConnectionRequest_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_ConnectionRequest_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_ConnectionRequest_] PRIMARY KEY ([connection_request_id])
    );
END;
GO

-- social.Connection: Mutually accepted member relationship.
IF OBJECT_ID(N'[social].[Connection]', N'U') IS NULL
BEGIN
    CREATE TABLE [social].[Connection] (
        [connection_id] varchar(64) NOT NULL, -- Connection identifier.
        [member_low_id] varchar(64) NOT NULL, -- Lexicographically lower member ID.
        [member_high_id] varchar(64) NOT NULL, -- Lexicographically higher member ID.
        [accepted_request_id] varchar(64) NOT NULL, -- Accepted ConnectionRequest.
        [status] varchar(20) NOT NULL CONSTRAINT [DF_Connection_status] DEFAULT ('ACTIVE'), -- ACTIVE or DISCONNECTED.
        [connected_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Connection_connected_at] DEFAULT (SYSUTCDATETIME()), -- Acceptance time.
        [disconnected_at] datetimeoffset(7) NULL, -- Relationship end.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Connection_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Connection_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_Connection_] PRIMARY KEY ([connection_id])
    );
END;
GO

-- social.MemberBlock: Directional block that suppresses discovery and communication both ways.
IF OBJECT_ID(N'[social].[MemberBlock]', N'U') IS NULL
BEGIN
    CREATE TABLE [social].[MemberBlock] (
        [block_id] bigint IDENTITY(1,1) NOT NULL, -- Internal key.
        [blocker_member_id] varchar(64) NOT NULL, -- Member initiating block.
        [blocked_member_id] varchar(64) NOT NULL, -- Blocked member.
        [reason_code] varchar(64) NULL, -- Private controlled reason.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberBlock_created_at] DEFAULT (SYSUTCDATETIME()), -- Effective immediately.
        [removed_at] datetimeoffset(7) NULL, -- Optional unblock.
        CONSTRAINT [PK_MemberBlock_] PRIMARY KEY ([block_id])
    );
END;
GO

-- social.MemberReport: Member-submitted safety/report workflow trigger.
IF OBJECT_ID(N'[social].[MemberReport]', N'U') IS NULL
BEGIN
    CREATE TABLE [social].[MemberReport] (
        [report_id] varchar(64) NOT NULL, -- Report identifier.
        [reporter_member_id] varchar(64) NOT NULL, -- Reporter.
        [reported_member_id] varchar(64) NOT NULL, -- Subject.
        [resource_type] varchar(32) NULL, -- PROFILE, REQUEST, MESSAGE, ATTACHMENT.
        [resource_id] varchar(64) NULL, -- Reported object.
        [category] varchar(64) NOT NULL, -- Controlled report category.
        [description] nvarchar(2000) NULL, -- Reporter description.
        [status] varchar(24) NOT NULL CONSTRAINT [DF_MemberReport_status] DEFAULT ('OPEN'), -- OPEN, TRIAGED, RESOLVED, DISMISSED.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberReport_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MemberReport_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_MemberReport_] PRIMARY KEY ([report_id])
    );
END;
GO

-- chat.Conversation: Accepted-connection one-to-one chat container.
IF OBJECT_ID(N'[chat].[Conversation]', N'U') IS NULL
BEGIN
    CREATE TABLE [chat].[Conversation] (
        [conversation_id] varchar(64) NOT NULL, -- Conversation identifier.
        [connection_id] varchar(64) NOT NULL, -- One conversation per accepted connection.
        [status] varchar(20) NOT NULL CONSTRAINT [DF_Conversation_status] DEFAULT ('ACTIVE'), -- ACTIVE, CLOSED, RESTRICTED.
        [last_message_at] datetimeoffset(7) NULL, -- Conversation list ordering.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Conversation_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Conversation_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_Conversation_] PRIMARY KEY ([conversation_id])
    );
END;
GO

-- chat.ConversationParticipant: Per-member chat state and authorization projection.
IF OBJECT_ID(N'[chat].[ConversationParticipant]', N'U') IS NULL
BEGIN
    CREATE TABLE [chat].[ConversationParticipant] (
        [conversation_id] varchar(64) NOT NULL, -- FK Conversation.
        [member_id] varchar(64) NOT NULL, -- Participant.
        [joined_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_ConversationParticipant_joined_at] DEFAULT (SYSUTCDATETIME()), -- Participation start.
        [last_read_message_id] varchar(64) NULL, -- Read cursor.
        [muted_until] datetimeoffset(7) NULL, -- Notification suppression.
        [left_at] datetimeoffset(7) NULL, -- Closure/disconnect projection.
        CONSTRAINT [PK_ConversationParticipant_] PRIMARY KEY ([conversation_id], [member_id])
    );
END;
GO

-- chat.Message: Durable one-to-one message.
IF OBJECT_ID(N'[chat].[Message]', N'U') IS NULL
BEGIN
    CREATE TABLE [chat].[Message] (
        [message_id] varchar(64) NOT NULL, -- Client-generated ID supports idempotency.
        [conversation_id] varchar(64) NOT NULL, -- FK Conversation.
        [sender_member_id] varchar(64) NOT NULL, -- Authorized participant.
        [message_type] varchar(20) NOT NULL CONSTRAINT [DF_Message_message_type] DEFAULT ('TEXT'), -- TEXT, FILE, SYSTEM.
        [body] nvarchar(max) NULL, -- Text content; sanitize for display.
        [client_sent_at] datetimeoffset(7) NULL, -- Client timestamp for UX only.
        [server_sequence] bigint NOT NULL CONSTRAINT [DF_Message_server_sequence] DEFAULT (NEXT VALUE FOR chat.MessageSequence), -- Monotonic per conversation or global stream.
        [moderation_status] varchar(24) NOT NULL CONSTRAINT [DF_Message_moderation_status] DEFAULT ('PENDING_OR_CLEAR'), -- Safety state.
        [deleted_at] datetimeoffset(7) NULL, -- Logical removal time.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Message_created_at] DEFAULT (SYSUTCDATETIME()), -- Authoritative send time.
        [row_version] rowversion NOT NULL, -- Concurrency token.
        CONSTRAINT [PK_Message_] PRIMARY KEY ([message_id])
    );
END;
GO

-- chat.MessageReceipt: Message delivered/read evidence by participant.
IF OBJECT_ID(N'[chat].[MessageReceipt]', N'U') IS NULL
BEGIN
    CREATE TABLE [chat].[MessageReceipt] (
        [message_id] varchar(64) NOT NULL, -- FK Message.
        [member_id] varchar(64) NOT NULL, -- Recipient participant.
        [delivered_at] datetimeoffset(7) NULL, -- First delivery.
        [read_at] datetimeoffset(7) NULL, -- First read.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MessageReceipt_updated_at] DEFAULT (SYSUTCDATETIME()), -- Last receipt update.
        CONSTRAINT [PK_MessageReceipt_] PRIMARY KEY ([message_id], [member_id])
    );
END;
GO

-- storage.FileAsset: Domain-neutral metadata and security lifecycle for a private Azure Blob object.
IF OBJECT_ID(N'[storage].[FileAsset]', N'U') IS NULL
BEGIN
    CREATE TABLE [storage].[FileAsset] (
        [file_asset_id] varchar(64) NOT NULL, -- Opaque file identifier.
        [community_id] varchar(64) NOT NULL, -- FK core.Community and authorization boundary.
        [owner_member_id] varchar(64) NULL, -- Uploader/owner when the asset belongs to a member.
        [purpose_code] varchar(32) NOT NULL, -- CHAT_FILE, VERIFICATION_EVIDENCE, PRIVACY_EXPORT or EVALUATION_REPORT.
        [container_name] varchar(128) NOT NULL, -- Allowlisted private container; not client supplied.
        [blob_path] nvarchar(1024) NOT NULL, -- Private blob path; never store a SAS URL.
        [blob_path_hash] char(64) NOT NULL, -- Deterministic lookup without broad path exposure.
        [file_name] nvarchar(255) NOT NULL, -- Sanitized display name.
        [media_type] varchar(128) NOT NULL, -- Verified MIME type.
        [size_bytes] bigint NOT NULL, -- Validated size.
        [sha256] char(64) NOT NULL, -- Integrity and deduplication hash.
        [classification] varchar(24) NOT NULL CONSTRAINT [DF_FileAsset_classification] DEFAULT ('CONFIDENTIAL'), -- INTERNAL, CONFIDENTIAL, RESTRICTED or HIGHLY_RESTRICTED.
        [scan_status] varchar(24) NOT NULL CONSTRAINT [DF_FileAsset_scan_status] DEFAULT ('PENDING'), -- PENDING, CLEAN, REJECTED or ERROR.
        [lifecycle_status] varchar(20) NOT NULL CONSTRAINT [DF_FileAsset_lifecycle_status] DEFAULT ('UPLOADING'), -- UPLOADING, AVAILABLE, QUARANTINED, DELETED or EXPIRED.
        [expires_at] datetimeoffset(7) NULL, -- Purpose policy or orphan-upload purge time.
        [deleted_at] datetimeoffset(7) NULL, -- Deletion completion time.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_FileAsset_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_FileAsset_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_FileAsset_] PRIMARY KEY ([file_asset_id])
    );
END;
GO

-- storage.FileAssetLink: Association between a FileAsset and an authorized product resource.
IF OBJECT_ID(N'[storage].[FileAssetLink]', N'U') IS NULL
BEGIN
    CREATE TABLE [storage].[FileAssetLink] (
        [file_asset_link_id] bigint IDENTITY(1,1) NOT NULL, -- Association identifier.
        [file_asset_id] varchar(64) NOT NULL, -- FK storage.FileAsset.
        [resource_type] varchar(32) NOT NULL, -- MESSAGE, MEMBER_VERIFICATION, PRIVACY_REQUEST or EVALUATION_RUN.
        [resource_id] varchar(64) NOT NULL, -- Authorized domain resource identifier.
        [relationship_type] varchar(32) NOT NULL CONSTRAINT [DF_FileAssetLink_relationship_type] DEFAULT ('PRIMARY'), -- PRIMARY, EVIDENCE, RESULT or REPORT.
        [linked_by] varchar(64) NULL, -- Member, administrator or service actor.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_FileAssetLink_created_at] DEFAULT (SYSUTCDATETIME()), -- Link creation time.
        [removed_at] datetimeoffset(7) NULL, -- Logical unlink time.
        CONSTRAINT [PK_FileAssetLink_] PRIMARY KEY ([file_asset_link_id])
    );
END;
GO

-- notification.NotificationPolicy: Versioned channel, frequency, quiet-hours, retry and expiry controls by notification purpose.
IF OBJECT_ID(N'[notification].[NotificationPolicy]', N'U') IS NULL
BEGIN
    CREATE TABLE [notification].[NotificationPolicy] (
        [notification_policy_id] bigint IDENTITY(1,1) NOT NULL, -- Immutable policy version identifier.
        [community_id] varchar(64) NULL, -- Optional community scope; null is platform default.
        [purpose_code] varchar(64) NOT NULL, -- MATCH, REQUEST, CHAT, EVENT, SAFETY or ACCOUNT.
        [channel] varchar(16) NOT NULL, -- PUSH, EMAIL or IN_APP.
        [policy_version] smallint NOT NULL CONSTRAINT [DF_NotificationPolicy_policy_version] DEFAULT (1), -- Monotonic version for scope/purpose/channel.
        [status] varchar(16) NOT NULL CONSTRAINT [DF_NotificationPolicy_status] DEFAULT ('DRAFT'), -- DRAFT, ACTIVE or RETIRED.
        [member_opt_out_allowed] bit NOT NULL CONSTRAINT [DF_NotificationPolicy_member_opt_out_allowed] DEFAULT (1), -- Whether member preference may disable this notification.
        [quiet_hours_behavior] varchar(16) NOT NULL CONSTRAINT [DF_NotificationPolicy_quiet_hours_behavior] DEFAULT ('DEFER'), -- DEFER, SUPPRESS or BYPASS.
        [dedupe_window_seconds] int NOT NULL CONSTRAINT [DF_NotificationPolicy_dedupe_window_seconds] DEFAULT (300), -- Duplicate suppression window for the same dedupe key.
        [max_per_hour] smallint NOT NULL CONSTRAINT [DF_NotificationPolicy_max_per_hour] DEFAULT (6), -- Maximum queued/sent notifications per member and policy each hour.
        [max_per_day] smallint NOT NULL CONSTRAINT [DF_NotificationPolicy_max_per_day] DEFAULT (30), -- Maximum queued/sent notifications per member and policy each day.
        [max_attempts] smallint NOT NULL CONSTRAINT [DF_NotificationPolicy_max_attempts] DEFAULT (3), -- Bounded provider delivery attempts.
        [retry_schedule_seconds] varchar(128) NOT NULL CONSTRAINT [DF_NotificationPolicy_retry_schedule_seconds] DEFAULT ('60,300,1800'), -- Validated comma-separated retry delays.
        [ttl_minutes] int NOT NULL CONSTRAINT [DF_NotificationPolicy_ttl_minutes] DEFAULT (1440), -- Notification expiry after initial eligibility.
        [effective_from] datetimeoffset(7) NOT NULL, -- Start of policy applicability.
        [effective_to] datetimeoffset(7) NULL, -- Optional retirement time.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NotificationPolicy_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NotificationPolicy_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_NotificationPolicy_] PRIMARY KEY ([notification_policy_id])
    );
END;
GO

-- notification.NotificationPreference: Member channel, quiet hours and purpose preferences.
IF OBJECT_ID(N'[notification].[NotificationPreference]', N'U') IS NULL
BEGIN
    CREATE TABLE [notification].[NotificationPreference] (
        [member_id] varchar(64) NOT NULL, -- FK Member.
        [purpose_code] varchar(64) NOT NULL, -- MATCH, REQUEST, CHAT, EVENT, SAFETY or ACCOUNT.
        [push_enabled] bit NOT NULL CONSTRAINT [DF_NotificationPreference_push_enabled] DEFAULT (1), -- Push channel preference.
        [email_enabled] bit NOT NULL CONSTRAINT [DF_NotificationPreference_email_enabled] DEFAULT (0), -- Email channel preference.
        [quiet_start_local] time NULL, -- Optional local quiet start.
        [quiet_end_local] time NULL, -- Optional local quiet end.
        [timezone_id] varchar(64) NULL, -- Required when quiet hours set.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NotificationPreference_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NotificationPreference_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_NotificationPreference_] PRIMARY KEY ([member_id], [purpose_code])
    );
END;
GO

-- notification.PushToken: Provider push token mapped to a registered device.
IF OBJECT_ID(N'[notification].[PushToken]', N'U') IS NULL
BEGIN
    CREATE TABLE [notification].[PushToken] (
        [push_token_id] bigint IDENTITY(1,1) NOT NULL, -- Internal key.
        [device_id] varchar(64) NOT NULL, -- FK MemberDevice.
        [provider] varchar(24) NOT NULL, -- APNS or FCM.
        [token_ciphertext] varbinary(max) NOT NULL, -- Encrypted/tokenized push token.
        [status] varchar(16) NOT NULL CONSTRAINT [DF_PushToken_status] DEFAULT ('ACTIVE'), -- ACTIVE or INVALID.
        [last_success_at] datetimeoffset(7) NULL, -- Last accepted delivery.
        [invalidated_at] datetimeoffset(7) NULL, -- Provider rejection/revocation.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_PushToken_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_PushToken_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        [token_fingerprint] char(64) NOT NULL, -- Stable SHA-256 fingerprint supplied by the service for uniqueness without indexing ciphertext.
        CONSTRAINT [PK_PushToken_] PRIMARY KEY ([push_token_id])
    );
END;
GO

-- notification.Notification: Policy-resolved, rate-limited delivery intent and aggregate outcome.
IF OBJECT_ID(N'[notification].[Notification]', N'U') IS NULL
BEGIN
    CREATE TABLE [notification].[Notification] (
        [notification_id] varchar(64) NOT NULL, -- Delivery identifier.
        [member_id] varchar(64) NOT NULL, -- Recipient.
        [notification_policy_id] bigint NOT NULL, -- Immutable NotificationPolicy version applied.
        [event_matching_policy_id] bigint NULL, -- EventMatchingPolicy applied to an event match alert.
        [purpose_code] varchar(64) NOT NULL, -- Notification purpose.
        [channel] varchar(16) NOT NULL, -- Resolved PUSH, EMAIL or IN_APP channel.
        [resource_type] varchar(32) NULL, -- MATCH, REQUEST, MESSAGE, EVENT.
        [resource_id] varchar(64) NULL, -- Deep-link resource.
        [template_code] varchar(64) NOT NULL, -- Versioned content template.
        [dedupe_key] varchar(160) NOT NULL, -- Stable purpose/member/resource key used for duplicate suppression.
        [dedupe_bucket_start] datetimeoffset(7) NOT NULL, -- Start of the policy-derived deduplication window.
        [source_confidence] decimal(6,5) NULL, -- Match confidence captured when threshold-based notification is used.
        [context_id] varchar(64) NULL, -- Event ID or GENERAL context used for event-lifetime caps.
        [status] varchar(20) NOT NULL CONSTRAINT [DF_Notification_status] DEFAULT ('PENDING'), -- PENDING, SENT, DELIVERED, FAILED, SUPPRESSED.
        [scheduled_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Notification_scheduled_at] DEFAULT (SYSUTCDATETIME()), -- Quiet-hours-aware schedule.
        [expires_at] datetimeoffset(7) NOT NULL, -- Policy-calculated time after which delivery is suppressed.
        [attempt_count] smallint NOT NULL CONSTRAINT [DF_Notification_attempt_count] DEFAULT (0), -- Aggregate count of append-only delivery attempts.
        [sent_at] datetimeoffset(7) NULL, -- Provider acceptance time.
        [delivered_at] datetimeoffset(7) NULL, -- Provider delivery acknowledgment when available.
        [suppression_reason] varchar(64) NULL, -- OPT_OUT, QUIET_HOURS, RATE_LIMIT, DUPLICATE, EXPIRED, BELOW_THRESHOLD or POLICY.
        [failure_code] varchar(64) NULL, -- Sanitized provider failure.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Notification_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_Notification_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_Notification_] PRIMARY KEY ([notification_id])
    );
END;
GO

-- notification.NotificationDeliveryAttempt: Append-only provider attempt and acknowledgment history.
IF OBJECT_ID(N'[notification].[NotificationDeliveryAttempt]', N'U') IS NULL
BEGIN
    CREATE TABLE [notification].[NotificationDeliveryAttempt] (
        [delivery_attempt_id] bigint IDENTITY(1,1) NOT NULL, -- Attempt identifier.
        [notification_id] varchar(64) NOT NULL, -- FK Notification.
        [attempt_number] smallint NOT NULL, -- One-based attempt number.
        [provider] varchar(32) NOT NULL, -- APNS, FCM, EMAIL_PROVIDER or IN_APP.
        [push_token_id] bigint NULL, -- PushToken used; null for non-push channels.
        [provider_message_id] nvarchar(256) NULL, -- Provider correlation ID; never a credential.
        [status] varchar(20) NOT NULL CONSTRAINT [DF_NotificationDeliveryAttempt_status] DEFAULT ('STARTED'), -- STARTED, ACCEPTED, DELIVERED, FAILED or EXPIRED.
        [attempted_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NotificationDeliveryAttempt_attempted_at] DEFAULT (SYSUTCDATETIME()), -- Attempt start time.
        [acknowledged_at] datetimeoffset(7) NULL, -- Provider acknowledgment time.
        [next_attempt_at] datetimeoffset(7) NULL, -- Next policy-derived retry time.
        [duration_ms] int NULL, -- Provider request duration.
        [failure_code] varchar(64) NULL, -- Sanitized failure category.
        CONSTRAINT [PK_NotificationDeliveryAttempt_] PRIMARY KEY ([delivery_attempt_id])
    );
END;
GO

-- nlp.NlpIntent: Current WANT/OFFER text and structured matching metadata.
IF OBJECT_ID(N'[nlp].[NlpIntent]', N'U') IS NULL
BEGIN
    CREATE TABLE [nlp].[NlpIntent] (
        [intent_id] varchar(64) NOT NULL, -- Matches existing API contract.
        [member_id] varchar(64) NOT NULL, -- Authoritative FK iam.Member.
        [context_id] varchar(64) NOT NULL, -- Event ID or GENERAL context.
        [intent_type] varchar(16) NOT NULL, -- WANT or OFFER.
        [original_text] nvarchar(4000) NOT NULL, -- Member-authored display text.
        [normalized_text] nvarchar(4000) NOT NULL, -- PII-minimized normalization.
        [normalized_hash] char(64) NOT NULL, -- Content hash for idempotent embedding.
        [language_code] varchar(16) NOT NULL CONSTRAINT [DF_NlpIntent_language_code] DEFAULT ('en'), -- Detected/approved language.
        [contains_pii] bit NOT NULL CONSTRAINT [DF_NlpIntent_contains_pii] DEFAULT (0), -- Preprocessing signal.
        [status] varchar(32) NOT NULL CONSTRAINT [DF_NlpIntent_status] DEFAULT ('PROCESSING'), -- PROCESSING, MATCH_READY, FAILED, INACTIVE.
        [category] nvarchar(128) NULL, -- Structured category.
        [industry] nvarchar(128) NULL, -- Structured industry.
        [geography] nvarchar(128) NULL, -- Business geography, not live location.
        [expires_at] datetimeoffset(7) NOT NULL, -- Freshness/eligibility expiry.
        [preprocessing_version] varchar(128) NOT NULL, -- Normalizer version.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NlpIntent_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NlpIntent_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_NlpIntent_] PRIMARY KEY ([intent_id])
    );
END;
GO

-- nlp.NlpEmbedding: Versioned vector for a normalized intent.
IF OBJECT_ID(N'[nlp].[NlpEmbedding]', N'U') IS NULL
BEGIN
    CREATE TABLE [nlp].[NlpEmbedding] (
        [intent_id] varchar(64) NOT NULL, -- FK NlpIntent.
        [model_version] varchar(128) NOT NULL, -- FK NlpModelVersion.
        [dimensions] int NOT NULL, -- Vector dimensions.
        [normalized_hash] char(64) NOT NULL, -- Text version embedded.
        [embedding] varbinary(max) NOT NULL, -- Existing varbinary baseline; native vector after target validation.
        [status] varchar(20) NOT NULL CONSTRAINT [DF_NlpEmbedding_status] DEFAULT ('ACTIVE'), -- ACTIVE, SUPERSEDED, FAILED.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NlpEmbedding_created_at] DEFAULT (SYSUTCDATETIME()), -- Creation time.
        CONSTRAINT [PK_NlpEmbedding_] PRIMARY KEY ([intent_id], [model_version])
    );
END;
GO

-- nlp.NlpModelVersion: Embedding provider/deployment and preprocessing compatibility.
IF OBJECT_ID(N'[nlp].[NlpModelVersion]', N'U') IS NULL
BEGIN
    CREATE TABLE [nlp].[NlpModelVersion] (
        [model_version] varchar(128) NOT NULL, -- Stable version.
        [provider] varchar(64) NOT NULL, -- Approved provider.
        [deployment_name] varchar(128) NOT NULL, -- Configuration reference, not secret.
        [dimensions] int NOT NULL, -- Expected vector length.
        [preprocessing_version] varchar(128) NOT NULL, -- Compatible preprocessing.
        [status] varchar(20) NOT NULL CONSTRAINT [DF_NlpModelVersion_status] DEFAULT ('CANDIDATE'), -- CANDIDATE, ACTIVE, RETIRED, ROLLED_BACK.
        [activated_at] datetimeoffset(7) NULL, -- Promotion time.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NlpModelVersion_created_at] DEFAULT (SYSUTCDATETIME()), -- Registration time.
        CONSTRAINT [PK_NlpModelVersion_] PRIMARY KEY ([model_version])
    );
END;
GO

-- nlp.NlpRankingConfig: Versioned ranking weights, threshold and policy switches.
IF OBJECT_ID(N'[nlp].[NlpRankingConfig]', N'U') IS NULL
BEGIN
    CREATE TABLE [nlp].[NlpRankingConfig] (
        [ranking_version] varchar(128) NOT NULL, -- Stable configuration version.
        [semantic_weight] decimal(6,5) NOT NULL CONSTRAINT [DF_NlpRankingConfig_semantic_weight] DEFAULT (0.40), -- Semantic/reciprocal weight.
        [category_weight] decimal(6,5) NOT NULL CONSTRAINT [DF_NlpRankingConfig_category_weight] DEFAULT (0.25), -- Category compatibility.
        [industry_weight] decimal(6,5) NOT NULL CONSTRAINT [DF_NlpRankingConfig_industry_weight] DEFAULT (0.15), -- Industry compatibility.
        [geography_weight] decimal(6,5) NOT NULL CONSTRAINT [DF_NlpRankingConfig_geography_weight] DEFAULT (0.10), -- Business geography fit.
        [freshness_weight] decimal(6,5) NOT NULL CONSTRAINT [DF_NlpRankingConfig_freshness_weight] DEFAULT (0.10), -- Intent freshness.
        [event_weight] decimal(6,5) NOT NULL CONSTRAINT [DF_NlpRankingConfig_event_weight] DEFAULT (0), -- Optional event context after evaluation.
        [threshold] decimal(6,5) NOT NULL CONSTRAINT [DF_NlpRankingConfig_threshold] DEFAULT (0.35), -- Display threshold.
        [active_from] datetimeoffset(7) NOT NULL, -- Effective time.
        [active_to] datetimeoffset(7) NULL, -- Retirement time.
        [config_json] nvarchar(2000) NULL, -- Bounded extra rule settings.
        CONSTRAINT [PK_NlpRankingConfig_] PRIMARY KEY ([ranking_version])
    );
END;
GO

-- nlp.NlpProcessingJob: Intent embedding and re-embedding retry state.
IF OBJECT_ID(N'[nlp].[NlpProcessingJob]', N'U') IS NULL
BEGIN
    CREATE TABLE [nlp].[NlpProcessingJob] (
        [job_id] varchar(64) NOT NULL, -- Job identifier.
        [intent_id] varchar(64) NOT NULL, -- Target intent.
        [job_type] varchar(24) NOT NULL CONSTRAINT [DF_NlpProcessingJob_job_type] DEFAULT ('EMBED'), -- EMBED or REEMBED. Normalization is synchronous for MVP.
        [status] varchar(20) NOT NULL CONSTRAINT [DF_NlpProcessingJob_status] DEFAULT ('PENDING'), -- PENDING, RUNNING, SUCCEEDED, FAILED, DEAD.
        [attempt_count] int NOT NULL CONSTRAINT [DF_NlpProcessingJob_attempt_count] DEFAULT (0), -- Bounded attempts.
        [available_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NlpProcessingJob_available_at] DEFAULT (SYSUTCDATETIME()), -- Retry schedule.
        [locked_until] datetimeoffset(7) NULL, -- Worker lease.
        [error_code] varchar(64) NULL, -- Sanitized failure code.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NlpProcessingJob_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NlpProcessingJob_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_NlpProcessingJob_] PRIMARY KEY ([job_id])
    );
END;
GO

-- nlp.MatchRequest: Idempotent match-search execution envelope.
IF OBJECT_ID(N'[nlp].[MatchRequest]', N'U') IS NULL
BEGIN
    CREATE TABLE [nlp].[MatchRequest] (
        [request_id] varchar(64) NOT NULL, -- Client/API idempotency key.
        [request_hash] char(64) NOT NULL, -- Canonical hash of matching inputs; detects idempotency-key reuse with different inputs.
        [requester_id] varchar(64) NOT NULL, -- Authenticated member.
        [intent_id] varchar(64) NOT NULL, -- Requester intent.
        [context_id] varchar(64) NOT NULL, -- Matching context.
        [language_code] varchar(16) NOT NULL CONSTRAINT [DF_MatchRequest_language_code] DEFAULT ('en'), -- Language snapshot used for this request.
        [requested_limit] smallint NOT NULL CONSTRAINT [DF_MatchRequest_requested_limit] DEFAULT (7), -- Allowed 3-7.
        [request_options_json] nvarchar(2000) NULL, -- Validated bounded options snapshot; no free-form secrets or raw provider payloads.
        [status] varchar(20) NOT NULL CONSTRAINT [DF_MatchRequest_status] DEFAULT ('PROCESSING'), -- PROCESSING, COMPLETED, FAILED.
        [preprocessing_version] varchar(128) NULL, -- Resolved synchronous normalization version.
        [model_version] varchar(128) NULL, -- Resolved model version.
        [ranking_version] varchar(128) NULL, -- Resolved ranking version.
        [ranking_threshold] decimal(6,5) NULL, -- Immutable threshold snapshot applied to this execution.
        [candidate_count] int NULL, -- Eligible bounded candidates examined.
        [completed_at] datetimeoffset(7) NULL, -- Completion time.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MatchRequest_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MatchRequest_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_MatchRequest_] PRIMARY KEY ([request_id])
    );
END;
GO

-- nlp.NlpMatchResult: Ranked, explained recommendation returned for one request.
IF OBJECT_ID(N'[nlp].[NlpMatchResult]', N'U') IS NULL
BEGIN
    CREATE TABLE [nlp].[NlpMatchResult] (
        [match_result_id] bigint IDENTITY(1,1) NOT NULL, -- Internal key.
        [request_id] varchar(64) NOT NULL, -- FK MatchRequest.
        [requester_id] varchar(64) NOT NULL, -- Requester.
        [candidate_id] varchar(64) NOT NULL, -- Candidate.
        [rank] smallint NOT NULL, -- 1-based result rank.
        [semantic_score] decimal(8,7) NOT NULL, -- Semantic score.
        [reciprocal_score] decimal(8,7) NULL, -- Bidirectional harmonic/approved score.
        [final_score] decimal(8,7) NOT NULL, -- Versioned final ranking score.
        [label] varchar(32) NOT NULL, -- STRONG_MATCH, PLAUSIBLE_MATCH, etc.
        [reason_codes] nvarchar(1000) NOT NULL, -- JSON array of approved codes.
        [reason_text] nvarchar(2000) NOT NULL, -- Deterministic explanation.
        [model_version] varchar(128) NOT NULL, -- Embedding version.
        [preprocessing_version] varchar(128) NOT NULL, -- Normalization version.
        [ranking_version] varchar(128) NOT NULL, -- Ranking configuration.
        [policy_status] varchar(24) NOT NULL CONSTRAINT [DF_NlpMatchResult_policy_status] DEFAULT ('ELIGIBLE'), -- ELIGIBLE or SUPPRESSED.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NlpMatchResult_created_at] DEFAULT (SYSUTCDATETIME()), -- Creation time.
        CONSTRAINT [PK_NlpMatchResult_] PRIMARY KEY ([match_result_id])
    );
END;
GO

-- nlp.NlpFeedback: Useful/not useful/inappropriate signal for recommendation quality.
IF OBJECT_ID(N'[nlp].[NlpFeedback]', N'U') IS NULL
BEGIN
    CREATE TABLE [nlp].[NlpFeedback] (
        [feedback_id] bigint IDENTITY(1,1) NOT NULL, -- Internal key.
        [supersedes_feedback_id] bigint NULL, -- Optional self-FK to the earlier feedback corrected by this row.
        [match_result_id] bigint NOT NULL, -- FK NlpMatchResult.
        [request_id] varchar(64) NOT NULL, -- Denormalized request for compatibility.
        [requester_id] varchar(64) NOT NULL, -- Authenticated feedback author.
        [candidate_id] varchar(64) NOT NULL, -- Candidate.
        [label] varchar(64) NOT NULL, -- USEFUL, NOT_USEFUL, INAPPROPRIATE.
        [reason_code] varchar(64) NULL, -- Controlled error category.
        [reason] nvarchar(1000) NULL, -- Optional free text, PII checked.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_NlpFeedback_created_at] DEFAULT (SYSUTCDATETIME()), -- Feedback time.
        CONSTRAINT [PK_NlpFeedback_] PRIMARY KEY ([feedback_id])
    );
END;
GO

-- nlp.MatchSuppression: Administrative or safety suppression independent of model score.
IF OBJECT_ID(N'[nlp].[MatchSuppression]', N'U') IS NULL
BEGIN
    CREATE TABLE [nlp].[MatchSuppression] (
        [suppression_id] bigint IDENTITY(1,1) NOT NULL, -- Internal key.
        [member_id] varchar(64) NULL, -- Affected member.
        [intent_id] varchar(64) NULL, -- Affected intent.
        [context_id] varchar(64) NULL, -- Optional context.
        [reason_code] varchar(64) NOT NULL, -- Controlled reason.
        [starts_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_MatchSuppression_starts_at] DEFAULT (SYSUTCDATETIME()), -- Effective time.
        [ends_at] datetimeoffset(7) NULL, -- Optional expiry.
        [created_by] varchar(64) NOT NULL, -- Administrator/service actor.
        CONSTRAINT [PK_MatchSuppression_] PRIMARY KEY ([suppression_id])
    );
END;
GO

-- nlp.EvaluationDataset: Versioned labelled-pair dataset metadata.
IF OBJECT_ID(N'[nlp].[EvaluationDataset]', N'U') IS NULL
BEGIN
    CREATE TABLE [nlp].[EvaluationDataset] (
        [dataset_id] varchar(64) NOT NULL, -- Dataset version ID.
        [name] nvarchar(200) NOT NULL, -- Display name.
        [version] varchar(32) NOT NULL, -- Immutable version.
        [description] nvarchar(1000) NULL, -- Sampling/labeling notes.
        [source_policy] nvarchar(500) NOT NULL, -- De-identification/provenance statement.
        [status] varchar(20) NOT NULL CONSTRAINT [DF_EvaluationDataset_status] DEFAULT ('DRAFT'), -- DRAFT, APPROVED, RETIRED.
        [approved_by] varchar(64) NULL, -- Evaluator/admin.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_EvaluationDataset_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_EvaluationDataset_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_EvaluationDataset_] PRIMARY KEY ([dataset_id])
    );
END;
GO

-- nlp.EvaluationPair: One labelled reciprocal matching example.
IF OBJECT_ID(N'[nlp].[EvaluationPair]', N'U') IS NULL
BEGIN
    CREATE TABLE [nlp].[EvaluationPair] (
        [evaluation_pair_id] bigint IDENTITY(1,1) NOT NULL, -- Pair identifier.
        [dataset_id] varchar(64) NOT NULL, -- FK EvaluationDataset.
        [requester_intent_text] nvarchar(4000) NOT NULL, -- De-identified requester sample.
        [candidate_intent_text] nvarchar(4000) NOT NULL, -- De-identified candidate sample.
        [structured_features_json] nvarchar(2000) NULL, -- Category/industry/geography features.
        [gold_label] varchar(32) NOT NULL, -- STRONG, PLAUSIBLE, WEAK, NONE, UNSAFE.
        [split] varchar(16) NOT NULL, -- TRAIN, VALIDATION or TEST.
        [organization_group] varchar(64) NULL, -- Leakage-prevention grouping, pseudonymous.
        [label_reason] nvarchar(1000) NULL, -- Evaluator rationale.
        CONSTRAINT [PK_EvaluationPair_] PRIMARY KEY ([evaluation_pair_id])
    );
END;
GO

-- nlp.EvaluationRun: Reproducible quality evaluation output.
IF OBJECT_ID(N'[nlp].[EvaluationRun]', N'U') IS NULL
BEGIN
    CREATE TABLE [nlp].[EvaluationRun] (
        [evaluation_run_id] varchar(64) NOT NULL, -- Run identifier.
        [dataset_id] varchar(64) NOT NULL, -- Dataset version.
        [model_version] varchar(128) NOT NULL, -- Model under test.
        [ranking_version] varchar(128) NOT NULL, -- Ranking config.
        [status] varchar(20) NOT NULL CONSTRAINT [DF_EvaluationRun_status] DEFAULT ('RUNNING'), -- RUNNING, PASSED, FAILED, ERROR.
        [metrics_json] nvarchar(max) NULL, -- Precision@5, Recall@20, reciprocal precision, coverage.
        [error_report_blob_path] nvarchar(1024) NULL, -- Private report artifact.
        [started_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_EvaluationRun_started_at] DEFAULT (SYSUTCDATETIME()), -- Run start.
        [completed_at] datetimeoffset(7) NULL, -- Run completion.
        CONSTRAINT [PK_EvaluationRun_] PRIMARY KEY ([evaluation_run_id])
    );
END;
GO

-- moderation.ModerationCase: Unified case for member reports, content flags and account review.
IF OBJECT_ID(N'[moderation].[ModerationCase]', N'U') IS NULL
BEGIN
    CREATE TABLE [moderation].[ModerationCase] (
        [moderation_case_id] varchar(64) NOT NULL, -- Case identifier.
        [source_type] varchar(32) NOT NULL, -- MEMBER_REPORT, AUTO_SCAN, ADMIN_REVIEW.
        [source_id] varchar(64) NULL, -- Source record identifier.
        [subject_member_id] varchar(64) NULL, -- Member under review.
        [resource_type] varchar(32) NULL, -- PROFILE, MESSAGE, ATTACHMENT, INTENT.
        [resource_id] varchar(64) NULL, -- Reviewed resource.
        [priority] varchar(16) NOT NULL CONSTRAINT [DF_ModerationCase_priority] DEFAULT ('NORMAL'), -- LOW, NORMAL, HIGH, URGENT.
        [status] varchar(24) NOT NULL CONSTRAINT [DF_ModerationCase_status] DEFAULT ('OPEN'), -- OPEN, TRIAGED, ACTIONED, CLOSED.
        [assigned_to] varchar(64) NULL, -- Moderator.
        [closed_at] datetimeoffset(7) NULL, -- Closure time.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_ModerationCase_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_ModerationCase_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_ModerationCase_] PRIMARY KEY ([moderation_case_id])
    );
END;
GO

-- moderation.ModerationAction: Append-only action taken within a moderation case.
IF OBJECT_ID(N'[moderation].[ModerationAction]', N'U') IS NULL
BEGIN
    CREATE TABLE [moderation].[ModerationAction] (
        [moderation_action_id] bigint IDENTITY(1,1) NOT NULL, -- Action identifier.
        [moderation_case_id] varchar(64) NOT NULL, -- FK ModerationCase.
        [actor_member_id] varchar(64) NOT NULL, -- Moderator/admin.
        [action_type] varchar(64) NOT NULL, -- WARN, HIDE, SUSPEND, REJECT_FILE, CLOSE, etc.
        [reason_code] varchar(64) NOT NULL, -- Controlled reason.
        [notes] nvarchar(2000) NULL, -- Restricted case notes.
        [effective_until] datetimeoffset(7) NULL, -- Temporary action expiry.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_ModerationAction_created_at] DEFAULT (SYSUTCDATETIME()), -- Action time.
        CONSTRAINT [PK_ModerationAction_] PRIMARY KEY ([moderation_action_id])
    );
END;
GO

-- moderation.ContentRule: Versioned blocked-content and moderation configuration.
IF OBJECT_ID(N'[moderation].[ContentRule]', N'U') IS NULL
BEGIN
    CREATE TABLE [moderation].[ContentRule] (
        [content_rule_id] varchar(64) NOT NULL, -- Rule ID.
        [rule_type] varchar(32) NOT NULL, -- FILE_TYPE, TERM, RATE, POLICY.
        [version] varchar(32) NOT NULL, -- Rule version.
        [config_json] nvarchar(max) NOT NULL, -- Validated rule configuration.
        [status] varchar(16) NOT NULL CONSTRAINT [DF_ContentRule_status] DEFAULT ('DRAFT'), -- DRAFT, ACTIVE, RETIRED.
        [active_from] datetimeoffset(7) NULL, -- Activation time.
        [created_by] varchar(64) NOT NULL, -- Administrator.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_ContentRule_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_ContentRule_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_ContentRule_] PRIMARY KEY ([content_rule_id])
    );
END;
GO

-- moderation.ContentScan: Malware/content scan result for files or text resources.
IF OBJECT_ID(N'[moderation].[ContentScan]', N'U') IS NULL
BEGIN
    CREATE TABLE [moderation].[ContentScan] (
        [content_scan_id] bigint IDENTITY(1,1) NOT NULL, -- Scan record.
        [resource_type] varchar(32) NOT NULL, -- FILE_ASSET, PROFILE, INTENT or MESSAGE.
        [resource_id] varchar(64) NOT NULL, -- Target object.
        [scanner] varchar(64) NOT NULL, -- Scanner/provider ID.
        [scanner_version] varchar(64) NULL, -- Engine/signature version.
        [result] varchar(24) NOT NULL, -- CLEAN, FLAGGED, MALICIOUS, ERROR.
        [reason_codes] nvarchar(1000) NULL, -- Sanitized JSON reason codes.
        [scanned_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_ContentScan_scanned_at] DEFAULT (SYSUTCDATETIME()), -- Scan time.
        CONSTRAINT [PK_ContentScan_] PRIMARY KEY ([content_scan_id])
    );
END;
GO

-- ops.SyncChange: Authorization-safe mobile delta feed and tombstone ledger.
IF OBJECT_ID(N'[ops].[SyncChange]', N'U') IS NULL
BEGIN
    CREATE TABLE [ops].[SyncChange] (
        [sync_sequence] bigint NOT NULL CONSTRAINT [DF_SyncChange_sync_sequence] DEFAULT (NEXT VALUE FOR ops.SyncChangeSequence), -- Monotonic sync API cursor.
        [community_id] varchar(64) NOT NULL, -- FK core.Community.
        [member_scope_id] varchar(64) NULL, -- Optional member-specific visibility scope.
        [resource_type] varchar(32) NOT NULL, -- PROFILE, MATCH, REQUEST, CONVERSATION, MESSAGE or NOTIFICATION.
        [resource_id] varchar(64) NOT NULL, -- Changed resource identifier.
        [change_type] varchar(16) NOT NULL, -- UPSERT or DELETE.
        [resource_version] binary(8) NULL, -- Source rowversion snapshot where available.
        [payload_json] nvarchar(max) NULL, -- Minimum authorization-safe read-model payload; null for protected tombstones.
        [occurred_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_SyncChange_occurred_at] DEFAULT (SYSUTCDATETIME()), -- Authoritative change time.
        [expires_at] datetimeoffset(7) NOT NULL, -- Earliest purge time.
        CONSTRAINT [PK_SyncChange_] PRIMARY KEY ([sync_sequence])
    );
END;
GO

-- ops.RetentionPolicy: Versioned retention and disposition rules for product data classes.
IF OBJECT_ID(N'[ops].[RetentionPolicy]', N'U') IS NULL
BEGIN
    CREATE TABLE [ops].[RetentionPolicy] (
        [retention_policy_id] bigint IDENTITY(1,1) NOT NULL, -- Immutable policy version identifier.
        [resource_type] varchar(64) NOT NULL, -- Governed product data class.
        [policy_version] smallint NOT NULL CONSTRAINT [DF_RetentionPolicy_policy_version] DEFAULT (1), -- Monotonic version per resource type.
        [status] varchar(16) NOT NULL CONSTRAINT [DF_RetentionPolicy_status] DEFAULT ('DRAFT'), -- DRAFT, ACTIVE or RETIRED.
        [retention_days] int NOT NULL, -- Approved retention duration.
        [disposition_action] varchar(20) NOT NULL, -- DELETE, ANONYMIZE or ARCHIVE.
        [legal_hold_supported] bit NOT NULL CONSTRAINT [DF_RetentionPolicy_legal_hold_supported] DEFAULT (1), -- Whether disposition can be delayed by approved legal hold.
        [effective_from] datetimeoffset(7) NOT NULL, -- Activation time.
        [effective_to] datetimeoffset(7) NULL, -- Optional retirement time.
        [approved_by] varchar(64) NULL, -- Approving privacy/security administrator.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_RetentionPolicy_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_RetentionPolicy_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_RetentionPolicy_] PRIMARY KEY ([retention_policy_id])
    );
END;
GO

-- ops.RetentionExecution: Auditable execution result for one retention policy batch or resource.
IF OBJECT_ID(N'[ops].[RetentionExecution]', N'U') IS NULL
BEGIN
    CREATE TABLE [ops].[RetentionExecution] (
        [retention_execution_id] varchar(64) NOT NULL, -- Execution identifier.
        [retention_policy_id] bigint NOT NULL, -- Immutable policy version applied.
        [scope_start] datetimeoffset(7) NOT NULL, -- Inclusive evaluation window start.
        [scope_end] datetimeoffset(7) NOT NULL, -- Exclusive evaluation window end.
        [status] varchar(20) NOT NULL CONSTRAINT [DF_RetentionExecution_status] DEFAULT ('RUNNING'), -- RUNNING, SUCCEEDED, PARTIAL or FAILED.
        [examined_count] bigint NOT NULL CONSTRAINT [DF_RetentionExecution_examined_count] DEFAULT (0), -- Rows/resources evaluated.
        [disposed_count] bigint NOT NULL CONSTRAINT [DF_RetentionExecution_disposed_count] DEFAULT (0), -- Rows/resources disposed.
        [skipped_hold_count] bigint NOT NULL CONSTRAINT [DF_RetentionExecution_skipped_hold_count] DEFAULT (0), -- Resources skipped due to legal hold.
        [evidence_hash] char(64) NULL, -- Hash of execution manifest/log evidence.
        [started_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_RetentionExecution_started_at] DEFAULT (SYSUTCDATETIME()), -- Execution start.
        [completed_at] datetimeoffset(7) NULL, -- Terminal completion time.
        [error_code] varchar(64) NULL, -- Sanitized terminal error.
        CONSTRAINT [PK_RetentionExecution_] PRIMARY KEY ([retention_execution_id])
    );
END;
GO

-- ops.OutboxEvent: Transactional event publication without dual-write loss.
IF OBJECT_ID(N'[ops].[OutboxEvent]', N'U') IS NULL
BEGIN
    CREATE TABLE [ops].[OutboxEvent] (
        [outbox_event_id] varchar(64) NOT NULL, -- Event ID/idempotency token.
        [aggregate_type] varchar(64) NOT NULL, -- MEMBER, CONNECTION, MESSAGE, INTENT.
        [aggregate_id] varchar(64) NOT NULL, -- Source aggregate.
        [event_type] varchar(128) NOT NULL, -- Versioned event name.
        [payload_json] nvarchar(max) NOT NULL, -- Minimal event payload; avoid raw content.
        [occurred_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_OutboxEvent_occurred_at] DEFAULT (SYSUTCDATETIME()), -- Business event time.
        [published_at] datetimeoffset(7) NULL, -- Successful publish time.
        [attempt_count] int NOT NULL CONSTRAINT [DF_OutboxEvent_attempt_count] DEFAULT (0), -- Publish attempts.
        [next_attempt_at] datetimeoffset(7) NULL, -- Retry schedule.
        CONSTRAINT [PK_OutboxEvent_] PRIMARY KEY ([outbox_event_id])
    );
END;
GO

-- ops.IdempotencyRecord: Safe replay of mobile/API commands.
IF OBJECT_ID(N'[ops].[IdempotencyRecord]', N'U') IS NULL
BEGIN
    CREATE TABLE [ops].[IdempotencyRecord] (
        [scope] varchar(64) NOT NULL, -- API/operation scope.
        [idempotency_key] varchar(128) NOT NULL, -- Client key.
        [actor_id] varchar(64) NOT NULL, -- Authenticated member/service.
        [request_hash] char(64) NOT NULL, -- Detect key reuse with different body.
        [status_code] smallint NULL, -- Cached response status.
        [response_ref] nvarchar(1000) NULL, -- Bounded response or resource reference.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_IdempotencyRecord_created_at] DEFAULT (SYSUTCDATETIME()), -- First request.
        [expires_at] datetimeoffset(7) NOT NULL, -- Purge time.
        CONSTRAINT [PK_IdempotencyRecord_] PRIMARY KEY ([scope], [idempotency_key])
    );
END;
GO

-- ops.BackgroundJob: Non-NLP background task lifecycle.
IF OBJECT_ID(N'[ops].[BackgroundJob]', N'U') IS NULL
BEGIN
    CREATE TABLE [ops].[BackgroundJob] (
        [background_job_id] varchar(64) NOT NULL, -- Job ID.
        [job_type] varchar(64) NOT NULL, -- SCAN_FILE, SEND_NOTIFICATION, PURGE_PRESENCE, etc.
        [resource_type] varchar(32) NULL, -- Target type.
        [resource_id] varchar(64) NULL, -- Target ID.
        [payload_json] nvarchar(2000) NULL, -- Minimal validated payload.
        [status] varchar(20) NOT NULL CONSTRAINT [DF_BackgroundJob_status] DEFAULT ('PENDING'), -- PENDING, RUNNING, SUCCEEDED, FAILED, DEAD.
        [attempt_count] int NOT NULL CONSTRAINT [DF_BackgroundJob_attempt_count] DEFAULT (0), -- Attempts.
        [available_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_BackgroundJob_available_at] DEFAULT (SYSUTCDATETIME()), -- Schedule/retry time.
        [error_code] varchar(64) NULL, -- Sanitized failure.
        [created_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_BackgroundJob_created_at] DEFAULT (SYSUTCDATETIME()), -- UTC creation time.
        [updated_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_BackgroundJob_updated_at] DEFAULT (SYSUTCDATETIME()), -- UTC last material update time.
        [row_version] rowversion NOT NULL, -- Optimistic concurrency token; never client supplied.
        CONSTRAINT [PK_BackgroundJob_] PRIMARY KEY ([background_job_id])
    );
END;
GO

-- ops.AuditEvent: Append-only evidence of sensitive/security/admin actions.
IF OBJECT_ID(N'[ops].[AuditEvent]', N'U') IS NULL
BEGIN
    CREATE TABLE [ops].[AuditEvent] (
        [audit_event_id] bigint IDENTITY(1,1) NOT NULL, -- Monotonic audit key.
        [actor_type] varchar(24) NOT NULL, -- MEMBER, ADMIN, SERVICE, SYSTEM.
        [actor_id] varchar(64) NULL, -- Pseudonymous/service identity.
        [action] varchar(128) NOT NULL, -- Versioned action code.
        [resource_type] varchar(64) NULL, -- Affected type.
        [resource_id] varchar(64) NULL, -- Affected ID.
        [outcome] varchar(16) NOT NULL, -- SUCCESS or DENIED/FAILED.
        [correlation_id] varchar(64) NOT NULL, -- End-to-end trace ID.
        [metadata_json] nvarchar(2000) NULL, -- Allowlisted, content-free metadata.
        [occurred_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_AuditEvent_occurred_at] DEFAULT (SYSUTCDATETIME()), -- Event time.
        CONSTRAINT [PK_AuditEvent_] PRIMARY KEY ([audit_event_id])
    );
END;
GO

-- analytics.ProductEvent: Privacy-safe product funnel and match-quality analytics.
IF OBJECT_ID(N'[analytics].[ProductEvent]', N'U') IS NULL
BEGIN
    CREATE TABLE [analytics].[ProductEvent] (
        [product_event_id] varchar(64) NOT NULL, -- Event ID.
        [event_name] varchar(128) NOT NULL, -- PROFILE_COMPLETED, MATCH_VIEWED, REQUEST_SENT, etc.
        [member_pseudonym] char(64) NULL, -- Environment-specific salted hash, not member_id.
        [community_id] varchar(64) NOT NULL, -- Aggregation boundary.
        [context_type] varchar(32) NULL, -- EVENT or GENERAL.
        [context_id] varchar(64) NULL, -- Allowed context reference.
        [properties_json] nvarchar(2000) NULL, -- Allowlisted non-content dimensions.
        [occurred_at] datetimeoffset(7) NOT NULL, -- Client/server event time.
        [received_at] datetimeoffset(7) NOT NULL CONSTRAINT [DF_ProductEvent_received_at] DEFAULT (SYSUTCDATETIME()), -- Server receipt time.
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

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberVerification_evidence_file_asset_id' AND parent_object_id = OBJECT_ID(N'[core].[MemberVerification]'))
    ALTER TABLE [core].[MemberVerification] WITH CHECK ADD CONSTRAINT [FK_MemberVerification_evidence_file_asset_id] FOREIGN KEY ([evidence_file_asset_id]) REFERENCES [storage].[FileAsset] ([file_asset_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MemberVerification_evidence_file_asset_id' AND is_not_trusted = 1)
    ALTER TABLE [core].[MemberVerification] WITH CHECK CHECK CONSTRAINT [FK_MemberVerification_evidence_file_asset_id];
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

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_PrivacyRequest_result_file_asset_id' AND parent_object_id = OBJECT_ID(N'[consent].[PrivacyRequest]'))
    ALTER TABLE [consent].[PrivacyRequest] WITH CHECK ADD CONSTRAINT [FK_PrivacyRequest_result_file_asset_id] FOREIGN KEY ([result_file_asset_id]) REFERENCES [storage].[FileAsset] ([file_asset_id]);
GO
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_PrivacyRequest_result_file_asset_id' AND is_not_trusted = 1)
    ALTER TABLE [consent].[PrivacyRequest] WITH CHECK CHECK CONSTRAINT [FK_PrivacyRequest_result_file_asset_id];
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

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[iam].[MemberIdentity]') AND name = N'UX_MemberIdentity_ProviderSubjectHash')
    CREATE UNIQUE INDEX [UX_MemberIdentity_ProviderSubjectHash] ON [iam].[MemberIdentity] ([provider], [provider_subject_hash]);
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



IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[iam].[MemberRole]') AND name = N'IX_MemberRole_granted_by')
    CREATE INDEX [IX_MemberRole_granted_by] ON [iam].[MemberRole] ([granted_by]);
GO








IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[MemberVerification]') AND name = N'IX_MemberVerification_evidence_file_asset_id')
    CREATE INDEX [IX_MemberVerification_evidence_file_asset_id] ON [core].[MemberVerification] ([evidence_file_asset_id]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[MemberVerification]') AND name = N'IX_MemberVerification_reviewed_by')
    CREATE INDEX [IX_MemberVerification_reviewed_by] ON [core].[MemberVerification] ([reviewed_by]);
GO




IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[consent].[PrivacyRequest]') AND name = N'IX_PrivacyRequest_result_file_asset_id')
    CREATE INDEX [IX_PrivacyRequest_result_file_asset_id] ON [consent].[PrivacyRequest] ([result_file_asset_id]);
GO




IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[event].[LiveModeSession]') AND name = N'IX_LiveModeSession_consent_record_id')
    CREATE INDEX [IX_LiveModeSession_consent_record_id] ON [event].[LiveModeSession] ([consent_record_id]);
GO


IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[social].[ConnectionRequest]') AND name = N'IX_ConnectionRequest_match_result_id')
    CREATE INDEX [IX_ConnectionRequest_match_result_id] ON [social].[ConnectionRequest] ([match_result_id]);
GO



IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[social].[MemberReport]') AND name = N'IX_MemberReport_reporter_member_id')
    CREATE INDEX [IX_MemberReport_reporter_member_id] ON [social].[MemberReport] ([reporter_member_id]);
GO




IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[chat].[ConversationParticipant]') AND name = N'IX_ConversationParticipant_last_read_message_id')
    CREATE INDEX [IX_ConversationParticipant_last_read_message_id] ON [chat].[ConversationParticipant] ([last_read_message_id]);
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



IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[MatchSuppression]') AND name = N'IX_MatchSuppression_created_by')
    CREATE INDEX [IX_MatchSuppression_created_by] ON [nlp].[MatchSuppression] ([created_by]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[EvaluationDataset]') AND name = N'IX_EvaluationDataset_approved_by')
    CREATE INDEX [IX_EvaluationDataset_approved_by] ON [nlp].[EvaluationDataset] ([approved_by]);
GO




IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[EvaluationRun]') AND name = N'IX_EvaluationRun_ranking_version')
    CREATE INDEX [IX_EvaluationRun_ranking_version] ON [nlp].[EvaluationRun] ([ranking_version]);
GO


IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[moderation].[ModerationCase]') AND name = N'IX_ModerationCase_assigned_to')
    CREATE INDEX [IX_ModerationCase_assigned_to] ON [moderation].[ModerationCase] ([assigned_to]);
GO



IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[moderation].[ContentRule]') AND name = N'IX_ContentRule_created_by')
    CREATE INDEX [IX_ContentRule_created_by] ON [moderation].[ContentRule] ([created_by]);
GO


-- v2.3 cross-domain foreign keys.
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_RolePermission_role_code' AND parent_object_id = OBJECT_ID(N'[iam].[RolePermission]'))
    ALTER TABLE [iam].[RolePermission] WITH CHECK ADD CONSTRAINT [FK_RolePermission_role_code] FOREIGN KEY ([role_code]) REFERENCES [iam].[Role] ([role_code]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_RolePermission_permission_code' AND parent_object_id = OBJECT_ID(N'[iam].[RolePermission]'))
    ALTER TABLE [iam].[RolePermission] WITH CHECK ADD CONSTRAINT [FK_RolePermission_permission_code] FOREIGN KEY ([permission_code]) REFERENCES [iam].[Permission] ([permission_code]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_RolePermission_granted_by' AND parent_object_id = OBJECT_ID(N'[iam].[RolePermission]'))
    ALTER TABLE [iam].[RolePermission] WITH CHECK ADD CONSTRAINT [FK_RolePermission_granted_by] FOREIGN KEY ([granted_by]) REFERENCES [iam].[Member] ([member_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_AuthSession_member_id' AND parent_object_id = OBJECT_ID(N'[iam].[AuthSession]'))
    ALTER TABLE [iam].[AuthSession] WITH CHECK ADD CONSTRAINT [FK_AuthSession_member_id] FOREIGN KEY ([member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_AuthSession_device_id' AND parent_object_id = OBJECT_ID(N'[iam].[AuthSession]'))
    ALTER TABLE [iam].[AuthSession] WITH CHECK ADD CONSTRAINT [FK_AuthSession_device_id] FOREIGN KEY ([device_id]) REFERENCES [iam].[MemberDevice] ([device_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_PrivacyRequestTask_privacy_request_id' AND parent_object_id = OBJECT_ID(N'[consent].[PrivacyRequestTask]'))
    ALTER TABLE [consent].[PrivacyRequestTask] WITH CHECK ADD CONSTRAINT [FK_PrivacyRequestTask_privacy_request_id] FOREIGN KEY ([privacy_request_id]) REFERENCES [consent].[PrivacyRequest] ([privacy_request_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_FileAsset_community_id' AND parent_object_id = OBJECT_ID(N'[storage].[FileAsset]'))
    ALTER TABLE [storage].[FileAsset] WITH CHECK ADD CONSTRAINT [FK_FileAsset_community_id] FOREIGN KEY ([community_id]) REFERENCES [core].[Community] ([community_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_FileAsset_owner_member_id' AND parent_object_id = OBJECT_ID(N'[storage].[FileAsset]'))
    ALTER TABLE [storage].[FileAsset] WITH CHECK ADD CONSTRAINT [FK_FileAsset_owner_member_id] FOREIGN KEY ([owner_member_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_FileAssetLink_file_asset_id' AND parent_object_id = OBJECT_ID(N'[storage].[FileAssetLink]'))
    ALTER TABLE [storage].[FileAssetLink] WITH CHECK ADD CONSTRAINT [FK_FileAssetLink_file_asset_id] FOREIGN KEY ([file_asset_id]) REFERENCES [storage].[FileAsset] ([file_asset_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_FileAssetLink_linked_by' AND parent_object_id = OBJECT_ID(N'[storage].[FileAssetLink]'))
    ALTER TABLE [storage].[FileAssetLink] WITH CHECK ADD CONSTRAINT [FK_FileAssetLink_linked_by] FOREIGN KEY ([linked_by]) REFERENCES [iam].[Member] ([member_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SyncChange_community_id' AND parent_object_id = OBJECT_ID(N'[ops].[SyncChange]'))
    ALTER TABLE [ops].[SyncChange] WITH CHECK ADD CONSTRAINT [FK_SyncChange_community_id] FOREIGN KEY ([community_id]) REFERENCES [core].[Community] ([community_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SyncChange_member_scope_id' AND parent_object_id = OBJECT_ID(N'[ops].[SyncChange]'))
    ALTER TABLE [ops].[SyncChange] WITH CHECK ADD CONSTRAINT [FK_SyncChange_member_scope_id] FOREIGN KEY ([member_scope_id]) REFERENCES [iam].[Member] ([member_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_RetentionPolicy_approved_by' AND parent_object_id = OBJECT_ID(N'[ops].[RetentionPolicy]'))
    ALTER TABLE [ops].[RetentionPolicy] WITH CHECK ADD CONSTRAINT [FK_RetentionPolicy_approved_by] FOREIGN KEY ([approved_by]) REFERENCES [iam].[Member] ([member_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_RetentionExecution_retention_policy_id' AND parent_object_id = OBJECT_ID(N'[ops].[RetentionExecution]'))
    ALTER TABLE [ops].[RetentionExecution] WITH CHECK ADD CONSTRAINT [FK_RetentionExecution_retention_policy_id] FOREIGN KEY ([retention_policy_id]) REFERENCES [ops].[RetentionPolicy] ([retention_policy_id]);
GO

-- v2.3 state, lifecycle and bounded-value constraints.
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Permission_action' AND parent_object_id = OBJECT_ID(N'[iam].[Permission]'))
    ALTER TABLE [iam].[Permission] WITH CHECK ADD CONSTRAINT [CK_Permission_action] CHECK ([action] IN ('READ','CREATE','UPDATE','DELETE','APPROVE','EXPORT','CONFIGURE'));
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Permission_status' AND parent_object_id = OBJECT_ID(N'[iam].[Permission]'))
    ALTER TABLE [iam].[Permission] WITH CHECK ADD CONSTRAINT [CK_Permission_status] CHECK ([status] IN ('ACTIVE','RETIRED'));
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_RolePermission_dates' AND parent_object_id = OBJECT_ID(N'[iam].[RolePermission]'))
    ALTER TABLE [iam].[RolePermission] WITH CHECK ADD CONSTRAINT [CK_RolePermission_dates] CHECK ([revoked_at] IS NULL OR [revoked_at] >= [granted_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_AuthSession_auth_strength' AND parent_object_id = OBJECT_ID(N'[iam].[AuthSession]'))
    ALTER TABLE [iam].[AuthSession] WITH CHECK ADD CONSTRAINT [CK_AuthSession_auth_strength] CHECK ([auth_strength] IN ('STANDARD','MFA','STEP_UP'));
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_AuthSession_dates' AND parent_object_id = OBJECT_ID(N'[iam].[AuthSession]'))
    ALTER TABLE [iam].[AuthSession] WITH CHECK ADD CONSTRAINT [CK_AuthSession_dates] CHECK ([expires_at] > [issued_at] AND [last_seen_at] >= [issued_at] AND ([revoked_at] IS NULL OR [revoked_at] >= [issued_at]));
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_PrivacyRequestTask_domain' AND parent_object_id = OBJECT_ID(N'[consent].[PrivacyRequestTask]'))
    ALTER TABLE [consent].[PrivacyRequestTask] WITH CHECK ADD CONSTRAINT [CK_PrivacyRequestTask_domain] CHECK ([domain_code] IN ('IAM','PROFILE','EVENT','SOCIAL','CHAT','STORAGE','NLP','ANALYTICS','AUDIT'));
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_PrivacyRequestTask_action' AND parent_object_id = OBJECT_ID(N'[consent].[PrivacyRequestTask]'))
    ALTER TABLE [consent].[PrivacyRequestTask] WITH CHECK ADD CONSTRAINT [CK_PrivacyRequestTask_action] CHECK ([action_type] IN ('EXPORT','CORRECT','ANONYMIZE','DELETE','RETAIN_EXCEPTION'));
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_PrivacyRequestTask_state' AND parent_object_id = OBJECT_ID(N'[consent].[PrivacyRequestTask]'))
    ALTER TABLE [consent].[PrivacyRequestTask] WITH CHECK ADD CONSTRAINT [CK_PrivacyRequestTask_state] CHECK ([status] IN ('PENDING','RUNNING','COMPLETED','FAILED','EXEMPTED') AND [attempt_count] >= 0 AND ([status] NOT IN ('COMPLETED','EXEMPTED') OR ([completed_at] IS NOT NULL AND [evidence_code] IS NOT NULL)));
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_FileAsset_purpose' AND parent_object_id = OBJECT_ID(N'[storage].[FileAsset]'))
    ALTER TABLE [storage].[FileAsset] WITH CHECK ADD CONSTRAINT [CK_FileAsset_purpose] CHECK ([purpose_code] IN ('CHAT_FILE','VERIFICATION_EVIDENCE','PRIVACY_EXPORT','EVALUATION_REPORT'));
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_FileAsset_classification' AND parent_object_id = OBJECT_ID(N'[storage].[FileAsset]'))
    ALTER TABLE [storage].[FileAsset] WITH CHECK ADD CONSTRAINT [CK_FileAsset_classification] CHECK ([classification] IN ('INTERNAL','CONFIDENTIAL','RESTRICTED','HIGHLY_RESTRICTED'));
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_FileAsset_lifecycle' AND parent_object_id = OBJECT_ID(N'[storage].[FileAsset]'))
    ALTER TABLE [storage].[FileAsset] WITH CHECK ADD CONSTRAINT [CK_FileAsset_lifecycle] CHECK ([size_bytes] >= 0 AND [scan_status] IN ('PENDING','CLEAN','REJECTED','ERROR') AND [lifecycle_status] IN ('UPLOADING','AVAILABLE','QUARANTINED','DELETED','EXPIRED') AND ([lifecycle_status] <> 'AVAILABLE' OR [scan_status] = 'CLEAN') AND ([lifecycle_status] NOT IN ('DELETED','EXPIRED') OR [deleted_at] IS NOT NULL));
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_FileAssetLink_values' AND parent_object_id = OBJECT_ID(N'[storage].[FileAssetLink]'))
    ALTER TABLE [storage].[FileAssetLink] WITH CHECK ADD CONSTRAINT [CK_FileAssetLink_values] CHECK ([resource_type] IN ('MESSAGE','MEMBER_VERIFICATION','PRIVACY_REQUEST','EVALUATION_RUN') AND [relationship_type] IN ('PRIMARY','EVIDENCE','RESULT','REPORT'));
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SyncChange_values' AND parent_object_id = OBJECT_ID(N'[ops].[SyncChange]'))
    ALTER TABLE [ops].[SyncChange] WITH CHECK ADD CONSTRAINT [CK_SyncChange_values] CHECK ([change_type] IN ('UPSERT','DELETE') AND [resource_type] IN ('PROFILE','MATCH','REQUEST','CONVERSATION','MESSAGE','NOTIFICATION') AND [expires_at] > [occurred_at] AND ([payload_json] IS NULL OR ISJSON([payload_json]) = 1));
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_RetentionPolicy_values' AND parent_object_id = OBJECT_ID(N'[ops].[RetentionPolicy]'))
    ALTER TABLE [ops].[RetentionPolicy] WITH CHECK ADD CONSTRAINT [CK_RetentionPolicy_values] CHECK ([policy_version] > 0 AND [retention_days] >= 0 AND [status] IN ('DRAFT','ACTIVE','RETIRED') AND [disposition_action] IN ('DELETE','ANONYMIZE','ARCHIVE') AND ([effective_to] IS NULL OR [effective_to] > [effective_from]));
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_RetentionExecution_values' AND parent_object_id = OBJECT_ID(N'[ops].[RetentionExecution]'))
    ALTER TABLE [ops].[RetentionExecution] WITH CHECK ADD CONSTRAINT [CK_RetentionExecution_values] CHECK ([scope_end] > [scope_start] AND [status] IN ('RUNNING','SUCCEEDED','PARTIAL','FAILED') AND [examined_count] >= 0 AND [disposed_count] >= 0 AND [skipped_hold_count] >= 0 AND [disposed_count] + [skipped_hold_count] <= [examined_count] AND ([status] = 'RUNNING' OR [completed_at] IS NOT NULL));
GO

-- v2.3 lookup, uniqueness and worker access paths.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[iam].[Permission]') AND name = N'UX_Permission_ResourceAction')
    CREATE UNIQUE INDEX [UX_Permission_ResourceAction] ON [iam].[Permission] ([resource_type], [action]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[iam].[Permission]') AND name = N'IX_Permission_Status')
    CREATE INDEX [IX_Permission_Status] ON [iam].[Permission] ([status]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[iam].[RolePermission]') AND name = N'IX_RolePermission_PermissionRevoked')
    CREATE INDEX [IX_RolePermission_PermissionRevoked] ON [iam].[RolePermission] ([permission_code], [revoked_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[iam].[AuthSession]') AND name = N'UX_AuthSession_ProviderSessionHash')
    CREATE UNIQUE INDEX [UX_AuthSession_ProviderSessionHash] ON [iam].[AuthSession] ([provider_session_hash]) WHERE [provider_session_hash] IS NOT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[iam].[AuthSession]') AND name = N'IX_AuthSession_MemberActive')
    CREATE INDEX [IX_AuthSession_MemberActive] ON [iam].[AuthSession] ([member_id], [revoked_at], [expires_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[iam].[AuthSession]') AND name = N'IX_AuthSession_DeviceRevoked')
    CREATE INDEX [IX_AuthSession_DeviceRevoked] ON [iam].[AuthSession] ([device_id], [revoked_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[consent].[PrivacyRequestTask]') AND name = N'UX_PrivacyRequestTask_DomainAction')
    CREATE UNIQUE INDEX [UX_PrivacyRequestTask_DomainAction] ON [consent].[PrivacyRequestTask] ([privacy_request_id], [domain_code], [action_type]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[consent].[PrivacyRequestTask]') AND name = N'IX_PrivacyRequestTask_DueWork')
    CREATE INDEX [IX_PrivacyRequestTask_DueWork] ON [consent].[PrivacyRequestTask] ([status], [updated_at]);
GO
-- blob_path is nvarchar(1024), which exceeds Azure SQL's index-key limit.
-- blob_path_hash is the enforceable unique key; the file service verifies the full path on a hash match.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[storage].[FileAsset]') AND name = N'UX_FileAsset_BlobPathHash')
    CREATE UNIQUE INDEX [UX_FileAsset_BlobPathHash] ON [storage].[FileAsset] ([blob_path_hash]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[storage].[FileAsset]') AND name = N'IX_FileAsset_OwnerCreated')
    CREATE INDEX [IX_FileAsset_OwnerCreated] ON [storage].[FileAsset] ([owner_member_id], [created_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[storage].[FileAsset]') AND name = N'IX_FileAsset_LifecycleExpiry')
    CREATE INDEX [IX_FileAsset_LifecycleExpiry] ON [storage].[FileAsset] ([purpose_code], [lifecycle_status], [expires_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[storage].[FileAsset]') AND name = N'IX_FileAsset_ScanQueue')
    CREATE INDEX [IX_FileAsset_ScanQueue] ON [storage].[FileAsset] ([scan_status], [created_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[storage].[FileAssetLink]') AND name = N'UX_FileAssetLink_Resource')
    CREATE UNIQUE INDEX [UX_FileAssetLink_Resource] ON [storage].[FileAssetLink] ([file_asset_id], [resource_type], [resource_id], [relationship_type]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[storage].[FileAssetLink]') AND name = N'IX_FileAssetLink_Resource')
    CREATE INDEX [IX_FileAssetLink_Resource] ON [storage].[FileAssetLink] ([resource_type], [resource_id], [removed_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[ops].[SyncChange]') AND name = N'IX_SyncChange_CommunityCursor')
    CREATE INDEX [IX_SyncChange_CommunityCursor] ON [ops].[SyncChange] ([community_id], [sync_sequence]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[ops].[SyncChange]') AND name = N'IX_SyncChange_MemberCursor')
    CREATE INDEX [IX_SyncChange_MemberCursor] ON [ops].[SyncChange] ([member_scope_id], [sync_sequence]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[ops].[SyncChange]') AND name = N'IX_SyncChange_Expiry')
    CREATE INDEX [IX_SyncChange_Expiry] ON [ops].[SyncChange] ([expires_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[ops].[RetentionPolicy]') AND name = N'UX_RetentionPolicy_Version')
    CREATE UNIQUE INDEX [UX_RetentionPolicy_Version] ON [ops].[RetentionPolicy] ([resource_type], [policy_version]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[ops].[RetentionPolicy]') AND name = N'UX_RetentionPolicy_Active')
    CREATE UNIQUE INDEX [UX_RetentionPolicy_Active] ON [ops].[RetentionPolicy] ([resource_type]) WHERE [status] = 'ACTIVE';
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[ops].[RetentionPolicy]') AND name = N'IX_RetentionPolicy_StatusEffective')
    CREATE INDEX [IX_RetentionPolicy_StatusEffective] ON [ops].[RetentionPolicy] ([status], [effective_from]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[ops].[RetentionExecution]') AND name = N'IX_RetentionExecution_PolicyStarted')
    CREATE INDEX [IX_RetentionExecution_PolicyStarted] ON [ops].[RetentionExecution] ([retention_policy_id], [started_at] DESC);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[ops].[RetentionExecution]') AND name = N'IX_RetentionExecution_StatusStarted')
    CREATE INDEX [IX_RetentionExecution_StatusStarted] ON [ops].[RetentionExecution] ([status], [started_at]);
GO

-- Documented v2.3 access paths not already covered by a matching key.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[Community]') AND name = N'IX_Community_Status')
    CREATE INDEX [IX_Community_Status] ON [core].[Community] ([status]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[Organization]') AND name = N'IX_Organization_WebsiteDomain')
    CREATE INDEX [IX_Organization_WebsiteDomain] ON [core].[Organization] ([website_domain]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[OrganizationMember]') AND name = N'UQ_OrganizationMember_OrganizationIdMemberIdStartedOn')
    CREATE UNIQUE INDEX [UQ_OrganizationMember_OrganizationIdMemberIdStartedOn] ON [core].[OrganizationMember] ([organization_id], [member_id], [started_on]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[OrganizationMember]') AND name = N'IX_OrganizationMember_MemberIdIsPrimary')
    CREATE INDEX [IX_OrganizationMember_MemberIdIsPrimary] ON [core].[OrganizationMember] ([member_id], [is_primary]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[MemberProfile]') AND name = N'IX_MemberProfile_UpdatedAt')
    CREATE INDEX [IX_MemberProfile_UpdatedAt] ON [core].[MemberProfile] ([updated_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[Sector]') AND name = N'UQ_Sector_Name')
    CREATE UNIQUE INDEX [UQ_Sector_Name] ON [core].[Sector] ([name]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[Sector]') AND name = N'IX_Sector_ParentSectorCodeStatus')
    CREATE INDEX [IX_Sector_ParentSectorCodeStatus] ON [core].[Sector] ([parent_sector_code], [status]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[MemberSector]') AND name = N'IX_MemberSector_SectorCodeMemberId')
    CREATE INDEX [IX_MemberSector_SectorCodeMemberId] ON [core].[MemberSector] ([sector_code], [member_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[MemberGeography]') AND name = N'IX_MemberGeography_MemberIdIsPrimary')
    CREATE INDEX [IX_MemberGeography_MemberIdIsPrimary] ON [core].[MemberGeography] ([member_id], [is_primary]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[MemberGeography]') AND name = N'IX_MemberGeography_CountryCodeRegionCity')
    CREATE INDEX [IX_MemberGeography_CountryCodeRegionCity] ON [core].[MemberGeography] ([country_code], [region], [city]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[ProfileFieldVisibility]') AND name = N'IX_ProfileFieldVisibility_Audience')
    CREATE INDEX [IX_ProfileFieldVisibility_Audience] ON [core].[ProfileFieldVisibility] ([audience]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[MemberVerification]') AND name = N'IX_MemberVerification_MemberIdStatus')
    CREATE INDEX [IX_MemberVerification_MemberIdStatus] ON [core].[MemberVerification] ([member_id], [status]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[core].[MemberVerification]') AND name = N'IX_MemberVerification_StatusCreatedAt')
    CREATE INDEX [IX_MemberVerification_StatusCreatedAt] ON [core].[MemberVerification] ([status], [created_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[iam].[Member]') AND name = N'IX_Member_StatusUpdatedAt')
    CREATE INDEX [IX_Member_StatusUpdatedAt] ON [iam].[Member] ([status], [updated_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[iam].[MemberIdentity]') AND name = N'IX_MemberIdentity_MemberIdIsPrimary')
    CREATE INDEX [IX_MemberIdentity_MemberIdIsPrimary] ON [iam].[MemberIdentity] ([member_id], [is_primary]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[iam].[MemberRole]') AND name = N'IX_MemberRole_RoleCodeExpiresAt')
    CREATE INDEX [IX_MemberRole_RoleCodeExpiresAt] ON [iam].[MemberRole] ([role_code], [expires_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[iam].[MemberDevice]') AND name = N'IX_MemberDevice_MemberIdStatus')
    CREATE INDEX [IX_MemberDevice_MemberIdStatus] ON [iam].[MemberDevice] ([member_id], [status]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[iam].[MemberDevice]') AND name = N'IX_MemberDevice_LastSeenAt')
    CREATE INDEX [IX_MemberDevice_LastSeenAt] ON [iam].[MemberDevice] ([last_seen_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[consent].[ConsentPolicy]') AND name = N'IX_ConsentPolicy_PurposeCodeEffectiveFrom')
    CREATE INDEX [IX_ConsentPolicy_PurposeCodeEffectiveFrom] ON [consent].[ConsentPolicy] ([purpose_code], [effective_from]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[consent].[MemberConsent]') AND name = N'IX_MemberConsent_MemberIdPolicyIdCapturedAt')
    CREATE INDEX [IX_MemberConsent_MemberIdPolicyIdCapturedAt] ON [consent].[MemberConsent] ([member_id], [policy_id], [captured_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[consent].[MemberConsent]') AND name = N'IX_MemberConsent_PolicyIdDecision')
    CREATE INDEX [IX_MemberConsent_PolicyIdDecision] ON [consent].[MemberConsent] ([policy_id], [decision]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[consent].[PrivacyRequest]') AND name = N'IX_PrivacyRequest_StatusDueAt')
    CREATE INDEX [IX_PrivacyRequest_StatusDueAt] ON [consent].[PrivacyRequest] ([status], [due_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[consent].[PrivacyRequest]') AND name = N'IX_PrivacyRequest_MemberIdCreatedAt')
    CREATE INDEX [IX_PrivacyRequest_MemberIdCreatedAt] ON [consent].[PrivacyRequest] ([member_id], [created_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[event].[Venue]') AND name = N'IX_Venue_CountryCodeRegionCity')
    CREATE INDEX [IX_Venue_CountryCodeRegionCity] ON [event].[Venue] ([country_code], [region], [city]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[event].[Event]') AND name = N'IX_Event_VenueIdStartsAt')
    CREATE INDEX [IX_Event_VenueIdStartsAt] ON [event].[Event] ([venue_id], [starts_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[event].[EventMatchingPolicy]') AND name = N'IX_EventMatchingPolicy_StatusEffectiveFromEffectiveTo')
    CREATE INDEX [IX_EventMatchingPolicy_StatusEffectiveFromEffectiveTo] ON [event].[EventMatchingPolicy] ([status], [effective_from], [effective_to]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[event].[EventRegistration]') AND name = N'IX_EventRegistration_MemberIdStatus')
    CREATE INDEX [IX_EventRegistration_MemberIdStatus] ON [event].[EventRegistration] ([member_id], [status]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[event].[EventRegistration]') AND name = N'IX_EventRegistration_EventIdStatus')
    CREATE INDEX [IX_EventRegistration_EventIdStatus] ON [event].[EventRegistration] ([event_id], [status]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[event].[LiveModeSession]') AND name = N'IX_LiveModeSession_EventIdStatusActiveUntil')
    CREATE INDEX [IX_LiveModeSession_EventIdStatusActiveUntil] ON [event].[LiveModeSession] ([event_id], [status], [active_until]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[event].[LiveModeSession]') AND name = N'IX_LiveModeSession_MemberIdStatus')
    CREATE INDEX [IX_LiveModeSession_MemberIdStatus] ON [event].[LiveModeSession] ([member_id], [status]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[event].[EventPresence]') AND name = N'IX_EventPresence_LiveSessionIdObservedAt')
    CREATE INDEX [IX_EventPresence_LiveSessionIdObservedAt] ON [event].[EventPresence] ([live_session_id], [observed_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[social].[ConnectionRequest]') AND name = N'IX_ConnectionRequest_SenderMemberIdStatus')
    CREATE INDEX [IX_ConnectionRequest_SenderMemberIdStatus] ON [social].[ConnectionRequest] ([sender_member_id], [status]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[social].[Connection]') AND name = N'IX_Connection_MemberLowIdStatus')
    CREATE INDEX [IX_Connection_MemberLowIdStatus] ON [social].[Connection] ([member_low_id], [status]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[social].[Connection]') AND name = N'IX_Connection_MemberHighIdStatus')
    CREATE INDEX [IX_Connection_MemberHighIdStatus] ON [social].[Connection] ([member_high_id], [status]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[social].[MemberBlock]') AND name = N'IX_MemberBlock_BlockedMemberIdRemovedAt')
    CREATE INDEX [IX_MemberBlock_BlockedMemberIdRemovedAt] ON [social].[MemberBlock] ([blocked_member_id], [removed_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[social].[MemberReport]') AND name = N'IX_MemberReport_StatusCreatedAt')
    CREATE INDEX [IX_MemberReport_StatusCreatedAt] ON [social].[MemberReport] ([status], [created_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[social].[MemberReport]') AND name = N'IX_MemberReport_ReportedMemberIdCreatedAt')
    CREATE INDEX [IX_MemberReport_ReportedMemberIdCreatedAt] ON [social].[MemberReport] ([reported_member_id], [created_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[chat].[Conversation]') AND name = N'IX_Conversation_StatusLastMessageAt')
    CREATE INDEX [IX_Conversation_StatusLastMessageAt] ON [chat].[Conversation] ([status], [last_message_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[chat].[ConversationParticipant]') AND name = N'IX_ConversationParticipant_MemberIdLeftAt')
    CREATE INDEX [IX_ConversationParticipant_MemberIdLeftAt] ON [chat].[ConversationParticipant] ([member_id], [left_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[chat].[Message]') AND name = N'IX_Message_SenderMemberIdCreatedAt')
    CREATE INDEX [IX_Message_SenderMemberIdCreatedAt] ON [chat].[Message] ([sender_member_id], [created_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[chat].[MessageReceipt]') AND name = N'IX_MessageReceipt_MemberIdReadAt')
    CREATE INDEX [IX_MessageReceipt_MemberIdReadAt] ON [chat].[MessageReceipt] ([member_id], [read_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[notification].[NotificationPolicy]') AND name = N'IX_NotificationPolicy_StatusEffectiveFromEffectiveTo')
    CREATE INDEX [IX_NotificationPolicy_StatusEffectiveFromEffectiveTo] ON [notification].[NotificationPolicy] ([status], [effective_from], [effective_to]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[notification].[PushToken]') AND name = N'IX_PushToken_DeviceIdStatus')
    CREATE INDEX [IX_PushToken_DeviceIdStatus] ON [notification].[PushToken] ([device_id], [status]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[notification].[Notification]') AND name = N'IX_Notification_MemberIdCreatedAt')
    CREATE INDEX [IX_Notification_MemberIdCreatedAt] ON [notification].[Notification] ([member_id], [created_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[notification].[NotificationDeliveryAttempt]') AND name = N'IX_NotificationDeliveryAttempt_ProviderProviderMessageId')
    CREATE INDEX [IX_NotificationDeliveryAttempt_ProviderProviderMessageId] ON [notification].[NotificationDeliveryAttempt] ([provider], [provider_message_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[NlpIntent]') AND name = N'IX_NlpIntent_MemberIdStatus')
    CREATE INDEX [IX_NlpIntent_MemberIdStatus] ON [nlp].[NlpIntent] ([member_id], [status]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[NlpIntent]') AND name = N'IX_NlpIntent_NormalizedHash')
    CREATE INDEX [IX_NlpIntent_NormalizedHash] ON [nlp].[NlpIntent] ([normalized_hash]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[NlpModelVersion]') AND name = N'IX_NlpModelVersion_StatusCreatedAt')
    CREATE INDEX [IX_NlpModelVersion_StatusCreatedAt] ON [nlp].[NlpModelVersion] ([status], [created_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[NlpRankingConfig]') AND name = N'IX_NlpRankingConfig_ActiveFromActiveTo')
    CREATE INDEX [IX_NlpRankingConfig_ActiveFromActiveTo] ON [nlp].[NlpRankingConfig] ([active_from], [active_to]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[NlpProcessingJob]') AND name = N'IX_NlpProcessingJob_StatusAvailableAt')
    CREATE INDEX [IX_NlpProcessingJob_StatusAvailableAt] ON [nlp].[NlpProcessingJob] ([status], [available_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[MatchRequest]') AND name = N'IX_MatchRequest_StatusCreatedAt')
    CREATE INDEX [IX_MatchRequest_StatusCreatedAt] ON [nlp].[MatchRequest] ([status], [created_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[MatchRequest]') AND name = N'IX_MatchRequest_RequestHash')
    CREATE INDEX [IX_MatchRequest_RequestHash] ON [nlp].[MatchRequest] ([request_hash]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[NlpFeedback]') AND name = N'IX_NlpFeedback_LabelCreatedAt')
    CREATE INDEX [IX_NlpFeedback_LabelCreatedAt] ON [nlp].[NlpFeedback] ([label], [created_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[MatchSuppression]') AND name = N'IX_MatchSuppression_MemberIdContextIdEndsAt')
    CREATE INDEX [IX_MatchSuppression_MemberIdContextIdEndsAt] ON [nlp].[MatchSuppression] ([member_id], [context_id], [ends_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[MatchSuppression]') AND name = N'IX_MatchSuppression_IntentIdEndsAt')
    CREATE INDEX [IX_MatchSuppression_IntentIdEndsAt] ON [nlp].[MatchSuppression] ([intent_id], [ends_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[EvaluationDataset]') AND name = N'IX_EvaluationDataset_StatusCreatedAt')
    CREATE INDEX [IX_EvaluationDataset_StatusCreatedAt] ON [nlp].[EvaluationDataset] ([status], [created_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[EvaluationPair]') AND name = N'IX_EvaluationPair_DatasetIdSplit')
    CREATE INDEX [IX_EvaluationPair_DatasetIdSplit] ON [nlp].[EvaluationPair] ([dataset_id], [split]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[EvaluationPair]') AND name = N'IX_EvaluationPair_GoldLabel')
    CREATE INDEX [IX_EvaluationPair_GoldLabel] ON [nlp].[EvaluationPair] ([gold_label]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[EvaluationRun]') AND name = N'IX_EvaluationRun_DatasetIdStartedAt')
    CREATE INDEX [IX_EvaluationRun_DatasetIdStartedAt] ON [nlp].[EvaluationRun] ([dataset_id], [started_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[nlp].[EvaluationRun]') AND name = N'IX_EvaluationRun_ModelVersionRankingVersion')
    CREATE INDEX [IX_EvaluationRun_ModelVersionRankingVersion] ON [nlp].[EvaluationRun] ([model_version], [ranking_version]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[moderation].[ModerationCase]') AND name = N'IX_ModerationCase_StatusPriorityCreatedAt')
    CREATE INDEX [IX_ModerationCase_StatusPriorityCreatedAt] ON [moderation].[ModerationCase] ([status], [priority], [created_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[moderation].[ModerationCase]') AND name = N'IX_ModerationCase_SubjectMemberIdCreatedAt')
    CREATE INDEX [IX_ModerationCase_SubjectMemberIdCreatedAt] ON [moderation].[ModerationCase] ([subject_member_id], [created_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[moderation].[ModerationAction]') AND name = N'IX_ModerationAction_ModerationCaseIdCreatedAt')
    CREATE INDEX [IX_ModerationAction_ModerationCaseIdCreatedAt] ON [moderation].[ModerationAction] ([moderation_case_id], [created_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[moderation].[ModerationAction]') AND name = N'IX_ModerationAction_ActorMemberIdCreatedAt')
    CREATE INDEX [IX_ModerationAction_ActorMemberIdCreatedAt] ON [moderation].[ModerationAction] ([actor_member_id], [created_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[moderation].[ContentRule]') AND name = N'UQ_ContentRule_RuleTypeVersion')
    CREATE UNIQUE INDEX [UQ_ContentRule_RuleTypeVersion] ON [moderation].[ContentRule] ([rule_type], [version]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[moderation].[ContentRule]') AND name = N'IX_ContentRule_RuleTypeStatus')
    CREATE INDEX [IX_ContentRule_RuleTypeStatus] ON [moderation].[ContentRule] ([rule_type], [status]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[moderation].[ContentScan]') AND name = N'IX_ContentScan_ResourceTypeResourceIdScannedAt')
    CREATE INDEX [IX_ContentScan_ResourceTypeResourceIdScannedAt] ON [moderation].[ContentScan] ([resource_type], [resource_id], [scanned_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[moderation].[ContentScan]') AND name = N'IX_ContentScan_ResultScannedAt')
    CREATE INDEX [IX_ContentScan_ResultScannedAt] ON [moderation].[ContentScan] ([result], [scanned_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[ops].[OutboxEvent]') AND name = N'IX_OutboxEvent_AggregateTypeAggregateIdOccurredAt')
    CREATE INDEX [IX_OutboxEvent_AggregateTypeAggregateIdOccurredAt] ON [ops].[OutboxEvent] ([aggregate_type], [aggregate_id], [occurred_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[ops].[BackgroundJob]') AND name = N'IX_BackgroundJob_ResourceTypeResourceId')
    CREATE INDEX [IX_BackgroundJob_ResourceTypeResourceId] ON [ops].[BackgroundJob] ([resource_type], [resource_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[ops].[AuditEvent]') AND name = N'IX_AuditEvent_ResourceTypeResourceIdOccurredAt')
    CREATE INDEX [IX_AuditEvent_ResourceTypeResourceIdOccurredAt] ON [ops].[AuditEvent] ([resource_type], [resource_id], [occurred_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[ops].[AuditEvent]') AND name = N'IX_AuditEvent_ActorIdOccurredAt')
    CREATE INDEX [IX_AuditEvent_ActorIdOccurredAt] ON [ops].[AuditEvent] ([actor_id], [occurred_at]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[ops].[AuditEvent]') AND name = N'IX_AuditEvent_CorrelationId')
    CREATE INDEX [IX_AuditEvent_CorrelationId] ON [ops].[AuditEvent] ([correlation_id]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[analytics].[ProductEvent]') AND name = N'IX_ProductEvent_CommunityIdOccurredAt')
    CREATE INDEX [IX_ProductEvent_CommunityIdOccurredAt] ON [analytics].[ProductEvent] ([community_id], [occurred_at]);
GO

-- ======================== CROSS-ROW INVARIANTS ========================
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

-- ======================== CONTROLLED PROCEDURES ========================
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
    ('ADMIN','Administrator','Privileged product administration through explicit permissions',1),
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

MERGE iam.Permission AS target
USING (VALUES
    ('PROFILE_READ','PROFILE','READ','Read an authorized member profile'),
    ('PROFILE_UPDATE','PROFILE','UPDATE','Update the authenticated member profile'),
    ('EVENT_READ','EVENT','READ','Read published or authorized event data'),
    ('EVENT_CONFIGURE','EVENT','CONFIGURE','Create and administer events and matching policies'),
    ('MATCH_READ','MATCH','READ','Read authorized match results'),
    ('MATCH_CREATE','MATCH','CREATE','Create an intent or match request'),
    ('CONNECTION_CREATE','CONNECTION','CREATE','Create and respond to connection requests'),
    ('CONNECTION_UPDATE','CONNECTION','UPDATE','Disconnect or manage an existing connection'),
    ('CHAT_READ','CHAT','READ','Read an authorized conversation'),
    ('CHAT_CREATE','CHAT','CREATE','Send a message to an authorized conversation'),
    ('FILE_READ','FILE_ASSET','READ','Download an authorized clean file asset'),
    ('FILE_CREATE','FILE_ASSET','CREATE','Create and finalize an authorized file asset'),
    ('NOTIFICATION_READ','NOTIFICATION','READ','Read the authenticated member notifications'),
    ('NOTIFICATION_UPDATE','NOTIFICATION','UPDATE','Update notification preferences and acknowledgements'),
    ('PRIVACY_READ','PRIVACY_REQUEST','READ','Read an authorized privacy request'),
    ('PRIVACY_CREATE','PRIVACY_REQUEST','CREATE','Submit a privacy request'),
    ('PRIVACY_APPROVE','PRIVACY_REQUEST','APPROVE','Approve privacy exceptions and completion evidence'),
    ('MODERATION_READ','MODERATION_CASE','READ','Read an authorized moderation case'),
    ('MODERATION_APPROVE','MODERATION_CASE','APPROVE','Review and action moderation cases'),
    ('NLP_EVALUATION_READ','NLP_EVALUATION','READ','Read de-identified NLP evaluation data'),
    ('NLP_EVALUATION_CONFIGURE','NLP_EVALUATION','CONFIGURE','Manage model, ranking and evaluation versions'),
    ('ROLE_CONFIGURE','AUTHORIZATION','CONFIGURE','Manage roles and permission assignments')
) AS source(permission_code,resource_type,action,description)
ON target.permission_code=source.permission_code
WHEN MATCHED THEN UPDATE SET resource_type=source.resource_type,action=source.action,description=source.description,status='ACTIVE',updated_at=SYSUTCDATETIME()
WHEN NOT MATCHED THEN INSERT(permission_code,resource_type,action,description,status) VALUES(source.permission_code,source.resource_type,source.action,source.description,'ACTIVE');
GO

MERGE iam.RolePermission AS target
USING (VALUES
    ('MEMBER','PROFILE_READ'),('MEMBER','PROFILE_UPDATE'),('MEMBER','EVENT_READ'),('MEMBER','MATCH_READ'),('MEMBER','MATCH_CREATE'),
    ('MEMBER','CONNECTION_CREATE'),('MEMBER','CONNECTION_UPDATE'),('MEMBER','CHAT_READ'),('MEMBER','CHAT_CREATE'),
    ('MEMBER','FILE_READ'),('MEMBER','FILE_CREATE'),('MEMBER','NOTIFICATION_READ'),('MEMBER','NOTIFICATION_UPDATE'),
    ('MEMBER','PRIVACY_READ'),('MEMBER','PRIVACY_CREATE'),
    ('EVENT_ADMIN','EVENT_READ'),('EVENT_ADMIN','EVENT_CONFIGURE'),('EVENT_ADMIN','PROFILE_READ'),
    ('MODERATOR','MODERATION_READ'),('MODERATOR','MODERATION_APPROVE'),('MODERATOR','PROFILE_READ'),('MODERATOR','FILE_READ'),
    ('NLP_EVALUATOR','NLP_EVALUATION_READ'),('NLP_EVALUATOR','NLP_EVALUATION_CONFIGURE'),('NLP_EVALUATOR','PROFILE_READ'),
    ('SUPPORT','PRIVACY_READ'),('SUPPORT','PRIVACY_APPROVE'),('SUPPORT','PROFILE_READ'),('SUPPORT','FILE_READ'),
    ('PRODUCT_ADMIN','PROFILE_READ'),('PRODUCT_ADMIN','EVENT_READ'),('PRODUCT_ADMIN','EVENT_CONFIGURE'),('PRODUCT_ADMIN','MODERATION_READ'),
    ('PRODUCT_ADMIN','NLP_EVALUATION_READ'),('PRODUCT_ADMIN','ROLE_CONFIGURE'),
    ('ADMIN','PROFILE_READ'),('ADMIN','EVENT_READ'),('ADMIN','EVENT_CONFIGURE'),('ADMIN','MODERATION_READ'),('ADMIN','MODERATION_APPROVE'),
    ('ADMIN','NLP_EVALUATION_READ'),('ADMIN','NLP_EVALUATION_CONFIGURE'),('ADMIN','PRIVACY_READ'),('ADMIN','PRIVACY_APPROVE'),('ADMIN','ROLE_CONFIGURE')
) AS source(role_code,permission_code)
ON target.role_code=source.role_code AND target.permission_code=source.permission_code
WHEN MATCHED THEN UPDATE SET revoked_at=NULL
WHEN NOT MATCHED THEN INSERT(role_code,permission_code) VALUES(source.role_code,source.permission_code);
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

-- ======================== VERIFICATION ========================
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
