/*<info serverAlias="DBBAH-bodb02" executers="bodbLicenseeNet,bodbDownlineNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[LAP_Rpt_DetailTransaction_Mem] 
    @CustID			INT,  
    @FromDate		DATE,  
    @ToDate			DATE,
	@TransactionId	BIGINT = NULL,
	@IsResettled	BIT = 0,
	@IsSingleWalletLic BIT = 0,
    @PageSize		INT = NULL,  
    @PageIndex		INT = 1,  
    @TotalRow		INT = 0 OUTPUT 
AS
/*
	Created:Bobby@20200313  
	Task : 130293 - LAP - Detail Transaction Member
	DB: DBBAH/bodb02
	Revisions:  
		- 20200313@Bobby: Initialize [RedmineID: #130293] 
		- 20200330@Louis: Support Statement & Detail Transaction Report in Chinese [RedmineID: #131262]
		- 20200420@Louis: Detail Transaction - Change rounding & sorting mechanism [RedmineID: #1328230]
		- 20200907@Sol: Show lost record for some cases [RedmineID: #140884]
		- 20201008@Sol: Show new column to determine re-settle tickets - [RedmineID: #142346]
		- 20220111@Sophia: Hide transfer ticket of Single Wallet Licensee [RedmineID: #167343]
	
	Param's Explanation:     
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE 
		@currentDate		SMALLDATETIME
		, @currency			INT  
		, @_fromDateTime	SMALLDATETIME
		, @_toDateTime		SMALLDATETIME
		, @_custID			INT
		, @_TransactionId	BIGINT
		, @_IsResettled		BIT

	CREATE TABLE #transactionRpt
    (  
		transid				BIGINT
		, bettype			INT
		, transtime			DATETIME
        , transremark		VARCHAR(200)
        , changedAmt		MONEY DEFAULT(0)
        , totalAmt			MONEY DEFAULT(0)
		--, CONSTRAINT PK_Trans PRIMARY KEY (transtime, transid)
		, rowIdx			INT PRIMARY KEY
		, IsResettled		BIT
    )

	SELECT @_fromDateTime	= @FromDate
	, @_toDateTime			= @ToDate
	, @_toDateTime			= DATEADD(DAY, 1, @_toDateTime)
	, @_custID				= @custID
	, @_TransactionId		= @TransactionId
	, @_IsResettled			= @IsResettled

	INSERT INTO #transactionRpt (
		transid
		, bettype
		, transtime
		, transremark
		, changedAmt
		, totalAmt
		, rowIdx
		, IsResettled
	)
	SELECT br.transid
		, br.bettype
		, br.transtime
		, br.transremark
		, br.changedAmt
		, br.totalAmt
		, rowIdx = ROW_NUMBER() OVER(ORDER BY RowID)
		, br.IsResettled
	FROM (
		SELECT transid
			, bettype
			, actiondate AS transtime
			, REPLACE([action],'TransLog','Ticket') AS transremark
			, BalanceChanged AS changedAmt
			, NewBalance AS totalAmt
			, RowID
			, CASE WHEN br.SettlementType IN (2,3) THEN 1 ELSE 0 END AS IsResettled
		FROM BalanceRecord.dbo.BalanceRecord_bk br WITH(NOLOCK)
		WHERE
			br.transid = ISNULL(@_TransactionId, br.transid)
			AND 1 = CASE 
						WHEN @_IsResettled = 1 AND br.SettlementType IN (2,3) THEN 1 -- get re-settled tickets only
						WHEN @_IsResettled = 0 THEN 1 -- get all tickets
						ELSE 0
					END
			AND custid = @_custid
			AND actiondate BETWEEN @_fromDateTime AND @_toDateTime
			AND 
			(
				BalanceChanged <> 0
				OR 
				(BalanceChanged = 0 AND ActionID NOT IN (1, 20, 21, 100, 255)) --excluded others (won/lose->won/lose...), Reject Bet, Accept Bet, Bet SUM insert, Balance insert
			)
	
		UNION ALL
		SELECT transid
			, bettype
			, actiondate AS transtime
			, REPLACE([action],'TransLog','Ticket') AS transremark
			, BalanceChanged AS changedAmt
			, NewBalance AS totalAmt
			, RowID
			, CASE WHEN SettlementType IN (2,3) THEN 1 ELSE 0 END AS IsResettled
		FROM bodb02.dbo.BalanceRecord WITH(NOLOCK)
		WHERE 
			transid = ISNULL(@_TransactionId, transid)
			AND 1 = CASE 
						WHEN @_IsResettled = 1 AND SettlementType IN (2,3) THEN 1 -- get re-settled tickets only
						WHEN @_IsResettled = 0 THEN 1 -- get all tickets
						ELSE 0
					END
			AND custid = @_custid
			AND actiondate BETWEEN @_fromDateTime AND @_toDateTime
			AND 
			(
				BalanceChanged <> 0
				OR 
				(BalanceChanged = 0 AND ActionID NOT IN (1, 20, 21, 100, 255)) --excluded others (won/lose->won/lose...), Reject Bet, Accept Bet, Bet SUM insert, Balance insert
			)
	) AS br
	
	IF @IsSingleWalletLic = 1 
	BEGIN 
		DELETE #transactionRpt WHERE Bettype IN (22001, 22002) 		
	END 

	-- SET @TotalRow
	SELECT @TotalRow		= @@ROWCOUNT
	
	DECLARE @_rowStart		INT
		, @_rowEnd			INT
		, @_maxIntValue		INT

	SELECT @_maxIntValue	= POWER(2.,31)-2
		, @PageSize		= CASE WHEN @PageSize > 0 THEN @PageSize ELSE @_maxIntValue END

    SELECT  @PageIndex		= CASE WHEN @PageIndex > 0 THEN @PageIndex - 1 ELSE 0 END,
            @_rowStart		= @PageSize * @PageIndex + 1,
            @_rowEnd		= @_rowStart + @PageSize - 1
	
	SELECT 
		br.transid
		, br.bettype
		, br.transtime
		, br.transremark
		, br.changedAmt
		, br.totalAmt
		, br.IsResettled
	FROM #transactionRpt br
	WHERE 
		br.rowIdx BETWEEN @_rowStart AND @_rowEnd
	ORDER BY 
		br.rowIdx

	DROP TABLE #transactionRpt
END
GO