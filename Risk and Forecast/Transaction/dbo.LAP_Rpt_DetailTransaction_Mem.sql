/*<info serverAlias="DBBAH-bodb02" executers="wsv_lap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[LAP_Rpt_DetailTransaction_Mem] 
    @CustID			INT,  
    @FromDate		DATE,  
    @ToDate			DATE,
	@TransactionId	VARCHAR(50) = NULL,
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
		- 20230614@Evan: Update condition show full cycle of status on ticket  [RedmineID: #189579]
		- 20230810@Evan: Add SettlementType filter Recover Bets [RedmineID: #191844]
		- 20230810@Evan: Show bettrans.refno for settled record of Translog products [RedmineID: #196379]
	
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

	-- Get bettype translog--
	DECLARE @Bettype_TransLog TABLE (Bettype SMALLINT)

	INSERT INTO @Bettype_TransLog
	SELECT DISTINCT BetType
	FROM dbo.SportBettypeMatrix (NOLOCK)
	WHERE RefTable = 3 --translog

	SELECT @_fromDateTime	= @FromDate
	, @_toDateTime			= @ToDate
	, @_toDateTime			= DATEADD(DAY, 1, @_toDateTime)
	, @_custID				= @custID
	, @_IsResettled			= @IsResettled

	IF @TransactionId IS NOT NULL
	BEGIN
		BEGIN TRY
			SELECT @_TransactionId	= IIF( ISNUMERIC (@TransactionId) = 1, CONVERT (BIGINT, @TransactionId), 0)
		END TRY
		BEGIN CATCH
			SELECT @_TransactionId = 0
		END CATCH
	END
	
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
		SELECT CASE
				   WHEN b.Bettype IS NOT NULL AND br.refno IS NOT NULL THEN br.refno
				   ELSE br.transid
			   END AS transid
			 , br.bettype
			 , ActionDate AS transtime
			 , REPLACE([Action], 'TransLog', 'Ticket') AS transremark
			 , BalanceChanged AS changedAmt
			 , NewBalance AS totalAmt
			 , RowID
			 , CASE
				   WHEN br.SettlementType IN (2, 3, 10, 11) THEN 1
				   ELSE 0
			   END AS IsResettled
		FROM BalanceRecord.dbo.BalanceRecord_bk br WITH (NOLOCK)
			LEFT JOIN @Bettype_TransLog b ON br.bettype = b.Bettype
		WHERE  
			(br.transid = ISNULL(@_TransactionId, br.transid) OR br.refno = ISNULL(@_TransactionId, br.refno))
			AND 1 = CASE
				WHEN @_IsResettled = 1 AND
					br.SettlementType IN (2, 3, 10, 11) THEN 1 -- get re-settled tickets only
				WHEN @_IsResettled = 0 THEN 1 -- get all tickets
				ELSE 0
			END
			AND custid = @_custID
			AND ActionDate BETWEEN @_fromDateTime AND @_toDateTime
			AND (
			BalanceChanged <> 0 OR (BalanceChanged = 0 AND ActionID NOT IN (1, 33, 35, 100, 255)) --excluded others (won/lose->won/lose...), LC|RNG Sum, Translog inserted, Bet SUM insert, Balance insert
			)
	
		UNION ALL
		SELECT CASE
				   WHEN b.Bettype IS NOT NULL AND br.refno IS NOT NULL THEN br.refno
				   ELSE br.transid
			   END AS transid
			 , br.bettype
			 , ActionDate AS transtime
			 , REPLACE([Action], 'TransLog', 'Ticket') AS transremark
			 , BalanceChanged AS changedAmt
			 , NewBalance AS totalAmt
			 , RowID
			 , CASE
				   WHEN SettlementType IN (2, 3, 10, 11) THEN 1
				   ELSE 0
			   END AS IsResettled
		FROM bodb02.dbo.BalanceRecord br WITH (NOLOCK)
			LEFT JOIN @Bettype_TransLog b ON br.bettype = b.Bettype 
		WHERE 
			(br.transid = ISNULL(@_TransactionId, br.transid) OR br.refno = ISNULL(@_TransactionId, br.refno))
			AND 1 = CASE 
						WHEN @_IsResettled = 1 AND SettlementType IN (2,3,10,11) THEN 1 -- get re-settled tickets only
						WHEN @_IsResettled = 0 THEN 1 -- get all tickets
						ELSE 0
					END
			AND custid = @_custid
			AND actiondate BETWEEN @_fromDateTime AND @_toDateTime
			AND 
			(
				BalanceChanged <> 0
				OR 
				(BalanceChanged = 0 AND ActionID NOT IN (1, 33, 35, 100, 255)) --excluded others (won/lose->won/lose...), LC|RNG Sum, Translog inserted, Bet SUM insert, Balance insert
			)
	) AS br
	
	IF @IsSingleWalletLic = 1 
	BEGIN 
		DELETE #transactionRpt WHERE Bettype IN (22001, 22002) 		
	END 

	-- SET @TotalRow
	SELECT @TotalRow = COUNT(1) FROM #transactionRpt
	
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