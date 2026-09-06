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
IF '$(SeedMvpPolicies)'='1' AND NOT EXISTS (SELECT 1 FROM notification.NotificationPolicy)
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
