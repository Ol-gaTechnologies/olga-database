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
