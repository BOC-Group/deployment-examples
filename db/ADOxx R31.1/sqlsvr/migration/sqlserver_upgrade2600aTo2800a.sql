BEGIN TRY
  DECLARE @vSrcSchemaVer nvarchar(50);
  DECLARE @vTrgSchemaVer nvarchar(50);
  SET @vSrcSchemaVer = 'ADOxx 26.00a'; -- source schema version
  SET @vTrgSchemaVer = 'ADOxx 28.00a'; -- target schema version

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

    PRINT N'Changing trigger delMiRepoObj...';    
    SET @sqltxt = N'ALTER TRIGGER [' + @schema + N'].delMiRepoObj ON [' + @schema + N'].mi_repoobjs FOR DELETE AS '
                +N'BEGIN SET NOCOUNT ON; '
                +N'INSERT INTO [' + @schema + N'].del_val (repoid,ownerid,ownertype,actiontime) SELECT repoid,modinstid,4,CONVERT(DATETIME2,''1900-01-01 00:00:00'',120) FROM deleted; '
                +N'DELETE FROM [' + @schema + N'].modelinst FROM deleted WHERE [' + @schema + N'].modelinst.modinstid=deleted.realmodinstid; '
                +N'DELETE FROM [' + @schema + N'].relepi_repoobjs FROM deleted WHERE [' + @schema + N'].relepi_repoobjs.repoid=deleted.repoid AND [' + @schema + N'].relepi_repoobjs.realrelepiid IN (SELECT relepi.relepiid FROM [' + @schema + N'].relendpntinst relepi WHERE relepi.ownerid=deleted.modinstid); '
                +N'DELETE FROM [' + @schema + N'].permissions FROM deleted WHERE [' + @schema + N'].permissions.contextid=(SELECT r.repoid FROM [' + @schema + N'].repository r WHERE r.realrepoid=deleted.repoid) AND [' + @schema + N'].permissions.objectid=deleted.modinstid; '
                +N'END;'    
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Trigger changed.';

    PRINT N'Creating trigger insertMiRepoobjs...';
    SET @sqltxt = N'CREATE TRIGGER [' + @schema + N'].insertMiRepoobjs ON [' + @schema + N'].mi_repoobjs FOR INSERT AS '
                +N'BEGIN SET NOCOUNT ON; '
                +N'DELETE FROM [' + @schema + N'].del_val FROM inserted WHERE [' + @schema + N'].del_val.repoid = inserted.repoid AND [' + @schema + N'].del_val.ownerid = inserted.modinstid; '
                +N'END;'    
    EXECUTE (@sqltxt);
    PRINT N'...Trigger created.';

    PRINT N'Changing type of column strdata in table generic_data';
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].generic_data ALTER COLUMN strdata nvarchar(max)';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Column changed.';

    PRINT N'Create TABLE int_data';
    IF EXISTS(SELECT * FROM sys.tables WHERE name = 'int_data' AND schema_id = SCHEMA_ID(@schema))
    BEGIN
      RAISERROR(N'Table int_data already exists.',16,1);
    END
    ELSE
    BEGIN
      SET @sqltxt = N'CREATE TABLE [' + @schema + N'].int_data('
                  +N'dataid BINARY(16) NOT NULL,'
                  +N'subid BINARY(16),'
                  +N'ownerid BINARY(16),'
                  +N'flags INTEGER NOT NULL,'
                  +N'creationdate DATETIME2 NOT NULL,'
                  +N'expirydate DATETIME2,'
                  +N'data VARBINARY(MAX) NOT NULL,'
                  +N'idata NVARCHAR(2048) NOT NULL)'        
      EXECUTE sp_executesql @sqltxt;
      PRINT N'...Table created.';
    END;

    PRINT N'Create INDEX cix_intdata_dataid_subid_ownerid';
    IF EXISTS(SELECT * FROM sys.indexes ind, sys.tables t
               WHERE ind.object_id = t.object_id
               AND t.schema_id = SCHEMA_ID(@schema)
               AND ind.name = N'cix_intdata_dataid_subid_ownerid'
               AND t.name = N'int_data')
    BEGIN
      RAISERROR(N'Index cix_intdata_dataid_subid_ownerid on table int_data already exists.',16,1);
    END
    ELSE
    BEGIN
      SET @sqltxt = N'CREATE UNIQUE CLUSTERED INDEX cix_intdata_dataid_subid_ownerid ON [' + @schema + N'].int_data (dataid, subid, ownerid)';
      EXECUTE sp_executesql @sqltxt;
      PRINT N'...Index created.';
    END;

    PRINT N'Create INDEX iintdata_ownerid_expirydate';
    IF EXISTS(SELECT * FROM sys.indexes ind, sys.tables t
               WHERE ind.object_id = t.object_id
               AND t.schema_id = SCHEMA_ID(@schema)
               AND ind.name = N'iintdata_ownerid_expirydate'
               AND t.name = N'int_data')
    BEGIN
      RAISERROR(N'Index iintdata_ownerid_expirydate on table int_data already exists.',16,1);
    END
    ELSE
    BEGIN
      SET @sqltxt = N'CREATE INDEX iintdata_ownerid_expirydate ON [' + @schema + N'].int_data (ownerid, expirydate)';
      EXECUTE sp_executesql @sqltxt;
      PRINT N'...Index created.';
    END;

    PRINT N'Create XLONGSTRING attribute';
    SET @sqltxt = N'INSERT INTO [' + @schema + N'].attrvaltype '
                  + N'VALUES (CONVERT(BINARY(16), ''0x4BC3EDA7F291A144814157AC5F61B60A'', 1), CONVERT(BINARY(16), ''0x4BC3EDA7F291A144814157AC5F61B60A'', 1), CONVERT(BINARY(16), ''0x4BC3EDA7F291A144814157AC5F61B60A'', 1), 4, 0) '
                  + N'INSERT INTO [' + @schema + N'].attrtype '
                  + N'VALUES (CONVERT(BINARY(16), ''0x1B149F5C70795F40A73B235185D7F855'', 1),4, CONVERT(BINARY(16), ''0x4BC3EDA7F291A144814157AC5F61B60A'', 1))';
    EXECUTE sp_executesql @sqltxt;      
    PRINT N'...Attribute created.';

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

