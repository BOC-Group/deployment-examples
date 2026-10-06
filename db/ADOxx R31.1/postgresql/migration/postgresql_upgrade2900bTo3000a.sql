DO $$
DECLARE 
  vSrcSchemaVer varchar(50);
  vTrgSchemaVer varchar(50);
  sqltxt varchar;
  schema varchar(128);
  sqlschema varchar(128);
  cntOUT integer; -- for existence checks
BEGIN 
  vSrcSchemaVer := 'ADOxx 29.00b'; -- current schema version
  vTrgSchemaVer := 'ADOxx 30.00a'; -- target schema version
  
  RAISE NOTICE '********************************************************';
  RAISE NOTICE '*         Upgrade ADOxx Schema for PostgreSQL          *';
  RAISE NOTICE '********************************************************';
  RAISE NOTICE '* Apply trigger function fixes to existing ADOxx database:';
  RAISE NOTICE '* - Source schema version: %', vSrcSchemaVer;
  RAISE NOTICE '* - Target schema version: %', vTrgSchemaVer;
  RAISE NOTICE '********************************************************';

  RAISE NOTICE '********************************************************';
  RAISE NOTICE '* Identifying the database schema of the ADOxx tables  *';
  RAISE NOTICE '********************************************************';

  IF 1 = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'dbinfo') THEN
    SELECT TABLE_SCHEMA INTO schema FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'dbinfo';
    RAISE NOTICE '...Using schema %', schema;
  ELSE 
    RAISE EXCEPTION 'Schema of ADOxx tables could not be identified.';
  END IF;

  sqlschema := '"' || schema || '"';

  RAISE NOTICE 'Starting to check the current database...';

  IF EXISTS(SELECT * FROM information_schema.tables WHERE table_name = 'dbinfo' AND table_schema = schema) THEN 
    sqltxt := 'SELECT COUNT(*) FROM ' || sqlschema || '.dbinfo WHERE type=4 AND val2=''' || vSrcSchemaVer || ''';';
    EXECUTE sqltxt INTO cntOUT;
    
    IF cntOUT <> 1 THEN 
      BEGIN 
        RAISE NOTICE 'Warning: The current database does not have the expected schema version. Proceeding anyway as this is a trigger fix only.';
      END;
    END IF;
  ELSE 
    RAISE EXCEPTION 'The current database is not a valid ADOxx database.';
  END IF;

  RAISE NOTICE '...Check for the current database done.';

  RAISE NOTICE 'Starting to apply the trigger function fixes...';

  -- Fix the delRiRepoObj function
  RAISE NOTICE 'Updating delRiRepoObj trigger function...';

  sqltxt := 'CREATE OR REPLACE FUNCTION ' || sqlschema || '.delRiRepoObj() RETURNS trigger AS 
  $BODY$ 
  BEGIN 
    DELETE FROM ' || sqlschema || '.repoinst 
    WHERE NOT EXISTS (
      SELECT ro.realrepoinstid 
      FROM ' || sqlschema || '.ri_repoobjs ro 
      WHERE ro.realrepoinstid=OLD.realrepoinstid
    ) 
    AND ' || sqlschema || '.repoinst.repoinstid = OLD.realrepoinstid; 
    
    DELETE FROM ' || sqlschema || '.mi_repoobjs 
    WHERE ' || sqlschema || '.mi_repoobjs.repoid=OLD.repoid 
    AND ' || sqlschema || '.mi_repoobjs.realmodinstid IN (
      SELECT mi.modinstid 
      FROM ' || sqlschema || '.modelinst mi 
      WHERE mi.repoinstid=OLD.repoinstid
    ); 
    
    DELETE FROM ' || sqlschema || '.relepi_repoobjs 
    WHERE ' || sqlschema || '.relepi_repoobjs.repoid=OLD.repoid 
    AND ' || sqlschema || '.relepi_repoobjs.realrelepiid IN (
      SELECT relepi.relepiid 
      FROM ' || sqlschema || '.relendpntinst relepi 
      WHERE relepi.ownerid=OLD.repoinstid
    ); 
    
    DELETE FROM ' || sqlschema || '.groupobjsctxtspec 
    WHERE ' || sqlschema || '.groupobjsctxtspec.objid=OLD.repoinstid 
    AND EXISTS (
      SELECT hg_ro.realgroupid 
      FROM ' || sqlschema || '.hg_repoobjs hg_ro 
      WHERE hg_ro.realgroupid=' || sqlschema || '.groupobjsctxtspec.groupid 
      AND hg_ro.repoid=OLD.repoid
    ); 
    
    DELETE FROM ' || sqlschema || '.permissions 
    WHERE ' || sqlschema || '.permissions.contextid=(
      SELECT r.repoid 
      FROM ' || sqlschema || '.repository r 
      WHERE r.realrepoid=OLD.repoid
    ) 
    AND ' || sqlschema || '.permissions.objectid=OLD.repoinstid; 
    
    -- Fix: Changed comparison from 0 to 1
    DELETE FROM ' || sqlschema || '.permissions 
    WHERE OLD.repoid=1 
    AND ' || sqlschema || '.permissions.actorid=OLD.repoinstid; 
    
    -- Fix: Changed comparison from 0 to 1
    DELETE FROM ' || sqlschema || '.rolemember 
    WHERE OLD.repoid=1 
    AND ' || sqlschema || '.rolemember.memberid=OLD.repoinstid 
    AND ' || sqlschema || '.rolemember.isgroup=0; 
    
    DELETE FROM ' || sqlschema || '.delayedaction 
    WHERE ' || sqlschema || '.delayedaction.artefactid=OLD.repoinstid 
    AND ' || sqlschema || '.delayedaction.repoid=OLD.repoid; 
    
    RETURN OLD;
  END;
  $BODY$ 
  LANGUAGE plpgsql;';

  EXECUTE sqltxt;

  RAISE NOTICE '...Trigger function updated.';

  -- Add a comment to document the change
  sqltxt := 'COMMENT ON FUNCTION ' || sqlschema || '.delRiRepoObj() IS ''Updated to fix repoid comparison from 0 to 1'';';
  EXECUTE sqltxt;

  -- Fix the delHgRepoObj function
  RAISE NOTICE 'Updating delHgRepoObj trigger function...';

  sqltxt := 'CREATE OR REPLACE FUNCTION ' || sqlschema || '.delHgRepoObj() RETURNS trigger AS 
  $BODY$ 
  BEGIN 
    DELETE FROM ' || sqlschema || '.hiergroup_ctxtspec 
    WHERE ' || sqlschema || '.hiergroup_ctxtspec.groupid = OLD.realgroupid;

    DELETE FROM ' || sqlschema || '.permissions 
    WHERE ' || sqlschema || '.permissions.contextid=(
      SELECT r.repoid 
      FROM ' || sqlschema || '.repository r 
      WHERE r.realrepoid=OLD.repoid
    ) 
    AND ' || sqlschema || '.permissions.actorid=OLD.groupid; 

    DELETE FROM ' || sqlschema || '.permissions 
    WHERE ' || sqlschema || '.permissions.contextid=(
      SELECT r.repoid 
      FROM ' || sqlschema || '.repository r 
      WHERE r.realrepoid=OLD.repoid
    ) 
    AND ' || sqlschema || '.permissions.objectid=OLD.groupid; 

    -- Fix: Changed comparison from 0 to 1
    DELETE FROM ' || sqlschema || '.rolemember 
    WHERE OLD.repoid=1 
    AND ' || sqlschema || '.rolemember.memberid=OLD.groupid 
    AND ' || sqlschema || '.rolemember.isgroup=1; 

    RETURN OLD;
  END;
  $BODY$ 
  LANGUAGE plpgsql;';

  EXECUTE sqltxt;

  RAISE NOTICE '...Trigger function updated.';

  -- Add a comment to document the change
  sqltxt := 'COMMENT ON FUNCTION ' || sqlschema || '.delHgRepoObj() IS ''Updated to fix repoid comparison from 0 to 1'';';
  EXECUTE sqltxt;

  RAISE NOTICE 'All trigger functions have been updated successfully.';

  RAISE NOTICE '********************************************************';
  RAISE NOTICE '*          Removing int_data table and related         *';
  RAISE NOTICE '********************************************************';
  BEGIN
    -- Check if int_data table exists
    sqltxt := 'SELECT COUNT(*) FROM information_schema.tables WHERE table_name = ''int_data'' AND table_schema = ''' || schema || ''';';
    EXECUTE sqltxt INTO cntOUT;
    
    IF cntOUT > 0 THEN
      RAISE NOTICE 'Removing int_data table and its indexes...';
      
      -- Drop indexes first
      RAISE NOTICE 'Dropping indexes on int_data table...';
      sqltxt := 'DROP INDEX IF EXISTS ' || sqlschema || '.iintdata_dataid_subid_ownerid;';
      EXECUTE sqltxt;
      RAISE NOTICE '...Dropped index iintdata_dataid_subid_ownerid';
      
      sqltxt := 'DROP INDEX IF EXISTS ' || sqlschema || '.iintdata_ownerid_expirydate;';
      EXECUTE sqltxt;
      RAISE NOTICE '...Dropped index iintdata_ownerid_expirydate';
      
      -- Drop the table
      RAISE NOTICE 'Dropping int_data table...';
      sqltxt := 'DROP TABLE IF EXISTS ' || sqlschema || '.int_data;';
      EXECUTE sqltxt;
      RAISE NOTICE '...int_data table removed successfully';
    ELSE
      RAISE NOTICE 'int_data table does not exist, skipping removal';
    END IF;
  END;

  RAISE NOTICE'********************************************************';
  RAISE NOTICE'*                   Update version info                *';
  RAISE NOTICE'********************************************************';
  BEGIN
    RAISE NOTICE'Updating the schema version info in dbinfo...';
    sqltxt := 'UPDATE ' || sqlschema || '.dbinfo SET val2=''' || vTrgSchemaVer || ''' WHERE type=4;';
    EXECUTE sqltxt;
    RAISE NOTICE'...Schema version info updated.';
  END;

  RAISE NOTICE '[Transaction committed]';

EXCEPTION
  WHEN OTHERS THEN 
    RAISE NOTICE 'Error while changing the database schema:';
    RAISE NOTICE '-> ';
    RAISE NOTICE '%', SQLERRM;
    RAISE NOTICE 'No action taken.';
    ROLLBACK;
    RAISE NOTICE '[Transaction rolled back]';
END;
$$;