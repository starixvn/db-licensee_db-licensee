ALTER procedure [dbo].[Lrf_GetLicenseeStatistic]
as
/*  
Created:  20120403@Shadow  
Task : Update Licensee Statistic 
DB: DB052.bodb_Licensee 
Original:
Revisions:  
 	 
   
   
Param's Explanation:   

*/  
begin
	declare @columns varchar(500)
	
	create table #Licensee
	(
		DateTime DateTime,
		VisitCount int,
		LicenseeName varchar(50)
	)	
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

	DECLARE @query VARCHAR(8000)
	SET @query =
	'insert into #Licensee
	select CONVERT(DateTime, CONVERT(char(10), StatisticDate, 110)) as DateTime, SUM(VisitCount)as VisitCount, LicenseeName
	from UserStatistic a WITH (NOLOCK), LicenseeUser b WITH (NOLOCK), Licensees c WITH (NOLOCK)
	where 
			a.UserId = b.UserId 
		and b.LicenseeId = c.LicenseeId
		and DATEDIFF("d", StatisticDate, GetDate()) <= 30
		and c.IsDeposit = 1
	group by CONVERT(char(10), StatisticDate, 110), LicenseeName
	order by CONVERT(char(10), StatisticDate, 110) ASC
     
	select *
	from 
	(
		select DateTime, LicenseeName, VisitCount
		from #Licensee
	) as Statistic
	PIVOT
	(
		SUM(VisitCount) FOR LicenseeName IN('+ @columns+')		
	) as PivotTable order by DateTime
	drop table #Licensee'
	execute(@query)

end 

GO
GRANT EXECUTE ON [dbo].[Lrf_GetLicenseeStatistic] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_GetLicenseeStatistic] TO [VNTeam]
GO
