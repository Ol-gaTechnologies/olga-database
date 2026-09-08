DO $$
BEGIN
    RAISE EXCEPTION 'Cross-engine SQL Server-to-PostgreSQL upgrades require a separately reviewed data-migration plan.';
END;
$$;
