/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet,bodbDownlineNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[LAP_Statement_Mem]  
    @CustID			INT,  
    @FromDate		SMALLDATETIME,  
    @ToDate			SMALLDATETIME,  
    @BalanceUpDay	SMALLDATETIME,  
    @MoveBetsDay	SMALLDATETIME,  
    @PageSize		INT = 50,  
    @PageIndex		INT = 1,  
    @BaseCurrency	VARCHAR(3) = '',
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
	
Param's Explanation:     
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @previousBalanceUpDay	DATE
		, @isCOMember				BIT --Cash Out member
		, @currentDate				SMALLDATETIME
		, @currency					INT  
		, @_startDate				SMALLDATETIME
		, @_endDate					SMALLDATETIME
		, @_tempStartDate			SMALLDATETIME
		, @_tempEndDate				SMALLDATETIME
		, @_CustID					INT
		, @_recommend				INT

	DECLARE @BAL_KEY			TINYINT = 0
			, @BET_KEY			TINYINT = 1
			, @VOID_KEY			TINYINT = 2
			, @OUT_KEY			TINYINT = 3
			, @PROMO_KEY		TINYINT = 4
			, @TRAN_KEY			TINYINT = 2
			, @CBGP_KEY			TINYINT = 4
			, @BAL_BETTYPE		INT = 20000

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

	SELECT @TotalRows	= 0
		, @currentDate	= CURRENT_TIMESTAMP
		, @_CustID		= ISNULL(@CustID, 0)
		, @_startDate	= @FromDate
		, @_endDate		= @ToDate

	SELECT TOP(1) @currency	= currency, @_recommend = recommend
	FROM dbo.custinfo (NOLOCK) 
	WHERE custid = @_CustID  
	
	SELECT TOP 1 @isCOMember = 1
	FROM dbo.TradeCust WITH(NOLOCK)
	WHERE custid = @_CustID
		AND VendorID = 14

	SELECT @isCOMember	= ISNULL(@isCOMember,0)

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
		-- INSERT the previous BAL transaction
		INSERT INTO #statementRpt (orderkey, winlostdate, transtype, transdesc, turnover,TotalAmt,commission)
		SELECT TOP(1)
			@BAL_KEY AS orderkey
			, rpt.accdate
			, UPPER(rpt.transtype)
			, NULL
			, 0 AS turnover, rpt.totalAmt AS TotalAmt , 0 AS commission
		FROM bodb_report.dbo.[Statement] rpt WITH (NOLOCK)  
		WHERE rpt.custid = @_CustID
			AND rpt.accdate <= @_startDate
			AND rpt.transtype = 'BAL'
		ORDER BY rpt.accdate DESC

		-- SET @previousBalanceUpDay
		SELECT @previousBalanceUpDay = winlostdate
		FROM #statementRpt
	END
	ELSE
	BEGIN
		INSERT INTO #statementRpt (orderkey, winlostdate, transtype, transdesc, turnover,TotalAmt,commission)
		SELECT @BAL_KEY,
			b.winlostdate
			,'BAL'
			,NULL  
			,0 AS turnover
			,(b.winlost - b.actual_stake) AS TotalAmt
			,0 AS commission
		FROM bodb02.dbo.bettrans b (NOLOCK)
		WHERE b.custid = @_CustID  
			AND b.bettype = @BAL_BETTYPE

		-- SET @previousBalanceUpDay
		SELECT @previousBalanceUpDay = winlostdate
		FROM #statementRpt
	END

	-- INSERT dummy OPENING BALANCE transaction for reactive member OR new member without balanceup day
	IF (NOT EXISTS(SELECT TOP 1 1 FROM #statementRpt))
	BEGIN
		IF(@previousBalanceUpDay IS NULL)
		BEGIN
			SELECT @previousBalanceUpDay =  @_startDate
			WHILE(DATEPART(DW,@previousBalanceUpDay) <> 6)
				SET @previousBalanceUpDay =  DATEADD(DD, -1, @previousBalanceUpDay)
		END

		INSERT INTO #statementRpt (orderkey, winlostdate, transtype, transdesc, turnover,TotalAmt,commission)
		SELECT @BAL_KEY AS orderkey
			, @previousBalanceUpDay AS winlostdate
			, 'BAL' transtype
			, NULL AS transdesc
			, 0 AS turnover, 0 AS TotalAmt, 0 AS commission
	END
	------------- END INIT: OPENING BALANCE ---------------

	-- RESET FromDate
	SELECT @_startDate = @previousBalanceUpDay
	
	DECLARE @isCurrentMonth BIT
	SELECT @isCurrentMonth = CASE WHEN MONTH(@_endDate) >= MONTH(@currentDate) THEN 1 ELSE 0 END

	--------------- Start: PROCESS data ------------------------
	-- after @BalanceUpDay - Mix up
	IF (@_endDate >= @BalanceUpDay OR @isCurrentMonth = 1)
	BEGIN   
		-- bettrans_bk tickets & [Statement] opening balance - before @BalanceUpDay
		IF (@_startDate < @BalanceUpDay)
		BEGIN 
			SELECT @_tempStartDate	=  @_startDate
				, @_tempEndDate		= @BalanceUpDay-1

			INSERT INTO #statementRpt (orderkey, winlostdate, transtype, transdesc, turnover,TotalAmt,commission)
			SELECT f.orderkey, f.winlostdate, f.transtype, f.transdesc, f.turnover, f.TotalAmt, f.commission
			FROM bodb02.dbo.LAP_f_Statement_Mem_Summary(@_CustID, @_tempStartDate, @_tempEndDate) AS f
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
					WHEN statusID IN (101, 102, 103) AND bettype NOT IN (17000) THEN @VOID_KEY
					WHEN bettype IN (17000) THEN @PROMO_KEY
					ELSE @BET_KEY END AS orderkey, 
				winlostdate,
				CASE WHEN bettype IN (17000) THEN 'PROMO' ELSE 'BET' END AS transtype,
				NULL AS transdesc,
				SUM(CASE 
					WHEN bettype IN (33, 43) AND liveawayscore = 0 AND livehomescore <> 0 AND ruben = 1 THEN stake/2 
					ELSE stake END
				) AS turnover,  
				SUM(winlost-actual_stake) AS totalamt,
				SUM(playercomm) AS commission
			FROM bodb02.dbo.bettrans14 b WITH (NOLOCK)  
			WHERE
				b.custid = @_CustID  
				AND b.winlostdate >= @_tempStartDate and winlostdate <= @_tempEndDate
				AND b.bettype NOT IN (903, 71, 913, 914)
				AND ((@IsCOMember = 0 AND b.bettype <> 912) OR (@IsCOMember = 1 AND b.bettype <> 911))
			GROUP BY
				CASE
					WHEN statusID IN (101, 102, 103) AND bettype NOT IN (17000) THEN @VOID_KEY
					WHEN bettype IN (17000) THEN @PROMO_KEY
					ELSE @BET_KEY END, 
				winlostdate,
				CASE WHEN bettype IN (17000) THEN 'PROMO' ELSE 'BET' END
		END  

		-- bettrans tickets -- after @MoveBetsDay
		IF (@_endDate > @MoveBetsDay OR @isCurrentMonth = 1)
		BEGIN
			SELECT @_tempStartDate  =  CASE WHEN @_startDate <= @MoveBetsDay THEN @MoveBetsDay-1 ELSE @_startDate END
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
						WHEN statusID IN (101, 102, 103) AND bettype NOT IN (17000) THEN @VOID_KEY
						WHEN bettype IN (17000) THEN @PROMO_KEY
						ELSE @BET_KEY END AS orderkey,  
					winlostdate,
					CASE WHEN bettype IN (17000) THEN 'PROMO' ELSE 'BET' END AS transtype,
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

				WHERE
					custid = @_CustID  
					AND winlostdate >= @_tempStartDate
					AND b.bettype < 19999
					AND b.bettype NOT IN (903, 71, 913, 914)
					AND ((@IsCOMember = 0 AND bettype <> 912) OR (@IsCOMember = 1 AND bettype <> 911))
					AND 1 = CASE 
								WHEN statusID IN (0, 1) AND @isCurrentMonth = 1 THEN 1
								WHEN statusID IN (101, 102, 103) AND @isCurrentMonth = 1 THEN 1
								WHEN b.winlostdate <= @_tempEndDate THEN 1
								ELSE 0
							END
				GROUP BY
					CASE
						WHEN statusID IN (0, 1) THEN @OUT_KEY
						WHEN statusID IN (101, 102, 103) AND bettype NOT IN (17000) THEN @VOID_KEY
						WHEN bettype IN (17000) THEN @PROMO_KEY
						ELSE @BET_KEY END,  
					winlostdate,
					CASE WHEN bettype IN (17000) THEN 'PROMO' ELSE 'BET' END
			
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
				FROM bodb02.dbo.translog WITH (NOLOCK)
				WHERE
					statusID IN (0,1) -- get only running game _ Keno
					AND custid = @_CustID  
					AND winlostdate >= @_tempStartDate
					AND 1 = CASE 
								WHEN @isCurrentMonth = 1 THEN 1
								WHEN winlostdate <= @_tempEndDate  THEN 1
								ELSE 0
							END
						
				GROUP BY 
					winlostdate
		
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
				FROM bodb02.dbo.bettransRnG WITH (NOLOCK)
				WHERE
					custid = @_CustID  
					AND winlostdate >= @_tempStartDate
					AND 1 = CASE 
								WHEN @isCurrentMonth = 1 THEN 1
								WHEN winlostdate <= @_tempEndDate  THEN 1
								ELSE 0
							END 
					AND statusID = 0 -- get only running game _ bettransRnG
				GROUP BY 
					winlostdate
		
				-- get only running game _ bettransRnG
				UNION ALL
				SELECT
					@OUT_KEY,
					winlostdate,
					'BET',
					NULL,
					SUM(actual_stake),
					0,
					0  
				FROM bodb02.dbo.bettransLC WITH (NOLOCK)
				WHERE
					recommend = @_recommend
					AND winlostdate >= @_tempStartDate
					AND 1 = CASE 
								WHEN @isCurrentMonth = 1 THEN 1
								WHEN winlostdate <= @_tempEndDate  THEN 1
								ELSE 0
							END
					AND custid = @_CustID  
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
				stake AS turnover,  
				winlost-actual_stake AS totalamt,
				playercomm AS commission
			FROM bodb02.dbo.bettrans b WITH (NOLOCK)  
			INNER JOIN dbo.bettype bt WITH(NOLOCK) ON b.bettype = bt.typeid
				
			WHERE
				b.custid = @_CustID  
				AND b.winlostdate >= @_tempStartDate and b.winlostdate <= @_tempEndDate
				AND b.matchid = 0 AND b.bettype >= @BAL_BETTYPE
					
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
		FROM bodb02.dbo.LAP_f_Statement_Mem_Summary(@_CustID, @_startDate, @_endDate) AS f
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
	FROM bodb02.dbo.PayoutTrans WITH (NOLOCK)
	WHERE custid = @_CustID
		AND winlostdate BETWEEN @_startDate AND @_endDate
	GROUP BY winlostdate, CustID
	-----------------------------------------------------------------------------

	---- Check for RECAL initial OPENNING BALANCE
	IF (@_startDate	< @FromDate)
	BEGIN
		DECLARE @totalInitBalance MONEY

		SELECT @totalInitBalance = SUM(ISNULL(TotalAmt,0) + ISNULL(Commission,0))
		FROM #statementRpt
		WHERE winlostdate < @FromDate

		UPDATE rpt
		SET TotalAmt = @totalInitBalance
		FROM #statementRpt rpt
		WHERE transtype = 'BAL'
		AND winlostdate < @FromDate

		DELETE rpt
		FROM #statementRpt rpt
		WHERE transtype <> 'BAL'
		AND winlostdate < @FromDate
	END

	DECLARE @rowStart		INT
		, @rowEnd			INT
		, @fromExRateDate	SMALLDATETIME
		, @toExRateDate		SMALLDATETIME

    SELECT  @PageIndex		= CASE WHEN @PageIndex > 0 THEN @PageIndex - 1 ELSE 0 END,
            @RowStart		= @PageSize * @PageIndex + 1,
            @RowEnd			= @RowStart + @PageSize - 1
	
	-- SET @TotalRows
	SELECT @TotalRows		= COUNT(1)
		,@fromExRateDate	= MIN(winlostdate)
		,@toExRateDate		= MAX(winlostdate)
	FROM #statementRpt rpt;

	 --RETURN output result
	WITH CTE_Exchange AS (
		SELECT f.FromDate
			, DATEADD(DAY, 1, f.ToDate) AS ToDate
			, Rate 
		FROM dbo.Lrf_f_GetExchangeRate(@fromExRateDate, @toExRateDate, @BaseCurrency, '') AS f
		WHERE f.ExchangeID = @currency
	), CTE_Paging AS (
		SELECT ROW_NUMBER() OVER (ORDER BY winlostdate, orderKey, transtype) AS rownum
			,winlostdate, orderKey, transtype, transdesc, TurnOver, TotalAmt, Commission
		FROM #statementRpt
	)
	SELECT 
		rpt.rownum
		,rpt.winlostdate
		,rpt.transtype
		,ISNULL(rpt.transdesc, dsc.transdesc)	AS transdesc
		,CAST(rpt.turnover * ISNULL(ex.Rate, fex.Rate) AS DECIMAL(15,2))	AS turnover
		,CAST(rpt.TotalAmt * ISNULL(ex.Rate, fex.Rate) AS DECIMAL(15,2))	AS totalamt
		,CAST(rpt.commission * ISNULL(ex.Rate, fex.Rate) AS DECIMAL(15,2))	AS commission
		, dsc.betTypeId
		
	FROM CTE_Paging rpt
		LEFT JOIN @transDesc dsc 
			ON rpt.OrderKey		= dsc.orderkey 
			AND rpt.transtype	= dsc.transtype
		LEFT JOIN CTE_Exchange ex 
			ON rpt.winlostdate	>= ex.FromDate 
			AND rpt.winlostdate < ex.ToDate
		OUTER APPLY (
			-- future rate usage
			SELECT Rate
			FROM CTE_Exchange ex 
			WHERE ex.ToDate IN (SELECT MAX(ToDate) FROM CTE_Exchange)
		) AS fex
	WHERE 
		rpt.RowNum BETWEEN @RowStart AND @RowEnd
	ORDER BY 
		rpt.RowNum

	DROP TABLE #statementRpt
END
GO