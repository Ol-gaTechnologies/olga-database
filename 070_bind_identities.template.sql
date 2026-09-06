-- Replace bracketed placeholders only after managed identities are created.
-- Execute while connected with a Microsoft Entra administrator.
CREATE USER [<core-api-managed-identity>] FROM EXTERNAL PROVIDER;
ALTER ROLE olga_core_app ADD MEMBER [<core-api-managed-identity>];

CREATE USER [<nlp-api-managed-identity>] FROM EXTERNAL PROVIDER;
ALTER ROLE olga_nlp_app ADD MEMBER [<nlp-api-managed-identity>];

CREATE USER [<notification-worker-managed-identity>] FROM EXTERNAL PROVIDER;
ALTER ROLE olga_notification_app ADD MEMBER [<notification-worker-managed-identity>];
ALTER ROLE olga_ops_worker ADD MEMBER [<notification-worker-managed-identity>];

CREATE USER [<file-service-managed-identity>] FROM EXTERNAL PROVIDER;
ALTER ROLE olga_storage_app ADD MEMBER [<file-service-managed-identity>];

-- Add equivalent users only for deployed services. Do not grant db_owner to application identities.
