/* Verify the recovery model for AdventureWorks2014 */ 
USE [master];
GO

SELECT [name], [recovery_model_desc]
FROM [sys].[databases]
WHERE [name] = 'AdventureWorks2014'
GO

ALTER DATABASE [AdventureWorks2014] SET RECOVERY FULL;
GO

/* 
	Run a full backup 
*/
DECLARE @BackupPath NVARCHAR(100);
SET @BackupPath = 'C:\Backups\AW2014_' + 
	REPLACE(CONVERT(nvarchar(19),SYSDATETIME(), 126), ':','') + '.bak';

BACKUP DATABASE [AdventureWorks2014] 
	TO  DISK = @BackupPath
	WITH NOFORMAT, 
	INIT,   
	COMPRESSION,  
	STATS = 10;
GO


/*
	Run a log backup 
*/
DECLARE @BackupPath NVARCHAR(100);
SET @BackupPath = 'C:\Backups\AW2014_LOG_' + 
	REPLACE(CONVERT(nvarchar(19),SYSDATETIME(), 126), ':','') + '.trn';

BACKUP LOG [AdventureWorks2014] 
	TO  DISK = @BackupPath
	WITH NOFORMAT, 
	INIT,   
	COMPRESSION,  
	STATS = 10;
GO


/*
	Set file growth low
*/
USE [master];
GO
ALTER DATABASE [AdventureWorks2014] MODIFY FILE ( NAME = N'AdventureWorks2014_Log', FILEGROWTH = 10%);
GO


/*
	Check log file configuration
*/
USE [AdventureWorks2014];
GO

SELECT
	[file_id],
	[type],
	[name],
	[physical_name],
	CAST([size] as DECIMAL(38,0))/128. [FileSizeMB], 
	CAST(FILEPROPERTY([name],'SpaceUsed') AS DECIMAL(38,0))/128. [SpaceUsedMB], 
	(CAST([size] as DECIMAL(38,0))/128) - (CAST(FILEPROPERTY([name],'SpaceUsed') 
		AS DECIMAL(38,0))/128.) [EmptySpaceMB],
	[growth]
FROM [AdventureWorks2014].[sys].[database_files]
WHERE [type] = 1;


/*
	Check VLFs
*/
DBCC LOGINFO('AdventureWorks2014');
GO
--note number of VLFs: 


/*
	Modify some data
*/
USE [AdventureWorks2014];
GO

UPDATE [Person].[Person]
SET [LastName] = 'Stark'
WHERE [FirstName] = 'Tony';

UPDATE [Person].[Person]
SET [LastName] = 'Stark'
WHERE [FirstName] like 'T%';

UPDATE [Person].[Person]
SET [Title] = 'Mr.'
WHERE [LastName] IN ('Stark');


/*
	Check VLFs again
*/
DBCC LOGINFO('AdventureWorks2014');
GO
--note number of VLFs:


/*
	Issue a checkpoint
*/
CHECKPOINT;
GO


/*
	Check VLFs again
*/
DBCC LOGINFO('AdventureWorks2014');
GO


/*
	Modify more data and then check VLFs
*/
UPDATE [Sales].[SalesOrderDetail]
SET [ModifiedDate] = GETDATE();
GO

/*
	Checkpoint again
*/
CHECKPOINT;
GO

DBCC LOGINFO('AdventureWorks2014');
GO


/*
	Take a log backup
*/
DECLARE @BackupPath NVARCHAR(100);
SET @BackupPath = 'C:\Backups\AW2014_TLog_' + 
	REPLACE(CONVERT(nvarchar(19),SYSDATETIME(), 126), ':','') + '.bak';

BACKUP LOG [AdventureWorks2014] 
	TO  DISK = @BackupPath
	WITH INIT,  
	STATS = 10;
GO


/*
	A final look at the VLFs 
*/
DBCC LOGINFO('AdventureWorks2014');
GO