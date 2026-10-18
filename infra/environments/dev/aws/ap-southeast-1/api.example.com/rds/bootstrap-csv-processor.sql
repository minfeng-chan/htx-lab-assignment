-- Run with psql as htxadmin against database htx after schema migrations.
-- Pass -v db_user=csv_processor; keep it aligned with env.hcl.
-- No database password is created for this workload user.
\set ON_ERROR_STOP on
\if :{?db_user}
\else
  \set db_user csv_processor
\endif

BEGIN;
SELECT format('CREATE ROLE %I LOGIN', :'db_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'db_user')
\gexec
ALTER ROLE :"db_user" LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION PASSWORD NULL;
GRANT rds_iam TO :"db_user";
GRANT CONNECT ON DATABASE :"DBNAME" TO :"db_user";

-- The processor can read and upsert ingestion data, but cannot own or create tables.
CREATE SCHEMA IF NOT EXISTS ingestion AUTHORIZATION htxadmin;
GRANT USAGE ON SCHEMA ingestion TO :"db_user";
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA ingestion TO :"db_user";
GRANT USAGE ON ALL SEQUENCES IN SCHEMA ingestion TO :"db_user";
-- Applies to future objects created by htxadmin migrations in this schema only.
ALTER DEFAULT PRIVILEGES FOR ROLE htxadmin IN SCHEMA ingestion
  GRANT SELECT, INSERT, UPDATE ON TABLES TO :"db_user";
ALTER DEFAULT PRIVILEGES FOR ROLE htxadmin IN SCHEMA ingestion
  GRANT USAGE ON SEQUENCES TO :"db_user";
COMMIT;
