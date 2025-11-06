/*<info serverAlias="DBBAH-bodb02" executers="wsv_lap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[LAP_Rpt_DetailTransaction_Mem] 
    @CustID			INT,  
    @FromDate		DATE,  
    @ToDate			DATE,
	@TransactionId	VARCHAR(50) = NULL,
	@IsResettled	BIT = 0,
	@IsSingleWalletLic BIT = 0,
    @ReportViewType	TINYINT	= 1,
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
		- 20240620@Kelvin: Integrate Saba Coins - add param @ReportViewType [RedmineID: #206840]
		- 20241227@Kelvin: LAP - Saba Coins phase 2 - Support multiple wallets [RedmineID: #215890]
		- 20251106@Kelvin: Add SettlementType = 13 [RedmineID: #243741]
	
	Param's Explanation:     
		- @ReportViewType : TINYINT
  			+ 1 - Main Wallet
  			+ 2 - Saba coins 
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

	CREATE TABLE #ListCustID
	(
		custID		INT
	)

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

	INSERT INTO @Bettype_TransLog (Bettype)
	SELECT DISTINCT BetType
	FROM dbo.SportBettypeMatrix (NOLOCK)
	WHERE RefTable = 3 --translog

	SELECT @_fromDateTime	= @FromDate
	, @_toDateTime			= @ToDate
	, @_toDateTime			= DATEADD(DAY, 1, @_toDateTime)
	, @_custID				= ISNULL(@CustID, 0)
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

	IF @ReportViewType = 2
		BEGIN
			INSERT INTO #ListCustID(CustID)
			SELECT s.CustID
			FROM dbo.Dep_CustSabaInfo s WITH(NOLOCK)
				CROSS APPLY 
				(
					SELECT TOP 1 SabaID
					FROM dbo.Dep_CustSabaInfo r WITH(NOLOCK)
					WHERE r.CustID = @_CustID
				) r
			WHERE s.CustType = 1 AND r.SabaID = s.SabaID

			IF @@ROWCOUNT = 0
				SELECT @_CustID = 0
		END
	ELSE
		BEGIN
			INSERT INTO #ListCustID(CustID)
			SELECT @_CustID
		END

	-- validate time range & custid
	IF (@_fromDateTime > @_toDateTime
		OR @_CustID <= 0)
	BEGIN
		RETURN
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
		, rowIdx = ROW_NUMBER() OVER(ORDER BY RowID ASC)
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
				   WHEN br.SettlementType IN (2, 3, 10, 11, 13) THEN 1
				   ELSE 0
			   END AS IsResettled
		FROM BalanceRecord.dbo.BalanceRecord_bk br WITH (NOLOCK)
			INNER JOIN #ListCustID c ON c.custID = br.custid
			LEFT JOIN @Bettype_TransLog b ON br.bettype = b.Bettype
		WHERE
			(
			br.transid = ISNULL(@_TransactionId, br.transid) OR br.refno = ISNULL(@_TransactionId, br.refno))
			AND 1 = CASE
				WHEN @_IsResettled = 1 AND
					br.SettlementType IN (2, 3, 10, 11, 13) THEN 1 -- get re-settled tickets only
				WHEN @_IsResettled = 0 THEN 1 -- get all tickets
				ELSE 0
			END			
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
				   WHEN SettlementType IN (2, 3, 10, 11, 13) THEN 1
				   ELSE 0
			   END AS IsResettled
		FROM bodb02.dbo.BalanceRecord br WITH (NOLOCK)
			INNER JOIN #ListCustID c ON c.custID = br.custid
			LEFT JOIN @Bettype_TransLog b ON br.bettype = b.Bettype
		WHERE 
			(
			br.transid = ISNULL(@_TransactionId, br.transid) OR br.refno = ISNULL(@_TransactionId, br.refno))
			AND 1 = CASE 
						WHEN @_IsResettled = 1 AND SettlementType IN (2, 3, 10, 11, 13) THEN 1 -- get re-settled tickets only
						WHEN @_IsResettled = 0 THEN 1 -- get all tickets
						ELSE 0
					END
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
		br.rowIdx ASC

	DROP TABLE #transactionRpt
END
GO