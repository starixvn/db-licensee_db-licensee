/*<info serverAlias="DBACC-bodb02" executers="wsv_lap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[LAP_Statement_Mem]
    @CustID			INT,  
    @FromDate		SMALLDATETIME,  
    @ToDate			SMALLDATETIME,  
    @ReportViewType	TINYINT	= 1,
    @BalanceUpDay	SMALLDATETIME,  
    @MoveBetsDay	SMALLDATETIME,  
    @PageSize		INT = 50,  
    @PageIndex		INT = 1,  
    @BaseCurrency	VARCHAR(12) = '',
    @TotalRows		INT = 0 OUTPUT 
AS
/*
Created:Bobby@20190723   
Task : 112658 - LAP - Customer Daily Statement
DB: DBACC/bodb02
Original: [Lrf_Statement_Mem]

Revisions:  
	- 20190723@Bobby: Initialize [RedmineID: #117534]
	- 20190904@Bobby: Implement Statement Service - Level 1 [RedmineID: #119648]
	- 20190919@Bobby: Enhance Statement Level 1 - show outstanding for future [RedmineID: #119648]
	- 20191024@Bobby: Correct running and void [RedmineID: #120690]
	- 20191003@Bobby: Integrate NPH Promotion product [RedmineID: #120333]
	- 20200330@Louis: Support Statement & Detail Transaction Report in Chinese [RedmineID: #131262]
	- 20200803@Sophia: add Saba Loyalty [Redmine: #138493]
	- 20210203@Louis: Saba Red Envelope [RedmineID: #149923]
	- 20210518@Percy: Change code to adapt new Move Bets flow [RedmineID: #154866]
	- 20211109@Percy: Fix wrong opening balance issue and add ACCUMULATED BALANCE [RedmineID: #164360]
	- 20211111@Sol: Split Transfer out of bettrans/Support IPv6 - [RedmineID: #164301]
    - 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]
	- 20230227@Evan: Ensure correct balance calculation when allow to transfer 247 (BU) [Redmine: #173554]
	- 20231018@Evan: Integrate Saba Reward Risk-free Rebate + add missing bettype 17006 [redmine: #196881]
	- 20240503@Kelvin: Change excuters login [RedmineID: #204744]
	- 20240416@Evan: Integrate Saba Coins [RedmineID: #202281]
	- 20240808@Kelvin: Add new bettype 11009 for "Saba Nickname Edited" - change bettype range [11001 -> 11049] [RedmineID: #209038]
	- 20250314@Kelvin: Integrate Saba Promotion - Number Game Lucky Draw Promotion [RedmineID: #219835]
	- 20241227@Kelvin: LAP - Saba Coins phase 2 - Support multiple wallets [RedmineID: #215890]

Param's Explanation:     
	- @ReportViewType : TINYINT
		+ 1 - Main Wallet
		+ 2 - Saba coins 
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @currentDate		SMALLDATETIME
		, @_startDate			SMALLDATETIME
		, @_endDate				SMALLDATETIME
		, @_tempStartDate		SMALLDATETIME
		, @_tempEndDate			SMALLDATETIME
		, @_CustID				INT
		, @currency				INT
		, @_SabaID				INT

	DECLARE @BAL_KEY			TINYINT = 0
			, @BET_KEY			TINYINT = 1
			, @VOID_KEY			TINYINT = 2
			, @OUT_KEY			TINYINT = 3
			, @PROMO_KEY		TINYINT = 4
			, @TRAN_KEY			TINYINT = 2
			, @CBGP_KEY			TINYINT = 4
			, @BAL_BETTYPE		INT = 20000
			, @PromoBettypes 	VARCHAR(MAX)

	CREATE TABLE #ListCustID
	(
		custID		INT,
		currency	INT,
		recommend	INT,
		isCOMember	TINYINT
	)

	CREATE TABLE #statementRpt
    (
        winlostdate		DATETIME,
		orderKey		INT,
        transtype		NVARCHAR(128),
        transdesc		NVARCHAR(1000),
        turnover		DECIMAL(15,2) DEFAULT(0),
        totalAmt		DECIMAL(15,2) DEFAULT(0),
        commission		DECIMAL(15,2) DEFAULT(0)
    )

	DECLARE @transDesc TABLE  
    (
        transtype		NVARCHAR(128),
        transdesc		NVARCHAR(1000),
		orderkey		TINYINT,
		betTypeId		SMALLINT
    )

	DECLARE @PROMO_BETTPE TABLE  
    (
		betTypeId		SMALLINT
    )

	INSERT INTO @PROMO_BETTPE (betTypeId)
	SELECT b.typeid FROM bettype b WITH(NOLOCK) 
	WHERE b.typeid BETWEEN 17000 AND 17099
		OR b.typeid BETWEEN 11001 AND 11049

	SELECT @PromoBettypes = STRING_AGG(betTypeId, ',')
	FROM @PROMO_BETTPE

	SELECT @TotalRows	= 0
		, @currentDate	= CURRENT_TIMESTAMP
		, @_CustID		= ISNULL(@CustID, 0)
		, @_startDate	= @FromDate
		, @_endDate		= @ToDate

	IF @ReportViewType = 2
		BEGIN
			SELECT TOP(1) @_SabaID = SabaID
			FROM dbo.Dep_CustSabaInfo r WITH(NOLOCK)
			WHERE CustID = @_custID

			INSERT INTO #ListCustID(CustID)
			SELECT s.CustID
			FROM dbo.Dep_CustSabaInfo s WITH(NOLOCK)
			WHERE s.CustType = 1 AND s.SabaID = @_SabaID

			IF @@ROWCOUNT = 0
				SELECT @_CustID = 0
		END
	ELSE
		BEGIN
			INSERT INTO #ListCustID(CustID)
			SELECT @_CustID
		END

	UPDATE tmp
	SET currency = c.currency, recommend = c.recommend
	FROM #ListCustID tmp
		INNER JOIN dbo.custinfo c WITH(NOLOCK) ON c.custid = tmp.custID

	SELECT TOP(1) @currency = currency FROM #ListCustID
	
	UPDATE tmp
	SET isCOMember = ISNULL(t.isCOMember,0)
	FROM #ListCustID tmp
		OUTER APPLY (SELECT TOP(1) 1 AS isCOMember FROM dbo.TradeCust t WITH(NOLOCK) WHERE t.custid = tmp.custID AND VendorID = 14) t

	-- validate time range & custid
	IF (@_startDate > @_endDate
		OR @BalanceUpDay IS NULL
		OR @MoveBetsDay IS NULL
		OR @BalanceUpDay > @MoveBetsDay
		OR @currency IS NULL
		OR @_CustID <= 0)
	BEGIN
		RETURN
	END

	INSERT INTO @transDesc (orderkey, transtype, transdesc, betTypeId)
	SELECT @BAL_KEY	AS OrderKey, 'BAL' AS TransType, 'Opening_Balance' AS TransDesc, 0 AS betTypeId
	UNION ALL
	SELECT @BET_KEY, 'BET', 'Bet_Statement', 0
	UNION ALL
	SELECT @VOID_KEY, 'BET', 'Void_Cancelled_Bet', 0
	UNION ALL
	SELECT @OUT_KEY, 'BET', 'Outstanding_Bet', 0
	UNION ALL
	SELECT @PROMO_KEY, 'PROMO', 'Promotion_Prize', 0
	UNION ALL
	SELECT @CBGP_KEY, 'GP', 'Grand_Prize', 0
	UNION ALL
	SELECT @TRAN_KEY, UPPER(typenamee), ISNULL(typedesc,''), typeid
	FROM bodb02.dbo.bettype (NOLOCK)
	WHERE typeid > @BAL_BETTYPE

	------------- START INIT: OPENING BALANCE ---------------
	IF (@_startDate < @BalanceUpDay)
	BEGIN
		DECLARE @rptToDate DATETIME = @_startDate
		DECLARE @rptFromDate DATETIME = DATEADD(DAY, -7, @rptToDate)
		
		-- INSERT the previous BAL transaction
		INSERT INTO #statementRpt (orderkey, winlostdate, transtype, transdesc, turnover,TotalAmt,commission)
		SELECT TOP(1)
			@BAL_KEY AS orderkey
			, rpt.accdate
			, UPPER(rpt.transtype)
			, NULL
			, 0 AS turnover
			, SUM(rpt.totalAmt) AS TotalAmt
			, 0 AS commission
		FROM bodb_report.dbo.[Statement] rpt WITH (NOLOCK)
			INNER JOIN #ListCustID c ON c.custID = rpt.custid
		WHERE rpt.accdate BETWEEN @rptFromDate AND @rptToDate
			AND rpt.transtype = 'BAL'
		GROUP BY rpt.accdate
			, UPPER(rpt.transtype)
		ORDER BY rpt.accdate DESC
	END
	ELSE
	BEGIN
		INSERT INTO #statementRpt (orderkey, winlostdate, transtype, transdesc, turnover,TotalAmt,commission)
		SELECT @BAL_KEY,
			b.winlostdate
			,'BAL'
			,NULL  
			,0 AS turnover
			,SUM(b.winlost - b.actual_stake) AS TotalAmt
			,0 AS commission
		FROM bodb02.dbo.Transfer b WITH(NOLOCK)
			INNER JOIN #ListCustID c ON c.custID = b.custid
		WHERE b.bettype = @BAL_BETTYPE AND winlostdate = @BalanceUpDay
		GROUP BY b.winlostdate
	END
	------------- END INIT: OPENING BALANCE ---------------

	-- RESET FromDate for ACCUMULATED BALANCE
	SET @_startDate = NULL
	SELECT @_startDate = winlostdate FROM #statementRpt

	IF @_startDate IS NULL
		SET @_startDate = CASE WHEN @FromDate < @BalanceUpDay THEN DATEADD(DAY, -7, @FromDate) ELSE @BalanceUpDay END
	
	DECLARE @isCurrentMonth BIT
	SELECT  @isCurrentMonth = CASE WHEN MONTH(@_endDate) >= MONTH(@currentDate) THEN 1 ELSE 0 END

	--------------- Start: PROCESS data ------------------------
	-- after @BalanceUpDay - Mix up
	IF (@_endDate >= @BalanceUpDay OR @isCurrentMonth = 1)
	BEGIN   
		-- bettrans_bk tickets & [Statement] opening balance - before @BalanceUpDay
		IF (@_startDate < @BalanceUpDay)
		BEGIN 
			SELECT @_tempStartDate	=  @_startDate
				, @_tempEndDate		= CASE WHEN @_endDate >= @BalanceUpDay THEN DATEADD(DAY, -1, @BalanceUpDay) ELSE @_endDate END

			INSERT INTO #statementRpt (orderkey, winlostdate, transtype, transdesc, turnover,TotalAmt,commission)
			SELECT f.orderkey, f.winlostdate, f.transtype, f.transdesc, f.turnover, f.TotalAmt, f.commission
			FROM bodb02.dbo.LAP_f_Statement_Mem_Summary(@_CustID, @_tempStartDate, @_tempEndDate, @PromoBettypes, @ReportViewType) AS f
			LEFT JOIN #statementRpt temp 
				ON f.winlostdate = temp.winlostdate AND f.transtype = temp.transtype
			WHERE temp.winlostdate IS NULL
		END

		-- bettrans14 tickets - after @BalanceUpDay
		IF (@_endDate >= @BalanceUpDay)
		BEGIN 
			SELECT @_tempStartDate	=  CASE WHEN @_startDate <= @BalanceUpDay THEN @BalanceUpDay ELSE @_startDate END
				, @_tempEndDate		= CASE WHEN @_endDate >= @MoveBetsDay THEN @MoveBetsDay ELSE @_endDate END

			-- bet tickets
			INSERT INTO #statementRpt (orderkey, winlostdate, transtype, transdesc, turnover,totalamt,commission)
			SELECT 
				CASE
					WHEN statusID IN (101, 102, 103) AND pb.betTypeId IS NULL THEN @VOID_KEY
					WHEN pb.betTypeId IS NOT NULL THEN @PROMO_KEY
					ELSE @BET_KEY END AS orderkey, 
				winlostdate,
				CASE WHEN pb.betTypeId IS NOT NULL THEN 'PROMO' ELSE 'BET' END AS transtype,
				NULL AS transdesc,
				SUM(CASE 
					WHEN bettype IN (33, 43) AND liveawayscore = 0 AND livehomescore <> 0 AND ruben = 1 THEN stake/2 
					ELSE stake END
				) AS turnover,  
				SUM(winlost-actual_stake) AS totalamt,
				SUM(playercomm) AS commission
			FROM bodb02.dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN #ListCustID c ON c.custID = b.custid
				LEFT JOIN @PROMO_BETTPE pb ON pb.betTypeId = b.bettype
			WHERE
				b.winlostdate >= @_tempStartDate and winlostdate <= @_tempEndDate
				AND b.bettype NOT IN (903, 71, 913, 914)
				AND ((c.isCOMember = 0 AND b.bettype <> 912) OR (c.isCOMember = 1 AND b.bettype <> 911))
			GROUP BY
				CASE
					WHEN statusID IN (101, 102, 103) AND pb.betTypeId IS NULL THEN @VOID_KEY
					WHEN pb.betTypeId IS NOT NULL THEN @PROMO_KEY
					ELSE @BET_KEY END, 
				winlostdate,
				CASE WHEN pb.betTypeId IS NOT NULL THEN 'PROMO' ELSE 'BET' END
		END  

		-- bettrans tickets -- after @MoveBetsDay
		IF (@_endDate > @MoveBetsDay OR @isCurrentMonth = 1)
		BEGIN
			SELECT @_tempStartDate  =  CASE WHEN @_startDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay) ELSE @_startDate END
				, @_tempEndDate		=  @_endDate

			-- bet tickets
			INSERT INTO #statementRpt (orderkey, winlostdate, transtype, transdesc, turnover,totalamt,commission)
			SELECT orderkey, winlostdate, transtype, transdesc
				,SUM(turnover)
				,SUM(totalamt)
				,SUM(commission)
			FROM (
				SELECT 
					CASE
						WHEN statusID IN (0, 1) THEN @OUT_KEY
						WHEN statusID IN (101, 102, 103) AND pb.betTypeId IS NULL THEN @VOID_KEY
						WHEN pb.betTypeId IS NOT NULL THEN @PROMO_KEY
						ELSE @BET_KEY END AS orderkey,  
					winlostdate,
					CASE WHEN pb.betTypeId IS NOT NULL THEN 'PROMO' ELSE 'BET' END AS transtype,
					NULL transdesc,
					SUM(CASE 
						WHEN bettype IN (33, 43) AND liveawayscore = 0 AND livehomescore <> 0 AND ruben = 1 THEN stake/2 
						WHEN statusID IN (0, 1) THEN ABS(actual_stake)
						ELSE stake END
					) AS turnover,  
					SUM(CASE WHEN statusID IN (0, 1) THEN 0 ELSE winlost-actual_stake END) AS totalamt,
					SUM(playercomm) AS commission

				FROM 
					bodb02.dbo.bettrans b WITH (NOLOCK)
					INNER JOIN #ListCustID c ON c.custID = b.custid
					LEFT JOIN @PROMO_BETTPE pb ON pb.betTypeId = b.bettype 
				WHERE
					winlostdate >= @_tempStartDate
					AND b.bettype NOT IN (903, 71, 913, 914)
					AND ((c.isCOMember = 0 AND bettype <> 912) OR (c.isCOMember = 1 AND bettype <> 911))
					AND 1 = CASE 
								WHEN statusID IN (0, 1) AND @isCurrentMonth = 1 THEN 1
								WHEN statusID IN (101, 102, 103) AND @isCurrentMonth = 1 THEN 1
								WHEN b.winlostdate <= @_tempEndDate THEN 1
								ELSE 0
							END
				GROUP BY
					CASE
						WHEN statusID IN (0, 1) THEN @OUT_KEY
						WHEN statusID IN (101, 102, 103) AND pb.betTypeId IS NULL THEN @VOID_KEY
						WHEN pb.betTypeId IS NOT NULL THEN @PROMO_KEY
						ELSE @BET_KEY END,  
					winlostdate,
					CASE WHEN pb.betTypeId IS NOT NULL THEN 'PROMO' ELSE 'BET' END
			
				--include running Keno bet
				UNION ALL
				SELECT
					@OUT_KEY,
					winlostdate,
					'BET',  
					NULL AS transdesc, 
					SUM(actual_stake),  
					0,
					0 
				FROM bodb02.dbo.translog b WITH (NOLOCK)
					INNER JOIN #ListCustID c ON c.custID = b.custid
				WHERE
					statusID IN (0,1) -- get only running game _ Keno
					AND winlostdate >= @_tempStartDate
					AND 1 = CASE 
								WHEN @isCurrentMonth = 1 THEN 1
								WHEN winlostdate <= @_tempEndDate  THEN 1
								ELSE 0
							END
						
				GROUP BY winlostdate
		
				--include running Microgaming + RNG Casino + Voidbridge
				UNION ALL
				SELECT
					@OUT_KEY,
					winlostdate,
					'BET',
					NULL,
					SUM(actual_stake),
					0,
					0 
				FROM bodb02.dbo.bettransRnG b WITH (NOLOCK)
					INNER JOIN #ListCustID c ON c.custID = b.custid
				WHERE
					winlostdate >= @_tempStartDate
					AND 1 = CASE 
								WHEN @isCurrentMonth = 1 THEN 1
								WHEN winlostdate <= @_tempEndDate  THEN 1
								ELSE 0
							END 
					AND statusID = 0 -- get only running game _ bettransRnG
				GROUP BY 
					winlostdate
		
				-- get only running game _ bettransLC
				UNION ALL
				SELECT
					@OUT_KEY,
					winlostdate,
					'BET',
					NULL,
					SUM(actual_stake),
					0,
					0  
				FROM bodb02.dbo.bettransLC b WITH (NOLOCK)
					INNER JOIN #ListCustID c ON c.custID = b.custid AND c.recommend = b.recommend
				WHERE					
					winlostdate >= @_tempStartDate
					AND 1 = CASE 
								WHEN @isCurrentMonth = 1 THEN 1
								WHEN winlostdate <= @_tempEndDate  THEN 1
								ELSE 0
							END
					AND statusID = 0
				GROUP BY 
					winlostdate
			) AS rpt
			GROUP BY
				orderkey
				, winlostdate
				, transtype
				, transdesc
		END

		-- bettrans transfer
		SELECT @_tempStartDate = @BalanceUpDay;
		WITH CTE_transfer AS (
			SELECT 
				CASE WHEN b.bettype = @BAL_BETTYPE THEN @BAL_KEY ELSE @TRAN_KEY END AS orderkey,
				CASE WHEN b.bettype = @BAL_BETTYPE THEN b.winlostdate ELSE b.transdate END AS winlostdate,
				CASE WHEN b.bettype = @BAL_BETTYPE THEN 'BAL' ELSE UPPER(bt.typenamee) END AS transtype ,
				CASE WHEN b.bettype = @BAL_BETTYPE THEN NULL ELSE b.transdesc END AS transdesc,
				SUM(stake) AS turnover,
				SUM(winlost-actual_stake) AS totalamt,
				SUM(playercomm) AS commission
			FROM bodb02.dbo.Transfer b WITH (NOLOCK)
				INNER JOIN #ListCustID c ON c.custID = b.custid
				INNER JOIN dbo.bettype bt WITH(NOLOCK) ON b.bettype = bt.typeid
			WHERE
				b.winlostdate >= @_tempStartDate and b.winlostdate <= @_tempEndDate
				AND b.bettype >= @BAL_BETTYPE
				AND 1 = CASE WHEN bettype = @BAL_BETTYPE AND winlostdate > @BalanceUpDay THEN 0 --> new bal
						WHEN winlostdate < @BalanceUpDay THEN 0 --> old data
						ELSE 1 END
			GROUP BY
				CASE WHEN b.bettype = @BAL_BETTYPE THEN @BAL_KEY ELSE @TRAN_KEY END,
				CASE WHEN b.bettype = @BAL_BETTYPE THEN b.winlostdate ELSE b.transdate END,
				CASE WHEN b.bettype = @BAL_BETTYPE THEN 'BAL' ELSE UPPER(bt.typenamee) END,
				CASE WHEN b.bettype = @BAL_BETTYPE THEN NULL ELSE b.transdesc END
		)
		INSERT INTO #statementRpt (orderkey, winlostdate, transtype, transdesc, turnover,totalamt,commission)
		SELECT b.orderkey, b.winlostdate, b.transtype, b.transdesc, b.turnover, b.totalamt, b.commission 
		FROM CTE_transfer b 
		LEFT JOIN #statementRpt temp
			ON b.winlostdate = temp.winlostdate AND b.transtype = temp.transtype
		WHERE temp.winlostdate IS NULL
	END
		
	-- before @BalanceUpDay --> bettrans_bk & [Statement] - only
	IF (@_endDate < @BalanceUpDay)  
	BEGIN
		INSERT INTO #statementRpt (orderkey, winlostdate, transtype, transdesc, turnover,TotalAmt,commission)
		SELECT f.orderkey, f.winlostdate, f.transtype, f.transdesc, f.turnover, f.TotalAmt, f.commission
		FROM bodb02.dbo.LAP_f_Statement_Mem_Summary(@_CustID, @_startDate, @_endDate, @PromoBettypes, @ReportViewType) AS f
		LEFT JOIN #statementRpt temp 
			ON f.winlostdate = temp.winlostdate AND f.transtype = temp.transtype
		WHERE temp.winlostdate IS NULL
	END
	
	--------------- End: PROCESS data ------------------------

	---------Get Data of PayOutTrans for Progressive Jackpot Win ----------
	INSERT INTO #statementRpt(OrderKey, winlostdate, transtype, transdesc, TurnOver, TotalAmt, Commission)
	SELECT
		@CBGP_KEY AS OrderKey,
		winlostdate,
		'GP' AS transtype,
		NULL AS transdesc,
		0,
		SUM (WinAmount) AS TotalAmt,
		0
	FROM bodb02.dbo.PayoutTrans b WITH (NOLOCK)
		INNER JOIN #ListCustID c ON c.custID = b.custid
	WHERE winlostdate BETWEEN @_startDate AND @_endDate
	GROUP BY winlostdate
	-----------------------------------------------------------------------------

	---- Calculate for ACCUMULATED BALANCE
	IF (@_startDate	< @FromDate)
	BEGIN
		IF NOT EXISTS (SELECT 1 FROM #statementRpt WHERE winlostdate = @FromDate AND transtype = 'BAL')
			INSERT INTO #statementRpt (winlostdate, orderKey, transtype, transdesc, turnover, totalAmt, commission)
			SELECT NULL, @BAL_KEY, 'BAL', 'Accumulated_Balance', 0 AS turnover, SUM(ISNULL(totalAmt, 0) + ISNULL(commission, 0)), 0 AS commission
			FROM #statementRpt
			WHERE winlostdate < @FromDate
			HAVING COUNT(1) > 0

		DELETE #statementRpt WHERE winlostdate < @FromDate
	END

	DECLARE @rowStart		INT
		, @rowEnd			INT

    SELECT  @PageIndex		= CASE WHEN @PageIndex > 0 THEN @PageIndex - 1 ELSE 0 END,
            @RowStart		= @PageSize * @PageIndex + 1,
            @RowEnd			= @RowStart + @PageSize - 1
	
	-- SET @TotalRows
	SELECT @TotalRows		= COUNT(1)
	FROM #statementRpt rpt;

	 --RETURN output result
	;WITH CTE_Paging AS (
		SELECT ROW_NUMBER() OVER (ORDER BY winlostdate, orderKey, transtype) AS rownum
			,winlostdate, orderKey, transtype, transdesc, TurnOver, TotalAmt, Commission
		FROM #statementRpt
	)
	SELECT 
		rpt.rownum
		,rpt.winlostdate
		,rpt.transtype
		,ISNULL(rpt.transdesc, dsc.transdesc)	AS transdesc
		,CAST(rpt.turnover AS DECIMAL(15,2))	AS turnover
		,CAST(rpt.TotalAmt AS DECIMAL(15,2))	AS totalamt
		,CAST(rpt.commission AS DECIMAL(15,2))	AS commission
		, dsc.betTypeId
		
	FROM CTE_Paging rpt
		LEFT JOIN @transDesc dsc 
			ON rpt.OrderKey		= dsc.orderkey 
			AND rpt.transtype	= dsc.transtype
	WHERE 
		rpt.RowNum BETWEEN @RowStart AND @RowEnd
	ORDER BY 
		rpt.RowNum

	DROP TABLE #statementRpt
	DROP TABLE #ListCustID
END
GO
