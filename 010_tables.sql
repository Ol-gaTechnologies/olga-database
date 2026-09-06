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
