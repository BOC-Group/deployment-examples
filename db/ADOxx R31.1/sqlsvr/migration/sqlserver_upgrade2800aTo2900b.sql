BEGIN TRY
  DECLARE @vSrcSchemaVer nvarchar(50);
  DECLARE @vTrgSchemaVer nvarchar(50);
  SET @vSrcSchemaVer = 'ADOxx 28.00a'; -- source schema version
  SET @vTrgSchemaVer = 'ADOxx 29.00b'; -- target schema version

  PRINT N'********************************************************';
  PRINT N'*         Upgrade ADOxx Schema for SQL Server          *';
  PRINT N'********************************************************';
  PRINT N'* Apply schema changes to existing ADOxx database:';
  PRINT N'* - Source schema version: ' + @vSrcSchemaVer;
  PRINT N'* - Target schema version: ' + @vTrgSchemaVer;
  PRINT N'********************************************************';

  DECLARE @sqltxt nvarchar(max); -- usually, a smaller fixed value can be sufficient, but nvarchar(max) should be used e.g. for the over 4000 nvarchar SP
  DECLARE @schema nvarchar(128);
  DECLARE @cntOUT int; -- for existence checks

  PRINT N'********************************************************';
  PRINT N'* Identifying the database schema of the ADOxx tables  *';
  PRINT N'********************************************************';

  IF 1=(SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'dbinfo')
  BEGIN
    SELECT @schema=TABLE_SCHEMA FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'dbinfo'
    PRINT N'...Using schema ' + @schema;
  END
  ELSE
  BEGIN
    RAISERROR(N'Schema of ADOxx tables could not be identified.',16,1);
  END;

  PRINT N'Starting to check the current database...';

  IF EXISTS(SELECT * FROM sys.tables WHERE name = 'dbinfo' AND schema_id = SCHEMA_ID(@schema))
  BEGIN
    SET @sqltxt = N'SELECT @cnt=COUNT(*) FROM [' + @schema + N'].dbinfo WHERE [type]=4 AND val2=N''' + @vSrcSchemaVer + ''';'
    EXECUTE sp_executesql @sqltxt, N'@cnt int OUTPUT', @cnt = @cntOUT OUTPUT;
    IF @cntOUT <> 1
    BEGIN
      RAISERROR(N'The current database does not have the appropriate source schema version.',16,1);
    END
  END
  ELSE
  BEGIN
    RAISERROR(N'The current database is not a valid ADOxx database.',16,1);
  END;

  PRINT N'...Check for the current database done.';

  PRINT N'Starting to apply the schema changes to the current database...';

  BEGIN TRAN;

    PRINT N'Remove constraint fkmod_modtype...';    
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].model DROP CONSTRAINT fkmod_modtype';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Constraint removed.';

    PRINT N'Remove constraint fkrepoinst_class...';
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].repoinst DROP CONSTRAINT fkrepoinst_class';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Constraint removed.';

    PRINT N'Remove constraint fkcvalmod_avt...';    
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].cval_mod DROP CONSTRAINT fkcvalmod_avt';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Constraint removed.';

    PRINT N'Remove constraint fkcvalri_avt...';    
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].cval_ri DROP CONSTRAINT fkcvalri_avt';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Constraint removed.';

    PRINT N'Remove constraint fkcvalmi_avt...';    
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].cval_mi DROP CONSTRAINT fkcvalmi_avt';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Constraint removed.';

    PRINT N'Remove constraint fkcvalrelepi_avt...';    
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].cval_relepi DROP CONSTRAINT fkcvalrelepi_avt';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Constraint removed.';

    PRINT N'Remove constraint fkcdefval_avt...';    
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].complexval_defval DROP CONSTRAINT fkcdefval_avt';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Constraint removed.';

    PRINT N'Remove constraint refclass_class...';    
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].class DROP CONSTRAINT refclass_class';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Constraint removed.';

    PRINT N'Remove constraint fkctomodt_modtype...';    
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].classtomodtype DROP CONSTRAINT fkctomodt_modtype';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Constraint removed.';

    PRINT N'Remove constraint fkctomodt_class...';    
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].classtomodtype DROP CONSTRAINT fkctomodt_class';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Constraint removed.';

    PRINT N'Remove constraint fkmodus_modtyp...';    
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].modus DROP CONSTRAINT fkmodus_modtyp';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Constraint removed.';

    PRINT N'Remove constraint fkctomodus_modus...';    
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].classtomodus DROP CONSTRAINT fkctomodus_modus';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Constraint removed.';

    PRINT N'Remove constraint fkctomodus_class...';    
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].classtomodus DROP CONSTRAINT fkctomodus_class';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Constraint removed.';

    PRINT N'Remove constraint fkcard_epdef...';    
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].cardinality DROP CONSTRAINT fkcard_epdef';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Constraint removed.';

    PRINT N'Remove constraint fendpntrest_rc...';    
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].endpointrestrict DROP CONSTRAINT fendpntrest_rc';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Constraint removed.';

    PRINT N'Remove constraint refavaltpy_id1...';    
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].attrvaltype DROP CONSTRAINT refavaltpy_id1';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Constraint removed.';

    PRINT N'Remove constraint refavaltyp_id2...';    
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].attrvaltype DROP CONSTRAINT refavaltyp_id2';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Constraint removed.';

    PRINT N'Remove constraint fkattrtyp_avaltyp...';    
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].attrtype DROP CONSTRAINT fkattrtyp_avaltyp';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Constraint removed.';

    PRINT N'Remove constraint fkadef_atyp...';    
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].attrdef DROP CONSTRAINT fkadef_atyp';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Constraint removed.';

    PRINT N'Remove constraint fkadob_adef...';    
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].objattrdefs DROP CONSTRAINT fkadob_adef';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Constraint removed.';

    PRINT N'Remove constraint fkrelepi_epdef...';    
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].relendpntinst DROP CONSTRAINT fkrelepi_epdef';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Constraint removed.';

    PRINT N'Adding column extid to table library';
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].library ADD extid binary(16) '
    EXECUTE sp_executesql @sqltxt;

    SET @sqltxt = N'UPDATE [' + @schema + N'].library SET extid = libid '
                  +N'ALTER TABLE [' + @schema + N'].library ALTER COLUMN extid binary(16) NOT NULL'
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Column added.';

    PRINT N'Adding column timestamp to table library';
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].library ADD timestamp datetime2 '
    EXECUTE sp_executesql @sqltxt;

    SET @sqltxt = N'UPDATE [' + @schema + N'].library SET timestamp = SYSUTCDATETIME() '
                  +N'ALTER TABLE [' + @schema + N'].library ALTER COLUMN timestamp datetime2 NOT NULL'
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Column added.';

    PRINT N'Create TABLE library_log';
    IF EXISTS(SELECT * FROM sys.tables WHERE name = 'library_log' AND schema_id = SCHEMA_ID(@schema))
    BEGIN
      RAISERROR(N'Table library_log already exists.',16,1);
    END
    ELSE
    BEGIN
      SET @sqltxt = N'CREATE TABLE [' + @schema + N'].library_log('
                  +N'changeid BINARY(16) NOT NULL, '
                  +N'libid BINARY(16) NOT NULL, '
                  +N'type SMALLINT NOT NULL, '
                  +N'metadata NVARCHAR(MAX), '
                  +N'data IMAGE, '
                  +N'flag INTEGER NOT NULL, '
                  +N'author NVARCHAR(MAX) NOT NULL, '
                  +N'timestamp TIMESTAMP NOT NULL, '
                  +N'CONSTRAINT PK_library_log PRIMARY KEY (changeid))'
      EXECUTE sp_executesql @sqltxt;
      PRINT N'...Table created.';
    END;

    PRINT N'********************************************************';
    PRINT N'*                   Update version info                *';
    PRINT N'********************************************************';
    BEGIN
      PRINT N'Updating the schema version info in dbinfo...';
      SET @sqltxt = N'UPDATE [' + @schema + N'].dbinfo SET val2=''' + @vTrgSchemaVer + ''' WHERE [type]=4;'
      EXECUTE sp_executesql @sqltxt;
      PRINT N'...Schema version info updated.';
    END;

  COMMIT TRAN;
  PRINT N'[Transaction commited]';
END TRY
BEGIN CATCH
  PRINT N'Error while changing the database schema:';
  PRINT N'-> ' + ERROR_MESSAGE();
  PRINT N'No action taken.';
  IF @@TRANCOUNT > 0
  BEGIN
    ROLLBACK TRAN;
    PRINT N'[Transaction rolled back]';
  END;
END CATCH;

