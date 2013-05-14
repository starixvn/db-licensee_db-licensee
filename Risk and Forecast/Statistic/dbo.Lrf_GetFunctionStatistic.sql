ALTER PROCEDURE [dbo].[Lrf_GetFunctionStatistic] 
	@ParentId INT
AS
/*  
Created: 20120403@Shadow  
Task : Get Function Statistic 
DB: DB052.bodb_Licensee 
Original:
Revisions:  
 	 
   
   
Param's Explanation:   

*/  
BEGIN
	SET NOCOUNT ON;
	
	declare @columns varchar(500)
	create table #Function
	(
		Name varchar(50),
		FunctionCount int,
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

	--Get function count by licensee in last 30 days
	SET @query =
	'insert into #Function
	select Name, SUM(VisitCount)as FunctionCount, c.LicenseeName
	from Functions a WITH (NOLOCK), UserStatistic b WITH (NOLOCK), Licensees c WITH (NOLOCK), LicenseeUser lu WITH (NOLOCK)
	where
			a.FunctionId = b.FunctionId
		and b.UserId = lu.UserId
		and lu.LicenseeId = c.LicenseeId
		and DATEDIFF("d", StatisticDate, GetDate()) <= 30
		and c.IsDeposit = 1
		and ParentId = ' + convert(varchar(10), @ParentID) + '
	group by Name, c.LicenseeName'
	
	execute(@query)
	
	--Get non function by licensee in last 30 days and insert them into #Function table
	insert into #Function
	select '_Non Function' as Name,SUM(VisitCount)as FunctionCount, LicenseeName
	from UserStatistic a WITH (NOLOCK), Licensees b WITH (NOLOCK), LicenseeUser lu WITH (NOLOCK)
	where
			a.FunctionId is null
		and a.UserId = lu.UserId
		and lu.LicenseeId = b.LicenseeId
		and b.IsDeposit = 1
		and DATEDIFF("d", StatisticDate, GetDate()) <= 30
	group by LicenseeName


	set @query = 'select *
	from 
	(
		select Name, LicenseeName, FunctionCount
		from #Function
	) as Statistic
	PIVOT
	(
		SUM(FunctionCount) FOR LicenseeName IN('+ @columns+')		
	) as PivotTable order by Name
	drop table #Function'
	execute(@query)


END

GO
GRANT EXECUTE ON [dbo].[Lrf_GetFunctionStatistic] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_GetFunctionStatistic] TO [VNTeam]
GO