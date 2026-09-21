/************************************************************************************
(C) COPYRIGHT BOC - Business Objectives Consulting 1995 - 2021
All Rights Reserved
Use, duplication or disclosure restricted by BOC
Vienna, 1995 - 2021
************************************************************************************
* PostgreSQL - DATABASE CREATION SCRIPT - ADOxx
************************************************************************************
Description:
The script creates the following:
    - Create empty database
    - Create ADOxx technical users (logins, DB users)
    - Create DB schema
    - Grant permissions
************************************************************************************
Adaption:
 * Mandatory:
   - Database name (vDBName)
 * Optional:
   - ADOxx technical user name
   - ADOxx technical user password
************************************************************************************
USAGE:
  psql -U postgres -f prepareDB.sql
************************************************************************************/

-- MUST BE ADAPTED: database name
\set vDBName 'adoxxdb'

\echo '********************************************************';
\echo '*         Create empty ADOxx Database                  *';
\echo '********************************************************';
CREATE DATABASE :vDBName;

\echo '...Database created.';

\echo '********************************************************';
\echo '*        Connect to the new database                   *';
\echo '********************************************************';
\connect :vDBName;

\echo '********************************************************';
\echo '*        Create logins for the ADOxx technical users   *';
\echo '********************************************************';
DO $$
BEGIN
  CREATE USER "ADOxx" PASSWORD '<ADOXX_PASSWORD>';
  EXCEPTION WHEN DUPLICATE_OBJECT THEN
  RAISE NOTICE '...Login ADOxx already exists. No action taken.';
END
$$;

\echo '...Login for the ADOxx technical user created.';

\echo '********************************************************';
\echo '*    Create schema, grant access and set permissions   *';
\echo '********************************************************';
GRANT CONNECT ON DATABASE :vDBName TO "ADOxx";

CREATE SCHEMA IF NOT EXISTS "ADOxx";

GRANT USAGE ON SCHEMA "ADOxx" TO "ADOxx";

ALTER DEFAULT PRIVILEGES IN SCHEMA "ADOxx" GRANT INSERT ON TABLES TO "ADOxx";
ALTER DEFAULT PRIVILEGES IN SCHEMA "ADOxx" GRANT SELECT ON TABLES TO "ADOxx";
ALTER DEFAULT PRIVILEGES IN SCHEMA "ADOxx" GRANT UPDATE ON TABLES TO "ADOxx";
ALTER DEFAULT PRIVILEGES IN SCHEMA "ADOxx" GRANT DELETE ON TABLES TO "ADOxx";

\echo '...Access granted.';

\echo '********************************************************';
\echo '*   Set the database owner to the ADOxx technical user *';
\echo '********************************************************';
ALTER DATABASE :vDBName OWNER TO "ADOxx"
