BEGIN TRY
  DECLARE @vSrcSchemaVer nvarchar(50);
  DECLARE @vTrgSchemaVer nvarchar(50);
  SET @vSrcSchemaVer = 'ADOxx 29.00b'; -- source schema version
  SET @vTrgSchemaVer = 'ADOxx 30.00a'; -- target schema version

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

    PRINT N'********************************************************';
    PRINT N'*             Updating upsertRelEpInst trigger         *';
    PRINT N'********************************************************';
    BEGIN
      PRINT N'Dropping existing upsertRelEpInst trigger...';
      SET @sqltxt = N'
      IF EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N''[' + @schema + N'].upsertRelEpInst''))
      BEGIN
          DROP TRIGGER [' + @schema + N'].upsertRelEpInst;
      END';
      EXECUTE sp_executesql @sqltxt;
      PRINT N'...Existing trigger dropped.';

      PRINT N'Creating new upsertRelEpInst trigger...';
      SET @sqltxt = N'
      CREATE TRIGGER [' + @schema + N'].upsertRelEpInst
      ON [' + @schema + N'].relendpntinst
      FOR INSERT, UPDATE
      AS
      BEGIN
          SET NOCOUNT ON;
          DECLARE @action SMALLINT;
          SET @action = 0;
          IF EXISTS (SELECT * FROM deleted)
          BEGIN
              IF EXISTS
              (
                  SELECT *
                  FROM inserted i,
                       deleted d
                  WHERE i.relepiid = d.relepiid
                        AND i.broken <> d.broken
              )
              BEGIN
                  SET @action = @action | 1;
              END;
              IF EXISTS
              (
                  SELECT *
                  FROM inserted i,
                       deleted d
                  WHERE i.relepiid = d.relepiid
                        AND i.twinepid <> d.twinepid
              )
              BEGIN
                  SET @action = @action | 2;
              END;
              IF EXISTS
              (
                  SELECT *
                  FROM inserted i,
                       deleted d
                  WHERE i.relepiid = d.relepiid
                        AND i.targetinstid <> d.targetinstid
              )
              BEGIN
                  SET @action = @action | 4;
              END;
          END
          ELSE
          BEGIN
              SET @action = 8;
          END;
          IF (@action <> 0)
          BEGIN
              INSERT INTO [' + @schema + N'].dep_activities
              SELECT relepi_ro.repoid,
                     relepi_ro.relepiid,
                     inserted.broken,
                     inserted.epdefid,
                     inserted.modelid,
                     inserted.modeltypeid,
                     inserted.ownerid,
                     inserted.ownertype,
                     inserted.ownerclassid,
                     inserted.targetclassid,
                     inserted.targetinstid,
                     inserted.targettype,
                     inserted.twinepid,
                     inserted.proxyid,
                     SYSUTCDATETIME(),
                     @action
              FROM [' + @schema + N'].relepi_repoobjs relepi_ro,
                   inserted
              WHERE relepi_ro.realrelepiid = inserted.relepiid
          END;
      END;';
      EXECUTE sp_executesql @sqltxt;
      PRINT N'...New trigger created.';
    END;

    PRINT N'********************************************************';
    PRINT N'*          Removing int_data table and related         *';
    PRINT N'********************************************************';
    BEGIN
      -- Drop foreign key constraints that reference int_data
      PRINT N'Dropping foreign key constraints referencing int_data...';
      DECLARE @constraintName NVARCHAR(128);
      DECLARE @tableName NVARCHAR(128);
      DECLARE constraint_cursor CURSOR FOR
        SELECT 
          fk.name AS constraint_name,
          OBJECT_NAME(fk.parent_object_id) AS table_name
        FROM sys.foreign_keys fk
        INNER JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
        INNER JOIN sys.tables t ON fkc.referenced_object_id = t.object_id
        WHERE t.name = 'int_data' AND t.schema_id = SCHEMA_ID(@schema);

      OPEN constraint_cursor;
      FETCH NEXT FROM constraint_cursor INTO @constraintName, @tableName;
      
      WHILE @@FETCH_STATUS = 0
      BEGIN
        SET @sqltxt = N'ALTER TABLE [' + @schema + N'].[' + @tableName + N'] DROP CONSTRAINT [' + @constraintName + N'];';
        EXECUTE sp_executesql @sqltxt;
        PRINT N'...Dropped constraint ' + @constraintName + N' from table ' + @tableName;
        FETCH NEXT FROM constraint_cursor INTO @constraintName, @tableName;
      END;
      
      CLOSE constraint_cursor;
      DEALLOCATE constraint_cursor;

      -- Drop indexes on int_data table
      PRINT N'Dropping indexes on int_data table...';
      DECLARE @indexName NVARCHAR(128);
      DECLARE index_cursor CURSOR FOR
        SELECT i.name
        FROM sys.indexes i
        INNER JOIN sys.tables t ON i.object_id = t.object_id
        WHERE t.name = 'int_data' 
          AND t.schema_id = SCHEMA_ID(@schema)
          AND i.name IS NOT NULL
          AND i.is_primary_key = 0;

      OPEN index_cursor;
      FETCH NEXT FROM index_cursor INTO @indexName;
      
      WHILE @@FETCH_STATUS = 0
      BEGIN
        SET @sqltxt = N'DROP INDEX [' + @indexName + N'] ON [' + @schema + N'].[int_data];';
        EXECUTE sp_executesql @sqltxt;
        PRINT N'...Dropped index ' + @indexName;
        FETCH NEXT FROM index_cursor INTO @indexName;
      END;
      
      CLOSE index_cursor;
      DEALLOCATE index_cursor;

      -- Drop triggers on int_data table
      PRINT N'Dropping triggers on int_data table...';
      DECLARE @triggerName NVARCHAR(128);
      DECLARE trigger_cursor CURSOR FOR
        SELECT tr.name
        FROM sys.triggers tr
        INNER JOIN sys.tables t ON tr.parent_id = t.object_id
        WHERE t.name = 'int_data' AND t.schema_id = SCHEMA_ID(@schema);

      OPEN trigger_cursor;
      FETCH NEXT FROM trigger_cursor INTO @triggerName;
      
      WHILE @@FETCH_STATUS = 0
      BEGIN
        SET @sqltxt = N'DROP TRIGGER [' + @schema + N'].[' + @triggerName + N'];';
        EXECUTE sp_executesql @sqltxt;
        PRINT N'...Dropped trigger ' + @triggerName;
        FETCH NEXT FROM trigger_cursor INTO @triggerName;
      END;
      
      CLOSE trigger_cursor;
      DEALLOCATE trigger_cursor;

      -- Drop views that reference int_data
      PRINT N'Dropping views that reference int_data...';
      DECLARE @viewName NVARCHAR(128);
      DECLARE view_cursor CURSOR FOR
        SELECT DISTINCT v.name
        FROM sys.views v
        INNER JOIN sys.sql_dependencies d ON v.object_id = d.object_id
        INNER JOIN sys.tables t ON d.referenced_major_id = t.object_id
        WHERE t.name = 'int_data' 
          AND t.schema_id = SCHEMA_ID(@schema)
          AND v.schema_id = SCHEMA_ID(@schema);

      OPEN view_cursor;
      FETCH NEXT FROM view_cursor INTO @viewName;
      
      WHILE @@FETCH_STATUS = 0
      BEGIN
        SET @sqltxt = N'DROP VIEW [' + @schema + N'].[' + @viewName + N'];';
        EXECUTE sp_executesql @sqltxt;
        PRINT N'...Dropped view ' + @viewName;
        FETCH NEXT FROM view_cursor INTO @viewName;
      END;
      
      CLOSE view_cursor;
      DEALLOCATE view_cursor;

      -- Drop stored procedures that reference int_data
      PRINT N'Dropping stored procedures that reference int_data...';
      DECLARE @procName NVARCHAR(128);
      DECLARE proc_cursor CURSOR FOR
        SELECT DISTINCT p.name
        FROM sys.procedures p
        INNER JOIN sys.sql_dependencies d ON p.object_id = d.object_id
        INNER JOIN sys.tables t ON d.referenced_major_id = t.object_id
        WHERE t.name = 'int_data' 
          AND t.schema_id = SCHEMA_ID(@schema)
          AND p.schema_id = SCHEMA_ID(@schema);

      OPEN proc_cursor;
      FETCH NEXT FROM proc_cursor INTO @procName;
      
      WHILE @@FETCH_STATUS = 0
      BEGIN
        SET @sqltxt = N'DROP PROCEDURE [' + @schema + N'].[' + @procName + N'];';
        EXECUTE sp_executesql @sqltxt;
        PRINT N'...Dropped procedure ' + @procName;
        FETCH NEXT FROM proc_cursor INTO @procName;
      END;
      
      CLOSE proc_cursor;
      DEALLOCATE proc_cursor;

      -- Finally, drop the int_data table itself
      PRINT N'Dropping int_data table...';
      IF EXISTS(SELECT * FROM sys.tables WHERE name = 'int_data' AND schema_id = SCHEMA_ID(@schema))
      BEGIN
        SET @sqltxt = N'DROP TABLE [' + @schema + N'].[int_data];';
        EXECUTE sp_executesql @sqltxt;
        PRINT N'...int_data table dropped successfully.';
      END
      ELSE
      BEGIN
        PRINT N'...int_data table does not exist, skipping.';
      END;

      PRINT N'...All int_data related objects removed.';
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

