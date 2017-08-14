 /*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Lrf_GetCustomerBalance] 
	@LicenseeID		INT,
	@CurrencyIDList		VARCHAR(500)='',
	@ReportDate		SMALLDATETIME
AS

/*  
	Created: 20170120@Joseph 
	Task : Dashboard API - Get Current Customer Balance  
	DB: DBACC/bodb02
	Original: Lrf_Rpt_CustomerBalance  
  
	Revisions:  
		- 20170120@Joseph: Copy from Lrf_Rpt_PlatformWinloss [RedmineID: #70616]
		- 20170613@Paul: return value in THB, IDR rates [RedmineID: #75030]
		- 20170808@Walter: Support UUS currency [RedmineID: #80855]

	Param's Explanation:  
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @tmpAg TABLE (
		custID INT,
		Currency INT
	)

	DECLARE @Temp TABLE (
		CustId INT,
		Currency INT
	)

	DECLARE @sql VARCHAR(500)

	SELECT @sql = 'SELECT CustID,Currency
					FROM OPENQUERY(DBLIC, ''SELECT LicenseeId,CustID,Currency,Description FROM bodb_licensee.dbo.f_SelLicenseeCust(' + CAST(@LicenseeID AS VARCHAR(10)) + ')'')'

	INSERT INTO @Temp (
		CustId,
		Currency
	)
	EXEC (@sql)

	INSERT INTO @tmpAg (
		CustId,
		Currency
	)
	SELECT	CustID,
			Currency
	FROM @Temp lc
	WHERE Currency IN
                (
                    SELECT val
                    FROM dbo.strSplit(@CurrencyIDList, ',')
                );

	CREATE TABLE #Exchange (ExchangeDate SMALLDATETIME, ExchangeId INT,  EUR FLOAT,USD FLOAT,GBP FLOAT, CNY FLOAT, MYR FLOAT, THB FLOAT, IDR FLOAT, Code VARCHAR(10), PRIMARY KEY(ExchangeDate,ExchangeId));

	INSERT INTO #Exchange (exchangedate, exchangeid, eur, usd, gbp, cny, myr, thb, idr, code)
	SELECT exchangedate, exchangeid, eur, usd, gbp, cny, myr, thb, idr, code
	FROM Lrf_f_GetExchangeDaily(@ReportDate, @ReportDate) t_ex
	WHERE EXISTS (SELECT 1 FROM @tmpAg t_ag WHERE t_ag.Currency = t_ex.ExchangeId);

	SELECT	SUM(b.ClosingBalance) AS ClosingBalance,		
			--BASE EUR
			SUM(b.ClosingBalance * e.EUR)	AS ClosingBalanceEUR,	
			--BASE USD
			SUM(b.ClosingBalance * e.USD)	AS ClosingBalanceUSD,
			--BASE GBP
			SUM(b.ClosingBalance * e.GBP)	AS ClosingBalanceGBP,
			--BASE CNY
			SUM(b.ClosingBalance * e.CNY)	AS ClosingBalanceCNY,
			--BASE MYR
			SUM(b.ClosingBalance * e.MYR)	AS ClosingBalanceMYR,
			--BASE THB
			SUM(b.ClosingBalance * e.THB)	AS ClosingBalanceTHB,
			--BASE IDR
			SUM(b.ClosingBalance * e.IDR)	AS ClosingBalanceIDR
	FROM bodb_Report.dbo.rptDepWinlost b WITH (NOLOCK)
		INNER JOIN @tmpAg a ON b.recommend = a.CustId AND b.Currency = a.Currency
		INNER JOIN #Exchange e ON e.exchangeid = a.currency
	WHERE b.winlostdate = @ReportDate

	SET NOCOUNT OFF
END
GO