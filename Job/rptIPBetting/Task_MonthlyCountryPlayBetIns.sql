ALTER PROCEDURE [dbo].[Task_MonthlyCountryPlayBetIns] 
	@inputdate SMALLDATETIME
AS
/*	Created by: Henry 
	Date: 2012-08-13
	Task: Task sum data for table rptMonthlyCountryPlayBet
	DB: DBRPT/bodb02

	Revision: 
    - 20130124@Daniel: Change link server alias

		

*/
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @FromDate DATETIME  
	DECLARE @ToDate DATETIME  
	
	SET @FromDate = CAST (year(@InputDate) AS VARCHAR(10)) + '-' + CAST (month(@InputDate) AS VARCHAR(10)) + '-01'  
	SET @ToDate = CAST(CONVERT(VARCHAR(10),  DATEADD(s,-1,DATEADD(mm, DATEDIFF(m,0,@FromDate)+1,0)), 111) AS DATETIME)   
	
	DELETE bodb_report.dbo.rptMonthlyCountryPlayBet WITH (ROWLOCK,UPDLOCK)
	WHERE YearMonthWinlostdate = CONVERT(varchar(6),@inputdate,112)
	
	INSERT INTO bodb_report.dbo.rptMonthlyCountryPlayBet(YearMonthWinlostdate,Country,YearMonthTransdate,CustID)
	select distinct 
		CONVERT(varchar(6),b.winlostdate,112) as YearMonthWinlostdate,
		i.countrySHORT as country,
		CONVERT(varchar(6),b.transdate,112) as YearMonthTransdate,
		b.custid
	from bodb_archive.dbo.bettrans_bk b with(nolock,INDEX=CIX_winlostdate)
	inner join DBLIC.bodb_licensee.dbo.ipcountry i (NOLOCK) on b.ip = i.ip
	where b.winlostdate between @FromDate and @ToDate
	
	
END
GO
GRANT EXECUTE ON [dbo].[Task_MonthlyCountryPlayBetIns] TO [vnteam] AS [dbo]