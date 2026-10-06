BEGIN TRY
  DECLARE @vSrcSchemaVer nvarchar(50);
  DECLARE @vTrgSchemaVer nvarchar(50);
  SET @vSrcSchemaVer = 'ADOxx 25.00b'; -- source schema version
  SET @vTrgSchemaVer = 'ADOxx 26.00a'; -- target schema version

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

  DECLARE @minint INTEGER  = -2147483500; -- IDENTITY start if no data yet

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

    PRINT N'Drop delInstancename...';
    SET @sqltxt = N'DROP TRIGGER  [' + @schema + N'].delInstancename';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Trigger dropped.';

    PRINT N'Drop insInstancename...';
    SET @sqltxt = N'DROP TRIGGER  [' + @schema + N'].insInstancename';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Trigger dropped.';

    PRINT N'Removing target names...';
    SET @sqltxt = N'DELETE FROM [' + @schema + N'].instancename WHERE '
                  +N'EXISTS (SELECT * FROM [' + @schema + N'].ri_repoobjs WHERE ri_repoobjs.repoid = instancename.repoid and instancename.instid = ri_repoobjs.repoinstid) '
                  +N'OR EXISTS (SELECT * FROM [' + @schema + N'].mod_repoobjs WHERE mod_repoobjs.repoid = instancename.repoid and instancename.instid = mod_repoobjs.modelid)';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Names removed.';

    PRINT N'Copying target names...';
    SET @sqltxt = N'INSERT INTO [' + @schema + N'].instancename '
                  +N'SELECT brokenep_iname.repoid, relepi_ro.relepiid, brokenep_iname.names, ep_brokenep_iname.actiontime '
                  +N'FROM [' + @schema + N'].brokenep_iname, [' + @schema + N'].ep_brokenep_iname, [' + @schema + N'].relepi_repoobjs relepi_ro '
                  +N'WHERE brokenep_iname.realbrokenepnameid = ep_brokenep_iname.brokenepnameid AND relepi_ro.realrelepiid = ep_brokenep_iname.relepiid';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Names copied.';

    PRINT N'Changing trigger delRelEpInst...';
    SET @sqltxt = N'ALTER TRIGGER [' + @schema + N'].delRelEpInst ON [' + @schema + N'].relendpntinst FOR DELETE AS '
                +N'BEGIN SET NOCOUNT ON; '
                +N'DECLARE @instid binary(16); '
                +N'DELETE FROM [' + @schema + N'].valowner_relepi FROM deleted WHERE [' + @schema + N'].valowner_relepi.ownerid=deleted.relepiid; '
                +N'INSERT INTO [' + @schema + N'].dep_activities SELECT relepi_ro.repoid, relepi_ro.relepiid, deleted.broken, deleted.epdefid, deleted.modelid, '
                +N'deleted.modeltypeid, deleted.ownerid, deleted.ownertype, deleted.ownerclassid, deleted.targetclassid, deleted.targetinstid, deleted.targettype, deleted.twinepid, deleted.proxyid, SYSUTCDATETIME(), 0 '
                +N'FROM deleted INNER JOIN [' + @schema + N'].relepi_repoobjs relepi_ro ON relepi_ro.realrelepiid = deleted.relepiid; END';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Trigger changed.';

    PRINT N'Changing trigger upsertRelEpInst...';
    SET @sqltxt = N'ALTER TRIGGER [' + @schema + N'].upsertRelEpInst ON [' + @schema + N'].relendpntinst FOR INSERT, UPDATE AS '
                +N'BEGIN SET NOCOUNT ON; '
                +N'DECLARE @action SMALLINT; SET @action = 0; '
                +N'IF EXISTS(SELECT * FROM deleted) '
                +N'BEGIN IF EXISTS(SELECT * FROM inserted i, deleted d WHERE i.relepiid = d.relepiid AND i.broken <> d.broken) '
                +N'BEGIN SET @action = @action | 1; END; '
                +N'IF EXISTS(SELECT * FROM inserted i, deleted d WHERE i.relepiid = d.relepiid AND i.twinepid <> d.twinepid) '
                +N'BEGIN SET @action = @action | 2; END; '
                +N'IF EXISTS(SELECT * FROM inserted i, deleted d WHERE i.relepiid = d.relepiid AND i.targetinstid <> d.targetinstid) '
                +N'BEGIN SET @action = @action | 4; END; '
                +N'END ELSE BEGIN '
                +N'SET @action = 8; END; '
                +N'IF (@action <> 0) BEGIN ' 
                +N'INSERT INTO [' + @schema + N'].dep_activities '
                +N'SELECT relepi_ro.repoid,relepi_ro.relepiid,inserted.broken,inserted.epdefid,inserted.modelid,inserted.modeltypeid,inserted.ownerid,inserted.ownertype,inserted.ownerclassid,inserted.targetclassid, '
                +N'inserted.targetinstid,inserted.targettype,inserted.twinepid,inserted.proxyid,SYSUTCDATETIME(),@action '
                +N'FROM [' + @schema + N'].relepi_repoobjs relepi_ro, inserted WHERE relepi_ro.realrelepiid = inserted.relepiid END; END';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Trigger changed.';

    PRINT N'Changing trigger delRepiRepoObj...';
    SET @sqltxt = N'ALTER TRIGGER [' + @schema + N'].delRepiRepoObj ON [' + @schema + N'].relepi_repoobjs FOR DELETE AS '
                +N'BEGIN SET NOCOUNT ON; '
                +N'INSERT INTO [' + @schema + N'].dep_activities '
                +N'SELECT deleted.repoid,deleted.relepiid,relepi.broken,relepi.epdefid,relepi.modelid,relepi.modeltypeid,relepi.ownerid,relepi.ownertype, '
                +N'relepi.ownerclassid,relepi.targetclassid,relepi.targetinstid,relepi.targettype,relepi.twinepid,relepi.proxyid,SYSUTCDATETIME(),0 '
                +N'FROM deleted INNER JOIN [' + @schema + N'].relendpntinst relepi ON relepi.relepiid = deleted.realrelepiid; '
                +N'DELETE FROM [' + @schema + N'].relendpntinst FROM deleted WHERE [' + @schema + N'].relendpntinst.relepiid = deleted.realrelepiid; END';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Trigger changed.';

    PRINT N'Changing trigger delRep...';
    SET @sqltxt = N'ALTER TRIGGER [' + @schema + N'].delRep ON [' + @schema + N'].repository FOR DELETE AS '
                +N'BEGIN SET NOCOUNT ON; '
                +N'DELETE FROM [' + @schema + N'].libobjs FROM deleted WHERE [' + @schema + N'].libobjs.objid = deleted.repoid; '
                +N'DELETE FROM [' + @schema + N'].directories FROM deleted WHERE [' + @schema + N'].directories.repoid=deleted.realrepoid; '
                +N'DELETE FROM [' + @schema + N'].valowner_mi_arch FROM deleted WHERE [' + @schema + N'].valowner_mi_arch.ownerid IN (SELECT realmodinstid FROM [' + @schema + N'].mi_repoobjs WHERE repoid = deleted.realrepoid); '
                +N'DELETE FROM [' + @schema + N'].valowner_mod_arch FROM deleted WHERE [' + @schema + N'].valowner_mod_arch.ownerid IN (SELECT realmodelid FROM [' + @schema + N'].mod_repoobjs WHERE repoid = deleted.realrepoid); '
                +N'DELETE FROM [' + @schema + N'].valowner_ri_arch FROM deleted WHERE [' + @schema + N'].valowner_ri_arch.ownerid IN (SELECT realrepoinstid FROM [' + @schema + N'].ri_repoobjs WHERE repoid = deleted.realrepoid); '
                +N'DELETE FROM [' + @schema + N'].ci_repoobjs FROM deleted WHERE [' + @schema + N'].ci_repoobjs.repoid = deleted.realrepoid; '
                +N'DELETE FROM [' + @schema + N'].mod_repoobjs FROM deleted WHERE [' + @schema + N'].mod_repoobjs.repoid = deleted.realrepoid;' 
                +N'DELETE FROM [' + @schema + N'].ri_repoobjs FROM deleted WHERE [' + @schema + N'].ri_repoobjs.srcrepoid = deleted.realrepoid;' 
                +N'DELETE FROM [' + @schema + N'].ri_repoobjs FROM deleted WHERE [' + @schema + N'].ri_repoobjs.repoid = deleted.realrepoid; '
                +N'DELETE FROM [' + @schema + N'].mi_repoobjs FROM deleted WHERE [' + @schema + N'].mi_repoobjs.repoid = deleted.realrepoid; '
                +N'DELETE FROM [' + @schema + N'].relepi_repoobjs FROM deleted WHERE [' + @schema + N'].relepi_repoobjs.repoid = deleted.realrepoid; '
                +N'DELETE FROM [' + @schema + N'].hg_repoobjs FROM deleted WHERE [' + @schema + N'].hg_repoobjs.repoid = deleted.realrepoid; '
                +N'DELETE FROM [' + @schema + N'].permissions FROM deleted WHERE [' + @schema + N'].permissions.objectid = deleted.repoid; '
                +N'DELETE FROM [' + @schema + N'].permissions FROM deleted WHERE [' + @schema + N'].permissions.contextid = deleted.repoid; '
                +N'DELETE FROM [' + @schema + N'].name FROM deleted WHERE [' + @schema + N'].name.objid = deleted.repoid; '
                +N'DELETE FROM [' + @schema + N'].identifiertext FROM deleted WHERE [' + @schema + N'].identifiertext.objid = deleted.repoid; '
                +N'DELETE FROM [' + @schema + N'].dep_activities FROM deleted WHERE [' + @schema + N'].dep_activities.repoid = deleted.realrepoid; '
                +N'DELETE FROM [' + @schema + N'].del_val FROM deleted WHERE [' + @schema + N'].del_val.repoid = deleted.realrepoid; '
                +N'DELETE FROM [' + @schema + N'].delayedaction FROM deleted WHERE [' + @schema + N'].delayedaction.repoid = deleted.realrepoid; END';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Trigger changed.';

    PRINT N'Drop del_ep_brokenep_iname...';
    SET @sqltxt = N'DROP TABLE  [' + @schema + N'].del_ep_brokenep_iname';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Table dropped.';

    PRINT N'Drop del_instancename...';
    SET @sqltxt = N'DROP TABLE  [' + @schema + N'].del_instancename';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Table dropped.';

    PRINT N'Drop ep_brokenep_iname...';
    SET @sqltxt = N'DROP TABLE  [' + @schema + N'].ep_brokenep_iname';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Table dropped.';

    PRINT N'Drop brokenep_iname...';
    SET @sqltxt = N'DROP TABLE  [' + @schema + N'].brokenep_iname';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Table dropped.';

    PRINT N'Drop usp_LoadChangedValuesPerOwnerType...';
    SET @sqltxt = N'DROP PROCEDURE  [' + @schema + N'].usp_LoadChangedValuesPerOwnerType';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Procedure dropped.';
    
    PRINT N'Dropping constraint PK_metamodelright';
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].metamodelright DROP CONSTRAINT PK_metamodelright';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Constraint dropped.';

    PRINT N'Adding column subid1 to table metamodelright';
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].metamodelright ADD subid1 binary(16) not null default 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Column added.';

    PRINT N'Adding column subid2 to table metamodelright';
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].metamodelright ADD subid2 binary(16) not null default 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Column added.';

    PRINT N'Adding modified constraint PK_metamodelright';
    SET @sqltxt = N'ALTER TABLE [' + @schema + N'].metamodelright ADD CONSTRAINT PK_metamodelright PRIMARY KEY (roleid,actionid,targetid,targetctxtid,subid1,subid2)';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Constraint added.';
    
    PRINT N'Changing trigger delClass...';
    SET @sqltxt = N'ALTER TRIGGER [' + @schema + N'].delClass ON [' + @schema + N'].class FOR DELETE AS '
                  +N'BEGIN '
                  +N'SET NOCOUNT ON; '
                  +N'DELETE FROM [' + @schema + N'].name FROM deleted WHERE [' + @schema + N'].name.objid = deleted.classid; '
                  +N'DELETE FROM [' + @schema + N'].identifiertext FROM deleted WHERE [' + @schema + N'].identifiertext.objid = deleted.classid; '
                  +N'DELETE FROM [' + @schema + N'].libobjs FROM deleted WHERE [' + @schema + N'].libobjs.objid = deleted.classid; '
                  +N'DELETE FROM [' + @schema + N'].direct_libobjs FROM deleted WHERE [' + @schema + N'].direct_libobjs.objid = deleted.classid; '
                  +N'DELETE FROM [' + @schema + N'].objattrdefs FROM deleted WHERE [' + @schema + N'].objattrdefs.objid = deleted.classid; '
                  +N'DELETE FROM [' + @schema + N'].cardinality FROM deleted WHERE [' + @schema + N'].cardinality.objectid = deleted.classid; '
                  +N'DELETE FROM [' + @schema + N'].valowner_lib FROM deleted WHERE [' + @schema + N'].valowner_lib.ownerid = deleted.classid; '
                  +N'DELETE FROM [' + @schema + N'].metamodelright FROM deleted WHERE [' + @schema + N'].metamodelright.targetid = deleted.classid; '
                  +N'DELETE FROM [' + @schema + N'].metamodelright FROM deleted WHERE [' + @schema + N'].metamodelright.targetctxtid = deleted.classid; '
                  +N'DELETE FROM [' + @schema + N'].metamodelright FROM deleted WHERE [' + @schema + N'].metamodelright.subid1 = deleted.classid; '
                  +N'DELETE FROM [' + @schema + N'].metamodelright FROM deleted WHERE [' + @schema + N'].metamodelright.subid2 = deleted.classid; '
                  +N'END';
    EXECUTE sp_executesql @sqltxt;
    PRINT N'...Trigger changed.';

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

