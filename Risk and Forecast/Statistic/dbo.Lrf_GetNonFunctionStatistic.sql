ALTER PROCEDURE [dbo].[Lrf_GetNonFunctionStatistic]

AS
/*  
Created:   20120403@Shadow 
Task : Get Non Function Statistic 
DB: DB052.bodb_Licensee 
Original:
Revisions:  
 	 
   
   
Param's Explanation:   

*/  
BEGIN

	SET NOCOUNT ON;

	create table #NonFunction
(
	ShortUrl varchar(100),
	VisitCount int,
	LicenseeName varchar(50)
)
declare @columns varchar(500)
declare @query VARCHAR(8000)
SELECT 
	
	/*Create colums*/
	@columns = 
	COALESCE
	(
		@columns + ',[' + LicenseeName + ']',
		'[' + LicenseeName + ']'
	)
	from 
		Licensees WITH (NOLOCK)
	where
		IsDeposit = 1


	insert into #NonFunction
	select 
		case 
			when PATINDEX('%?%',Url) > 0
			then
		
				REVERSE(SUBSTRING(REVERSE(SUBSTRING(Url, 0, CHARINDEX('?', Url))), 0, CHARINDEX('/', REVERSE(SUBSTRING(Url, 0, CHARINDEX('?', Url))))))
			else
				REVERSE( SUBSTRING(REVERSE(Url), 0, CHARINDEX('/', REVERSE(Url))))
		end as ShortUrl, SUM(VisitCount)as VisitCount, LicenseeName
	from UserStatistic a WITH (NOLOCK), LicenseeUser b WITH (NOLOCK), Licensees c WITH (NOLOCK)
	where
				a.FunctionId is null
			and a.UserId = b.UserId
			and b.LicenseeId = c.LicenseeId
			and DATEDIFF("d", StatisticDate, GetDate()) <= 30
			and c.IsDeposit = 1
	group by Url, LicenseeName

	set @query = 'select *
	from 
	(
		select ShortUrl, VisitCount, LicenseeName
		from #NonFunction
	) as NonFunctionStatistic
	PIVOT
	(
		SUM(VisitCount) FOR LicenseeName IN('+ @columns+')		
	) as PivotTable order by ShortUrl'
	execute(@query)
	drop table #NonFunction
END
 
GO
GRANT EXECUTE ON [dbo].[Lrf_GetNonFunctionStatistic] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_GetNonFunctionStatistic] TO [VNTeam]
GO 