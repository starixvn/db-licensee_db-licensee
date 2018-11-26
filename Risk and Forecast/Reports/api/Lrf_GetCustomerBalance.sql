/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet,vnteam" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Lrf_GetCustomerBalance] 
	@LicenseeID		INT,
	@CurrencyIDList	VARCHAR(500)	= '',
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
		- 20170814@Alex  : Restrict permission by currency  [RedmineID: #80855]
		- 20181031@Percy: Remove linked-server DBLIC [RedmineID: #103660]
		- 20181120@Kathy: Tunning SP - got timeout error [RedmineId:#104824]

	Param's Explanation:  
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @tmpAg TABLE (
		custID		INT
		,Currency	INT
		,EUR		FLOAT
		,USD		FLOAT
		,GBP		FLOAT 
		,CNY		FLOAT 
		,MYR		FLOAT 
		,THB		FLOAT 
		,IDR		FLOAT
	)

	DECLARE @Temp TABLE (
		CustId		INT
		,Currency	INT
	)

	INSERT INTO @Temp (CustId,Currency)
	SELECT CustID,Currency FROM bodb_licensee.dbo.f_SelLicenseeCust(@LicenseeID)

	INSERT INTO @tmpAg (
		CustId
		,Currency
	)
	SELECT	CustID
			,Currency
	FROM	@Temp lc
	WHERE	Currency IN
                (
                    SELECT	val
                    FROM	dbo.strSplit(@CurrencyIDList, ',')
                );

	UPDATE	a  
		SET EUR = t_ex.EUR
			,USD = t_ex.USD
			,GBP = t_ex.GBP
			,CNY = t_ex.CNY
			,MYR = t_ex.MYR
			,THB = t_ex.THB
			,IDR = t_ex.IDR
	FROM	@tmpAg a
		INNER JOIN Lrf_f_GetExchangeDaily(@ReportDate, @ReportDate) t_ex
			ON	a.Currency = t_ex.ExchangeId

	SELECT	SUM(b.ClosingBalance) AS ClosingBalance,		
			--BASE EUR
			SUM(b.ClosingBalance * a.EUR)	AS ClosingBalanceEUR,	
			--BASE USD
			SUM(b.ClosingBalance * a.USD)	AS ClosingBalanceUSD,
			--BASE GBP
			SUM(b.ClosingBalance * a.GBP)	AS ClosingBalanceGBP,
			--BASE CNY
			SUM(b.ClosingBalance * a.CNY)	AS ClosingBalanceCNY,
			--BASE MYR
			SUM(b.ClosingBalance * a.MYR)	AS ClosingBalanceMYR,
			--BASE THB
			SUM(b.ClosingBalance * a.THB)	AS ClosingBalanceTHB,
			--BASE IDR
			SUM(b.ClosingBalance * a.IDR)	AS ClosingBalanceIDR
	FROM	@tmpAg a 
		CROSS APPLY (
			SELECT	TOP (1) SUM(b.ClosingBalance) AS ClosingBalance
			FROM	bodb_Report.dbo.rptDepWinlost b WITH (NOLOCK)
			WHERE	b.winlostdate = @ReportDate
					AND b.recommend = a.CustId 
					AND b.Currency = a.Currency
		) b

	SET NOCOUNT OFF
END

GO