-- Replace these lower_snake_case principals after Azure PostgreSQL Microsoft Entra mappings exist.
GRANT olga_core_app TO core_api_database_principal;
GRANT olga_nlp_app TO nlp_api_database_principal;
GRANT olga_notification_app, olga_ops_worker TO notification_worker_database_principal;
GRANT olga_storage_app TO file_service_database_principal;

-- Add only deployed service principals; runtime identities never receive owner or DDL roles.
