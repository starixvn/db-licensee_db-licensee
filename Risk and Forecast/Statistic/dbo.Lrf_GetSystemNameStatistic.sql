ALTER PROCEDURE [dbo].[Lrf_GetSystemNameStatistic]
/*  
Created:   20120403@Shadow 
Task : Get System Info from UserStatistic
DB: DB052.bodb_Licensee 
Original:
Revisions:  
 	 
   
   
Param's Explanation:   

*/  
AS
BEGIN

	SET NOCOUNT ON;

	create table #SystemName
	(
		DateTime DateTime,
		SystemCount bigint,
		UserAgent varchar(1024)	
	)	

	declare @columns varchar(8000)	
	set @columns = ''


	DECLARE @query VARCHAR(8000)
	SET @query =
	'insert into #SystemName
	select CONVERT(DateTime, CONVERT(char(10), StatisticDate, 110)) as DateTime, SUM(VisitCount)as SystemCount, 
		case 
		WHEN PATINDEX(''%Win16%'',UserAgent) > 0
             THEN ''Windows 3.11''
		WHEN PATINDEX(''%Windows 95)%'',UserAgent) > 0 
				OR PATINDEX(''Windows_95'', UserAgent) > 0
				OR PATINDEX(''Win95'', UserAgent) > 0
             THEN ''Windows 95''
        WHEN PATINDEX(''%Windows 98%'',UserAgent) > 0
				OR PATINDEX(''Win98'', UserAgent) > 0
             THEN ''Windows 98''		  
		WHEN PATINDEX(''%Windows NT 5.0%'',UserAgent) > 0
				OR PATINDEX(''Windows 2000'', UserAgent) > 0
             THEN ''Windows 2000''
        WHEN PATINDEX(''%Windows NT 5.1%'',UserAgent) > 0 
				OR PATINDEX(''Windows XP'', UserAgent) > 0
             THEN ''Windows XP''
		WHEN PATINDEX(''%Windows NT 5.2%'',UserAgent) > 0
             THEN ''Windows Server 2003''
		WHEN PATINDEX(''%Windows NT 6.0%'',UserAgent) > 0
             THEN ''Windows Vista''
		WHEN PATINDEX(''%Windows NT 6.1%'',UserAgent) > 0
             THEN ''Windows 7''
		WHEN PATINDEX(''%Windows NT 6.2%'',UserAgent) > 0
             THEN ''Windows 8''
		WHEN PATINDEX(''%Windows NT 4.0%'',UserAgent) > 0
				OR PATINDEX(''WinNT4.0'', UserAgent) > 0
				OR PATINDEX(''WinNT'', UserAgent) > 0
				OR PATINDEX(''Windows NT'', UserAgent) > 0
             THEN ''Windows NT 4.0''
		WHEN PATINDEX(''%Windows ME%'',UserAgent) > 0
             THEN ''Windows ME''
		WHEN PATINDEX(''%OpenBSD%'',UserAgent) > 0
             THEN ''OpenBSD''
		WHEN PATINDEX(''%SunOS%'',UserAgent) > 0
             THEN ''SunOS''
		WHEN PATINDEX(''%Linux%'',UserAgent) > 0
				OR PATINDEX(''X11'', UserAgent) > 0
             THEN ''Linux''
		WHEN PATINDEX(''%Macintosh%'',UserAgent) > 0
				OR PATINDEX(''Mac_PowerPC'', UserAgent) > 0
             THEN ''Mac OS''
		WHEN PATINDEX(''%QNX%'',UserAgent) > 0
             THEN ''QNX''
		WHEN PATINDEX(''%BeOS%'',UserAgent) > 0
             THEN ''BeOS''
		WHEN PATINDEX(''%OS/2%'',UserAgent) > 0
             THEN ''OS/2''
		WHEN PATINDEX(''%iPhone%'', UserAgent) > 0 OR PATINDEX(''%iPad%'', UserAgent) > 0
			 THEN ''iOS''
		WHEN PATINDEX(''%BlackBerry%'', UserAgent) > 0
			 THEN ''BlackBerry OS''
		ELSE
			  ''Unknown System''
    END as UserAgent

	from UserStatistic a WITH (NOLOCK), Licensees b WITH (NOLOCK), LicenseeUser WITH (NOLOCK)
	where
		    a.UserId = LicenseeUser.UserId
		and LicenseeUser.LicenseeId = b.LicenseeId
		and DATEDIFF("d", StatisticDate, GetDate()) <= 30
	group by CONVERT(DateTime, CONVERT(char(10), StatisticDate, 110)), UserAgent'

	execute(@query)

	DECLARE csr_System CURSOR FOR  
	SELECT DISTINCT UserAgent
	FROM #SystemName

	OPEN csr_System
	   
	DECLARE @temp varchar(500)
	DECLARE @SystemName varchar(30)
	FETCH NEXT FROM csr_System INTO @temp   

	WHILE @@FETCH_STATUS = 0   
	BEGIN   
		   SET @columns = @columns + '[' + @temp + '],'
		   FETCH NEXT FROM csr_System INTO @temp   
	END
	SET @columns = SUBSTRING(@columns, 0, LEN(@columns))

	CLOSE csr_System   
	DEALLOCATE csr_System

	set @query = 
	
	'select *
	from 
	(
		select DateTime, UserAgent, SystemCount
		from #SystemName
	) as Statistic
	PIVOT
	(
		SUM(SystemCount) FOR UserAgent IN('+ @columns+')		
	) as PivotTable order by DateTime
	drop table #SystemName'
	execute(@query)
	

END

GO
GRANT EXECUTE ON [dbo].[Lrf_GetSystemNameStatistic] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_GetSystemNameStatistic] TO [VNTeam]
GO  