USE [AdventureWorks2014];
GO


/*
	Verify full recovery
*/
USE [master];
GO
ALTER DATABASE [AdventureWorks2014] SET RECOVERY FULL WITH NO_WAIT;
GO


/*
	Check log space utilization
*/
DBCC SQLPERF (LOGSPACE);


/*
	Change autogrowth for the log
*/
USE [master];
GO
ALTER DATABASE [AdventureWorks2014] MODIFY FILE 
( NAME = N'AdventureWorks2012_Log', FILEGROWTH = 1024KB );
GO


/*
	Create a table to track history
*/
CREATE TABLE [AdventureWorks2014].[dbo].[Track_LogSpace] (
	[DatabaseName] VARCHAR(250),
	[LogSizeMB] DECIMAL(38),
	[LogSpaceUsed] DECIMAL(38),
	[LogStatus] TINYINT,
	[CaptureDate] DATETIME2 DEFAULT GETDATE()
	);


/*
	Run these statements in a job on a regular basis
*/
CREATE TABLE #LogSpace_Temp (
	[DatabaseName] VARCHAR(100),
	[LogSizeMB] DECIMAL(10,2),
	[LogSpaceUsed] DECIMAL(10,2),
	[LogStatus] VARCHAR(1)
	);

INSERT INTO #LogSpace_Temp EXEC('DBCC SQLPERF(logspace)');

INSERT INTO [AdventureWorks2014].[dbo].[Track_LogSpace] 
	([DatabaseName], [LogSizeMB], [LogSpaceUsed], [LogStatus])
	SELECT [DatabaseName], [LogSizeMB], [LogSpaceUsed], [LogStatus]
	FROM #LogSpace_Temp;

DROP TABLE #LogSpace_Temp;


/*
	Snapshot log space
*/
--EXEC msdb.dbo.sp_start_job N'SQLskills - Track Log Space Use';


/*
	Generate a bunch of transaction log, then re-run above statements
*/
USE [AdventureWorks2014];
GO

UPDATE [Sales].[SalesOrderDetail] 
SET [ModifiedDate] = SYSDATETIME();

EXEC msdb.dbo.sp_start_job N'SQLskills - Track Log Space Use';

UPDATE [Person].[Person]
SET [LastName] = 'Stark'
WHERE [FirstName] = 'Tony';

UPDATE [Person].[Person]
SET [LastName] = 'Stark'
WHERE [FirstName] like 'T%';

UPDATE [Person].[Person]
SET [Title] = 'Mr.'
WHERE [LastName] IN ('Stark');

UPDATE [Person].[Person]
SET [LastName] = 'Wayne'
WHERE [FirstName] like 'Bruce';

EXEC msdb.dbo.sp_start_job N'SQLskills - Track Log Space Use';

UPDATE [Person].[Person]
SET [LastName] = 'Howlett'
WHERE [FirstName] like 'James';

UPDATE [Person].[Person]
SET [LastName] = 'Xavier'
WHERE [FirstName] like 'Charles';

UPDATE [Person].[Person]
SET [LastName] = 'Bristow'
WHERE [FirstName] like 'Sydney';

UPDATE [Person].[Person]
SET [Title] = 'Ms.'
WHERE [LastName] = 'Bristow';

EXEC msdb.dbo.sp_start_job N'SQLskills - Track Log Space Use';

UPDATE [Person].[Person]
SET [Title] = 'Mr.'
WHERE [LastName] IN ('Stark', 'Wayne', 'Howlett', 'Xavier');

UPDATE [Person].[Person]
SET [ModifiedDate] = GETDATE()
WHERE [LastName] IN ('Stark', 'Wayne', 'Howlett', 'Bristow', 'Xavier');

UPDATE [Person].[Person]
SET [ModifiedDate] = GETDATE()
WHERE [PersonType] = 'SC' ;

UPDATE [Person].[Person]
SET [ModifiedDate] = GETDATE()
WHERE [PersonType] <> 'IN' ;

EXEC msdb.dbo.sp_start_job N'SQLskills - Track Log Space Use';



/*
	Look at utilization over time
*/

SELECT * 
FROM [AdventureWorks2014].[dbo].[Track_LogSpace]  
WHERE [DatabaseName] = 'AdventureWorks2014' 
ORDER BY [CaptureDate];

------------------------------------------------------------------------------

/*
	Check wait stats
*/
SELECT *
FROM [sys].[dm_os_wait_stats];
GO


/*
	Not incredibly useful, try this instead...
	http://www.sqlskills.com/BLOGS/PAUL/post/Wait-statistics-or-please-tell-me-where-it-hurts.aspx
*/
WITH Waits AS
    (SELECT
        wait_type,
        wait_time_ms / 1000.0 AS WaitS,
        (wait_time_ms - signal_wait_time_ms) / 1000.0 AS ResourceS,
        signal_wait_time_ms / 1000.0 AS SignalS,
        waiting_tasks_count AS WaitCount,
        100.0 * wait_time_ms / SUM (wait_time_ms) OVER() AS Percentage,
        ROW_NUMBER() OVER(ORDER BY wait_time_ms DESC) AS RowNum
    FROM sys.dm_os_wait_stats
    WHERE wait_type NOT IN (
	        N'BROKER_EVENTHANDLER',					N'BROKER_RECEIVE_WAITFOR',
			N'BROKER_TASK_STOP',					N'BROKER_TO_FLUSH',
			N'BROKER_TRANSMITTER',					N'CHECKPOINT_QUEUE',
			N'CHKPT',								N'CLR_AUTO_EVENT',
			N'CLR_MANUAL_EVENT',					N'CLR_SEMAPHORE',
			N'DBMIRROR_DBM_EVENT',					N'DBMIRROR_EVENTS_QUEUE',
			N'DBMIRROR_WORKER_QUEUE',				N'DBMIRRORING_CMD',
			N'DIRTY_PAGE_POLL',						N'DISPATCHER_QUEUE_SEMAPHORE',
			N'EXECSYNC',							N'FSAGENT',
			N'FT_IFTS_SCHEDULER_IDLE_WAIT',			N'HADR_CLUSAPI_CALL',
			N'HADR_FILESTREAM_IOMGR_IOCOMPLETION',	N'KSOURCE_WAKEUP',
			N'LAZYWRITER_SLEEP',					N'LOGMGR_QUEUE',
			N'ONDEMAND_TASK_QUEUE',					N'PWAIT_ALL_COMPONENTS_INITIALIZED',
			N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',	N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',
			N'QDS_SHUTDOWN_QUEUE',
			N'REQUEST_FOR_DEADLOCK_SEARCH',			N'RESOURCE_QUEUE',
			N'SERVER_IDLE_CHECK',					N'SLEEP_BPOOL_FLUSH',
			N'SLEEP_DBSTARTUP',						N'SLEEP_DCOMSTARTUP',
			N'SLEEP_MASTERDBREADY',					N'SLEEP_MASTERMDREADY',
			N'SLEEP_MASTERUPGRADED',				N'SLEEP_MSDBSTARTUP',
			N'SLEEP_SYSTEMTASK',					N'SLEEP_TASK',
			N'SLEEP_TEMPDBSTARTUP',					N'SNI_HTTP_ACCEPT',
			N'SP_SERVER_DIAGNOSTICS_SLEEP',			N'SQLTRACE_BUFFER_FLUSH',
			N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',	N'WAIT_FOR_RESULTS',
			N'WAITFOR',								N'WAITFOR_TASKSHUTDOWN',
			N'WAIT_XTP_HOST_WAIT',					N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG', 
			N'WAIT_XTP_CKPT_CLOSE',					N'XE_DISPATCHER_JOIN',					
			N'XE_DISPATCHER_WAIT',					N'XE_TIMER_EVENT')
    )
SELECT
    W1.wait_type AS WaitType,
    CAST (W1.WaitS AS DECIMAL(14, 2)) AS Wait_S,
    CAST (W1.ResourceS AS DECIMAL(14, 2)) AS Resource_S,
    CAST (W1.SignalS AS DECIMAL(14, 2)) AS Signal_S,
    W1.WaitCount AS WaitCount,
    CAST (W1.Percentage AS DECIMAL(4, 2)) AS Percentage,
    CAST ((W1.WaitS / W1.WaitCount) AS DECIMAL (14, 4)) AS AvgWait_S,
    CAST ((W1.ResourceS / W1.WaitCount) AS DECIMAL (14, 4)) AS AvgRes_S,
    CAST ((W1.SignalS / W1.WaitCount) AS DECIMAL (14, 4)) AS AvgSig_S
FROM Waits AS W1
    INNER JOIN Waits AS W2 ON W2.RowNum <= W1.RowNum
GROUP BY W1.RowNum, W1.wait_type, W1.WaitS, W1.ResourceS, W1.SignalS, W1.WaitCount, W1.Percentage
HAVING SUM (W2.Percentage) - W1.Percentage < 95; -- percentage threshold
GO


/* 
	Clear wait stats
*/
DBCC SQLPERF ("sys.dm_os_wait_stats" , CLEAR); 


/*
    Check to see when wait stats were last cleared
*/
SELECT 
wait_type,
wait_time_ms, 
DATEADD(ms,-wait_time_ms,getdate()) as "Date/TimeCleared",
CASE 
WHEN wait_time_ms < 1000 THEN cast(wait_time_ms as varchar(15)) + ' ms'
WHEN wait_time_ms between 1000 and 60000 THEN cast((wait_time_ms/1000) as varchar(15)) + ' seconds'
WHEN wait_time_ms between 60001 and 3600000 THEN cast((wait_time_ms/60000) as varchar(15)) + ' minutes'
WHEN wait_time_ms between 3600001 and 86400000 THEN cast((wait_time_ms/3600000) as varchar(15)) + ' hours'
WHEN wait_time_ms > 86400000 THEN cast((wait_time_ms/86400000) as varchar(15)) + ' days'
END as "TimeSinceCleared"
FROM sys.dm_os_wait_stats 
WHERE wait_type = 'SQLTRACE_INCREMENTAL_FLUSH_SLEEP';


/*
    Check SQL Server start time - 2008 and higher
*/
SELECT sqlserver_start_time 
FROM sys.dm_os_sys_info;


/*
	Check SQL Server start time - 2005 and higher	
*/
SELECT create_date 
FROM sys.databases 
WHERE database_id = 2


SELECT servicename, startup_type_desc, status_desc, 
last_startup_time, service_account, is_clustered, cluster_nodename
FROM sys.dm_server_services OPTION (RECOMPILE);


/*
	Clear latch and spinlock stats (2012+)
*/
DBCC SQLPERF ("sys.dm_os_latch_stats" , CLEAR);

DBCC SQLPERF ("sys.dm_os_spinlock_stats" , CLEAR);
