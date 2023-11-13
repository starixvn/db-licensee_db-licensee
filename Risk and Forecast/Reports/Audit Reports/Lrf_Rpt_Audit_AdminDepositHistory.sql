/*<info serverAlias="DBPLO-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_Rpt_Audit_AdminDepositHistory]  	
	@CustId			INT,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@BUDate			SMALLDATETIME
	
AS 
/*  
	Created: 20231025@Bobby
    Description: LAP - Implement new report for auditing
    DB: DBPLO.bodb02
   
    Revisions:  
		- 20231025@Bobby: Customer Admin - [redmine: #195850]
		
    Param's Explanation:  
	  
*/
BEGIN  
    
	SET NOCOUNT ON;
	
	DECLARE @SiteName	VARCHAR(15) = '12Bet'
		,@tmpFromDate	SMALLDATETIME
		,@tmpToDate		SMALLDATETIME
	;

	DROP TABLE IF EXISTS #TransResult;

	CREATE TABLE #TransResult
	(
		TransId	BIGINT PRIMARY KEY
		,TransDate	DATETIME
		,Amount		MONEY
		,Remark		NVARCHAR(1000)
	)

	IF NOT EXISTS (SELECT 1 
		FROM [bodb_Ploutos].[dbo].[PlayerProfile] p WITH(NOLOCK) 
		WHERE p.CustId = @CustId
			AND p.BrandCode = @SiteName
	)
	BEGIN
		GOTO OUTPUT_DETAIL;
	END

	--TODO: Get transaction history
	BEGIN
		SELECT @tmpFromDate = IIF(@FromDate <= @BUDate, @BUDate, @FromDate)
			,@tmpToDate = @ToDate;

		INSERT INTO #TransResult (TransId, TransDate, Amount)
		SELECT TransId, DATEADD(HH, 8, TransDate) AS TransDate, ABS(Winlost-Actual_Stake) AS Amount
		FROM dbo.transfer t WITH(NOLOCK)
		WHERE t.CustId = @CustId
			AND t.bettype = 22001
			AND t.Winlostdate >= @BUDate
			AND t.Winlostdate BETWEEN @tmpFromDate AND @tmpToDate


		---------------------bk range
		DECLARE @rmtQuery NVARCHAR(MAX);

		SELECT @tmpFromDate = DATEADD(DAY, -1, @FromDate)
			, @tmpToDate = IIF(@ToDate >= @BUDate, @BUDate, @ToDate)

		SELECT @rmtQuery = N'INSERT INTO #TransResult (TransId, TransDate, Amount)
			SELECT TransId, TransDate, Amount
			FROM OPENQUERY(DBARC, ''SELECT TransId, DATEADD(HH, 8, TransDate) AS TransDate, ABS(Credit-Debit) AS Amount
			FROM bodb_Archive.dbo.transfer_bk t WITH(NOLOCK)
			WHERE t.CustId = '+ CAST(@CustId AS VARCHAR(15))+'
				AND t.bettype = 22001
				AND t.Winlostdate < ''''' +FORMAT(@BUDate, 'yyyy-MM-dd') + '''''
				AND t.Winlostdate BETWEEN '''''+FORMAT(@tmpFromDate, 'yyyy-MM-dd')+''''' AND '''''+FORMAT(@tmpToDate, 'yyyy-MM-dd')+''''''') AS rmt'

		EXEC (@rmtQuery)
		
	END
		
	--- RETURN BET in Detail
	SELECT @tmpToDate = DATEADD(DAY, 1, @ToDate) --> whole day
	OUTPUT_DETAIL:
	SELECT 
		TransId	
		,TransDate	
		,Amount
		,ISNULL(Remark, '') AS Remark
	FROM #TransResult p
	WHERE TransDate >= @FromDate AND TransDate < @tmpToDate
	ORDER BY TransDate DESC

END
GO