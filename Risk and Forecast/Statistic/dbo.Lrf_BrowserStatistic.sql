ALTER PROCEDURE [dbo].[Lrf_BrowserStatistic] 
	@Month INT,
	@Year INT
AS
/*  
Created:   20120403@Shadow 
Task : Get Browser Statistic 
DB: DB052.bodb_Licensee 
Original:
Revisions:  
 	 
   
Param's Explanation:   

*/  
BEGIN
	create table #Browsers
	(
		DateTime DateTime,
		BrowserCount bigint,
		UserAgent varchar(1024)	
	)
declare @columns varchar(8000)	
	set @columns = ''

insert into #Browsers
select CONVERT(DateTime, CONVERT(char(10), StatisticDate, 110)) as DateTime, SUM(VisitCount)as BrowserCount, 
		case 
		WHEN PATINDEX('%MSIE 8.0%',UserAgent) > 0
             THEN 'Internet Explorer 8.0'
		WHEN PATINDEX('%MSIE 7.0%',UserAgent) > 0
             THEN 'Internet Explorer 7.0'
        WHEN PATINDEX('%MSIE 6.0%',UserAgent) > 0
             THEN 'Internet Explorer 6.0'	  
		WHEN PATINDEX('%MSIE 5.0%',UserAgent) > 0
             THEN 'Internet Explorer 5.0'
        WHEN PATINDEX('%Firefox%',UserAgent) > 0
             THEN 'Mozilla Firefox ' + SUBSTRING(SUBSTRING(UserAgent,PATINDEX('%Firefox%',UserAgent), 20), PATINDEX('%/%', SUBSTRING(UserAgent,PATINDEX('%Firefox%',UserAgent), 20)) + 1, PATINDEX('%.%', SUBSTRING(UserAgent,PATINDEX('%Firefox%',UserAgent), 20)) - PATINDEX('%/%', SUBSTRING(UserAgent,PATINDEX('%Firefox%',UserAgent), 20)) + 1)
		WHEN PATINDEX('%Chrome%',UserAgent) > 0
             THEN 'Google ' + REPLACE(SUBSTRING(UserAgent,
                           PATINDEX('%Chrome%',UserAgent), 11),CHAR(47), CHAR(32)) 
		WHEN PATINDEX('%Safari%',UserAgent) > 0
             THEN  'Safari' + SUBSTRING(REPLACE(SUBSTRING(UserAgent, PATINDEX('%Version%', UserAgent), PATINDEX('%Safari%', UserAgent) - PATINDEX('%Version%',UserAgent)), 'Version/', ' '), 1, 4)
		WHEN PATINDEX('%Opera%',UserAgent) > 0
             THEN REPLACE(SUBSTRING(UserAgent,
                           PATINDEX('%Opera%',UserAgent),
                                  PATINDEX('%(%',UserAgent)-2),CHAR(47), CHAR(32))
		ELSE
			  'Unknown Browser'
    END as UserAgent

	from UserStatistic a WITH (NOLOCK), Licensees b WITH (NOLOCK), LicenseeUser WITH (NOLOCK)
	where
		    a.UserId = LicenseeUser.UserId
		and LicenseeUser.LicenseeId = b.LicenseeId
		and MONTH(StatisticDate) = CONVERT(char(10), @Month)
		and YEAR(StatisticDate) = CONVERT(char(10), @Year)
	group by CONVERT(DateTime, CONVERT(char(10), StatisticDate, 110)), UserAgent

	DECLARE csr_Browser CURSOR FOR  
	SELECT DISTINCT UserAgent
	FROM #Browsers

	OPEN csr_Browser
	   
	DECLARE @temp varchar(8000)
	FETCH NEXT FROM csr_Browser INTO @temp   

	WHILE @@FETCH_STATUS = 0   
	BEGIN   
		   SET @columns = @columns + '[' + @temp + '],'
		   FETCH NEXT FROM csr_Browser INTO @temp   
	END
	SET @columns = SUBSTRING(@columns, 0, LEN(@columns))

	CLOSE csr_Browser   
	DEALLOCATE csr_Browser


	DECLARE @query varchar(8000)
	set @query = 
	
	'select *
	from 
	(
		select DateTime, UserAgent, BrowserCount
		from #Browsers
	) as Statistic
	PIVOT
	(
		SUM(BrowserCount) FOR UserAgent IN('+ @columns+')		
	) as PivotTable order by DateTime'
	IF LEN(@columns) > 0
		begin
		 execute(@query)
		end
	ELSE
		select * from #Browsers
	drop table #Browsers

		
END

 
GO
GRANT EXECUTE ON [dbo].[Lrf_BrowserStatistic] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BrowserStatistic] TO [VNTeam]
GO  