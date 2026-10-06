DO $$
DECLARE vSrcSchemaVer varchar(50);
DECLARE vTrgSchemaVer varchar(50);
DECLARE sqltxt varchar; -- usually, a smaller fixed value can be sufficient, but nvarchar(max) should be used e.g. for the over 4000 nvarchar SP
DECLARE schema varchar(128);
DECLARE sqlschema varchar(128);
DECLARE cntOUT integer; -- for existence checks

BEGIN
  vSrcSchemaVer := 'ADOxx 28.00a'; -- source schema version
  vTrgSchemaVer := 'ADOxx 29.00b'; -- target schema version

  RAISE NOTICE'********************************************************';
  RAISE NOTICE'*         Upgrade ADOxx Schema for PostgreSQL          *';
  RAISE NOTICE'********************************************************';
  RAISE NOTICE'* Apply schema changes to existing ADOxx database:';
  RAISE NOTICE'* - Source schema version: %', vSrcSchemaVer;
  RAISE NOTICE'* - Target schema version: %', vTrgSchemaVer;
  RAISE NOTICE'********************************************************';


  RAISE NOTICE'********************************************************';
  RAISE NOTICE'* Identifying the database schema of the ADOxx tables  *';
  RAISE NOTICE'********************************************************';

  IF 1=(SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'dbinfo') THEN
    SELECT TABLE_SCHEMA FROM INFORMATION_SCHEMA.TABLES INTO schema WHERE TABLE_NAME = 'dbinfo';
    RAISE NOTICE'...Using schema %', schema;
  ELSE
    RAISE EXCEPTION'Schema of ADOxx tables could not be identified.';
  END IF;

  sqlschema := '"' || schema || '"';
  
  RAISE NOTICE'Starting to check the current database...';

  IF EXISTS(SELECT * FROM information_schema.tables WHERE table_name = 'dbinfo' AND table_schema = schema) THEN
    sqltxt := 'SELECT COUNT(*) FROM ' || sqlschema || '.dbinfo WHERE type=4 AND val2=''' || vSrcSchemaVer || ''';';
    EXECUTE sqltxt INTO cntOUT;
    IF cntOUT <> 1 THEN
      BEGIN
        RAISE EXCEPTION'The current database does not have the appropriate source schema version.';
      END;
    END IF;
  ELSE
    RAISE EXCEPTION'The current database is not a valid ADOxx database.';
  END IF;

  RAISE NOTICE'...Check for the current database done.';

  RAISE NOTICE'Starting to apply the schema changes to the current database...';

  RAISE NOTICE'Remove constraint fkmod_modtype...';    
  sqltxt := 'ALTER TABLE ' || sqlschema || '.model DROP CONSTRAINT fkmod_modtype';
  EXECUTE sqltxt;
  RAISE NOTICE'...Constraint removed.';

  RAISE NOTICE'Remove constraint fkrepoinst_class...';
  sqltxt := 'ALTER TABLE ' || sqlschema || '.repoinst DROP CONSTRAINT fkrepoinst_class';
  EXECUTE sqltxt;
  RAISE NOTICE'...Constraint removed.';
  
  RAISE NOTICE'Remove constraint fkcvalmod_avt...';    
  sqltxt := 'ALTER TABLE ' || sqlschema || '.cval_mod DROP CONSTRAINT fkcvalmod_avt';
  EXECUTE sqltxt;
  RAISE NOTICE'...Constraint removed.';

  RAISE NOTICE'Remove constraint fkcvalri_avt...';    
  sqltxt := 'ALTER TABLE ' || sqlschema || '.cval_ri DROP CONSTRAINT fkcvalri_avt';
  EXECUTE sqltxt;
  RAISE NOTICE'...Constraint removed.';

  RAISE NOTICE'Remove constraint fkcvalmi_avt...';    
  sqltxt := 'ALTER TABLE ' || sqlschema || '.cval_mi DROP CONSTRAINT fkcvalmi_avt';
  EXECUTE sqltxt;
  RAISE NOTICE'...Constraint removed.';

  RAISE NOTICE'Remove constraint fkcvalrelepi_avt...';    
  sqltxt := 'ALTER TABLE ' || sqlschema || '.cval_relepi DROP CONSTRAINT fkcvalrelepi_avt';
  EXECUTE sqltxt;
  RAISE NOTICE'...Constraint removed.';

  RAISE NOTICE'Remove constraint fkcdefval_avt...';    
  sqltxt := 'ALTER TABLE ' || sqlschema || '.complexval_defval DROP CONSTRAINT fkcdefval_avt';
  EXECUTE sqltxt;
  RAISE NOTICE'...Constraint removed.';  

  RAISE NOTICE'Remove constraint refclass_class...';    
  sqltxt := 'ALTER TABLE ' || sqlschema || '.class DROP CONSTRAINT refclass_class';
  EXECUTE sqltxt;
  RAISE NOTICE'...Constraint removed.';  

  RAISE NOTICE'Remove constraint fkctomodt_modtype...';    
  sqltxt := 'ALTER TABLE ' || sqlschema || '.classtomodtype DROP CONSTRAINT fkctomodt_modtype';
  EXECUTE sqltxt;
  RAISE NOTICE'...Constraint removed.';  

  RAISE NOTICE'Remove constraint fkctomodt_class...';    
  sqltxt := 'ALTER TABLE ' || sqlschema || '.classtomodtype DROP CONSTRAINT fkctomodt_class';
  EXECUTE sqltxt;
  RAISE NOTICE'...Constraint removed.';  

  RAISE NOTICE'Remove constraint fkmodus_modtyp...';    
  sqltxt := 'ALTER TABLE ' || sqlschema || '.modus DROP CONSTRAINT fkmodus_modtyp';
  EXECUTE sqltxt;
  RAISE NOTICE'...Constraint removed.';  

  RAISE NOTICE'Remove constraint fkctomodus_modus...';    
  sqltxt := 'ALTER TABLE ' || sqlschema || '.classtomodus DROP CONSTRAINT fkctomodus_modus';
  EXECUTE sqltxt;
  RAISE NOTICE'...Constraint removed.';  

  RAISE NOTICE'Remove constraint fkctomodus_class...';    
  sqltxt := 'ALTER TABLE ' || sqlschema || '.classtomodus DROP CONSTRAINT fkctomodus_class';
  EXECUTE sqltxt;
  RAISE NOTICE'...Constraint removed.';  

  RAISE NOTICE'Remove constraint fkcard_epdef...';    
  sqltxt := 'ALTER TABLE ' || sqlschema || '.cardinality DROP CONSTRAINT fkcard_epdef';
  EXECUTE sqltxt;
  RAISE NOTICE'...Constraint removed.';  

  RAISE NOTICE'Remove constraint fendpntrest_rc...';    
  sqltxt := 'ALTER TABLE ' || sqlschema || '.endpointrestrict DROP CONSTRAINT fendpntrest_rc';
  EXECUTE sqltxt;
  RAISE NOTICE'...Constraint removed.';  

  RAISE NOTICE'Remove constraint refavaltpy_id1...';    
  sqltxt := 'ALTER TABLE ' || sqlschema || '.attrvaltype DROP CONSTRAINT refavaltpy_id1';
  EXECUTE sqltxt;
  RAISE NOTICE'...Constraint removed.';  

  RAISE NOTICE'Remove constraint refavaltyp_id2...';    
  sqltxt := 'ALTER TABLE ' || sqlschema || '.attrvaltype DROP CONSTRAINT refavaltyp_id2';
  EXECUTE sqltxt;
  RAISE NOTICE'...Constraint removed.';  

  RAISE NOTICE'Remove constraint fkattrtyp_avaltyp...';    
  sqltxt := 'ALTER TABLE ' || sqlschema || '.attrtype DROP CONSTRAINT fkattrtyp_avaltyp';
  EXECUTE sqltxt;
  RAISE NOTICE'...Constraint removed.';  

  RAISE NOTICE'Remove constraint fkadef_atyp...';    
  sqltxt := 'ALTER TABLE ' || sqlschema || '.attrdef DROP CONSTRAINT fkadef_atyp';
  EXECUTE sqltxt;
  RAISE NOTICE'...Constraint removed.';  

  RAISE NOTICE'Remove constraint fkadob_adef...';    
  sqltxt := 'ALTER TABLE ' || sqlschema || '.objattrdefs DROP CONSTRAINT fkadob_adef';
  EXECUTE sqltxt;
  RAISE NOTICE'...Constraint removed.';  

  RAISE NOTICE'Remove constraint fkrelepi_epdef...';    
  sqltxt := 'ALTER TABLE ' || sqlschema || '.relendpntinst DROP CONSTRAINT fkrelepi_epdef';
  EXECUTE sqltxt;
  RAISE NOTICE'...Constraint removed.';  

  RAISE NOTICE'Adding column extid to table library';
  sqltxt := 'ALTER TABLE ' || sqlschema || '.library ADD COLUMN extid BYTEA;';  
  EXECUTE sqltxt;

  sqltxt := 'UPDATE ' || sqlschema || '.library SET extid = libid; ' || 'ALTER TABLE ' || sqlschema || '.library ALTER COLUMN extid SET NOT NULL;';
  EXECUTE sqltxt;
  RAISE NOTICE'...Column added.';

  RAISE NOTICE'Adding column timestamp to table library';
  sqltxt := 'ALTER TABLE ' || sqlschema || '.library ADD COLUMN timestamp TIMESTAMP;';
  EXECUTE sqltxt;

  sqltxt := 'UPDATE ' || sqlschema || '.library SET timestamp = (select now() at time zone ''utc''); ' || 'ALTER TABLE ' || sqlschema || '.library ALTER COLUMN timestamp SET NOT NULL;';
  EXECUTE sqltxt;
  RAISE NOTICE'...Column added.';

  RAISE NOTICE'Create TABLE library_log';
  IF EXISTS(SELECT * FROM information_schema.tables WHERE table_name = 'library_log' AND table_schema = schema) THEN
    RAISE EXCEPTION'Table library_log already exists.';
  ELSE
    sqltxt := 'CREATE TABLE ' || sqlschema || '.library_log('
                || 'changeid BYTEA NOT NULL, '
                || 'libid BYTEA NOT NULL, '
                || 'type SMALLINT NOT NULL, '
                || 'metadata TEXT, '
                || 'data BYTEA, '
                || 'flag INTEGER NOT NULL, '
                || 'author TEXT NOT NULL, '
                || 'timestamp BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL, '
                ||'CONSTRAINT PK_library_log PRIMARY KEY (changeid))';
    EXECUTE sqltxt;
    RAISE NOTICE'...Table created.';
  END IF;

  RAISE NOTICE'********************************************************';
  RAISE NOTICE'*                   Update version info                *';
  RAISE NOTICE'********************************************************';
  BEGIN
    RAISE NOTICE'Updating the schema version info in dbinfo...';
    sqltxt := 'UPDATE ' || sqlschema || '.dbinfo SET val2=''' || vTrgSchemaVer || ''' WHERE type=4;';
    EXECUTE sqltxt;
    RAISE NOTICE'...Schema version info updated.';
  END;

RAISE NOTICE'[Transaction commited]';
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE'Error while changing the database schema:';
    RAISE NOTICE'-> ';
    RAISE NOTICE '%', SQLERRM;
    RAISE NOTICE'No action taken.';
    ROLLBACK;
    RAISE NOTICE'[Transaction rolled back]';
END $$
