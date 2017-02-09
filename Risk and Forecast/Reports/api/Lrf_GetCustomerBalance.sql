USE [bodb02]
GO

CREATE PROCEDURE [dbo].[Lrf_GetCustomerBalance] 
	@LicenseeID		INT,
	@UserID			INT,
	@CurrencyID		INT,
	@ReportDate		SMALLDATETIME
AS

/*  
	Created: 20170120@Joseph 
	Task : Dashboard API - Get Current Customer Balance  
	DB: DBACC/bodb02
	Original: Lrf_Rpt_CustomerBalance  
  
	Revisions:  
		- 20170120@Joseph: Copy from Lrf_Rpt_PlatformWinloss [RedmineID: #70616]

	Param's Explanation:  
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @tmpAg TABLE (
		custID INT,
		Currency INT
	)

	SELECT	CurrencyID,
			LicenseeID
	INTO #Currency
	FROM DBLIC.bodb_licensee.dbo.CurrencyUser WITH (NOLOCK)
	WHERE usrID = @userID
		AND LicenseeID = @LicenseeID
		AND SystemID = 1 -- System is default=1 (LRF)
		AND (@CurrencyID = 0 OR CurrencyID = @CurrencyID)

	DECLARE @Temp TABLE (
		LicenseeId INT,
		CustId INT,
		Currency INT,
		[Description] VARCHAR(200)
	)

	DECLARE @sql VARCHAR(500)

	SELECT @sql = 'SELECT LicenseeId,CustID,Currency,Description 
					FROM OPENQUERY(DBLIC, ''SELECT LicenseeId,CustID,Currency,Description FROM bodb_licensee.dbo.f_SelLicenseeCust(' + CAST(@LicenseeID AS VARCHAR(10)) + ')'')'

	INSERT INTO @Temp (
		LicenseeId,
		CustId,
		Currency,
		[Description]
	)
	EXEC (@sql)

	INSERT INTO @tmpAg (
		CustId,
		Currency
	)
	SELECT	CustID,
			Currency
	FROM @Temp lc
		INNER JOIN #Currency c 
			ON lc.LicenseeID = c.LicenseeID
			AND lc.Currency = c.CurrencyID
	WHERE (@CurrencyID = 0 OR (@CurrencyID <> 0 AND Currency = @CurrencyID))
		AND Currency <> 20
		
	DROP TABLE #Currency

	SELECT SUM(b.ClosingBalance) AS ClosingBalance
	FROM bodb_Report.dbo.rptDepWinlost b WITH (NOLOCK)
	INNER JOIN @tmpAg a
		ON b.recommend = a.CustId AND b.Currency = a.Currency
	WHERE b.winlostdate = @ReportDate
END