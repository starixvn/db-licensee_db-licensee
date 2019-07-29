/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet,bodbDownlineNet" viewers="" isFunction="0"></info>*/
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
DB: DBEXT/bodb02
Original: [Lrf_Statement_Mem]

Revisions:  
	- 20190723@Bobby: Initialize [RedmineID: #117534]
	
Param's Explanation:     
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @previousBalanceUpDay	DATE
		, @isCOMember				BIT --Cash Out member
		, @startDate				SMALLDATETIME
		, @endDate					SMALLDATETIME
		, @currentDate				SMALLDATETIME
		, @currency					INT  

	DECLARE @betTicket	TABLE  
    (
		winlostdate		DATETIME,
        bettype			SMALLINT,
        statusID		SMALLINT,
        transdate		DATETIME,
        transdesc		NVARCHAR(300),
        stake			DECIMAL(15,2),
        actual_stake	DECIMAL(15,2),
        winlost			DECIMAL(15,2),
        playercomm		DECIMAL(15,2),
		outstanding		DECIMAL(15,2)
    )

	DECLARE @statementRpt TABLE  
    (  
        OrderKey		INT,
        winlostdate		DATETIME,
        transtype		NVARCHAR(100),
        transdesc		NVARCHAR(300),
        TurnOver		DECIMAL(15,2),
        TotalAmt		DECIMAL(15,2),
        Commission		DECIMAL(15,2),
		Balance			DECIMAL(15,2)
    )

	DECLARE @transDesc TABLE  
    (  
        transtype		NVARCHAR(100),
        transdesc		NVARCHAR(300),
		orderkey		TINYINT
    )

	CREATE TABLE #tempStatementRpt (
		RowNum			INT IDENTITY(1,1) PRIMARY KEY,
		winlostdate		DATETIME,
		OrderKey		INT,
        transtype		NVARCHAR(100),
        transdesc		NVARCHAR(300),
        TurnOver		DECIMAL(15,2),
        TotalAmt		DECIMAL(15,2),
        Commission		DECIMAL(15,2),
		Balance			DECIMAL(15,2)
	)

	SELECT TOP(1) @currency	= currency 
	FROM dbo.custinfo (NOLOCK) 
	WHERE custid = @custid  
	
	IF (@currency IS NULL)
	BEGIN
		SELECT RowNum,winlostdate,transtype,transdesc,TurnOver,TotalAmt,Commission
		FROM #tempStatementRpt
		RETURN
	END


	SELECT TOP 1 @isCOMember = 1
	FROM dbo.TradeCust WITH(NOLOCK)
	WHERE custid = @CustID
		AND VendorID = 14

	SELECT @TotalRows	= 0
		, @currentDate	= CURRENT_TIMESTAMP
		, @isCOMember	= ISNULL(@isCOMember,0)
		, @startDate	= @FromDate
		, @endDate		= CASE WHEN @ToDate > @currentDate THEN @currentDate ELSE @ToDate END

	INSERT INTO @transDesc (orderkey, transtype, transdesc)
	SELECT 0				AS OrderKey
		,'BAL'				AS TransType
		,'OPENING BALANCE'	AS TransDesc
	UNION ALL
	SELECT 1,'BET','Betting Statement'
	UNION ALL
	SELECT 2,'BET','Void/Cancelled Bet'
	UNION ALL
	SELECT 3,'BET','Outstanding Bet'
	UNION ALL
	SELECT 4,'GP','Grand Prize'
	UNION ALL
	SELECT 2, UPPER(typenamee), ISNULL(typedesc,'')
	FROM bodb02.dbo.bettype (NOLOCK)
	WHERE typeid > 20000

	-- validate time range
	IF (@startDate > @endDate OR @BalanceUpDay > @MoveBetsDay) RETURN
	
	-- INIT: OPENING BALANCE
	IF (@startDate < @BalanceUpDay)
	BEGIN
		-- INSERT the previous BAL transaction
		INSERT INTO @statementRpt (orderkey, winlostdate, transtype, transdesc, turnover,TotalAmt,commission, balance)
		SELECT TOP(1)
			0 AS orderkey
			, rpt.accdate
			, UPPER(rpt.transtype)
			, rpt.transdesc
			, 0 AS turnover, rpt.totalAmt AS TotalAmt , 0 AS commission, rpt.totalAmt AS  balance
		FROM DBRPT.bodb_report.dbo.[Statement] rpt WITH (NOLOCK)  
		WHERE rpt.custid = @custid
			AND rpt.accdate <= @startDate
			AND rpt.transtype = 'BAL'
		ORDER BY rpt.accdate DESC

		IF(@@ROWCOUNT = 0)
		BEGIN
			SELECT @previousBalanceUpDay =  @startDate
			WHILE(DATEPART(DW,@previousBalanceUpDay) <> 6)
				SET @previousBalanceUpDay =  DATEADD(DD, -1, @previousBalanceUpDay)
		END

		-- RESET FromDate
		SELECT @startDate = @previousBalanceUpDay
	END
	ELSE
	BEGIN
		INSERT INTO @statementRpt (orderkey, winlostdate, transtype, transdesc, turnover,TotalAmt,commission, balance)
		SELECT 0,
			b.winlostdate
			,'BAL'
			,NULL  
			,0 AS turnover
			,(b.winlost - b.actual_stake) AS TotalAmt
			,0 AS commission
			,(b.winlost - b.actual_stake) AS balance
		FROM dbo.bettrans b (NOLOCK) 
		WHERE b.custid = @custid  
			AND b.bettype = 20000

		-- RESET FromDate
		SELECT @startDate = @BalanceUpDay
			,@previousBalanceUpDay = @BalanceUpDay
	END

	-- INSERT dummy OPENING BALANCE transaction for reactive member OR new member without balanceup day
	IF (NOT EXISTS(SELECT TOP 1 1 FROM @statementRpt))
	BEGIN
		INSERT INTO @statementRpt (orderkey, winlostdate, transtype, transdesc, turnover,TotalAmt,commission, balance)
		SELECT 0 AS orderkey
			, @previousBalanceUpDay AS winlostdate
			, 'BAL' transtype
			, NULL AS transdesc
			, 0 AS turnover, 0 AS TotalAmt, 0 AS commission, 0 AS balance
	END

	-- begin statement report data
	BEGIN
		-- after BalanceUpDay
		IF (@endDate >= @BalanceUpDay)
		BEGIN   
			-- bet summary - before BalanceUpDay
			IF (@startDate < @BalanceUpDay)
			BEGIN 
				INSERT INTO @statementRpt (orderkey, winlostdate, transtype, transdesc, turnover,TotalAmt,commission, balance)
				SELECT f.orderkey, f.winlostdate, f.transtype, f.transdesc, f.turnover, f.TotalAmt, f.commission, f.balance
				FROM dbo.LAP_f_Statement_Mem_Summary(@CustID, @startDate, @BalanceUpDay) AS f
					LEFT JOIN @statementRpt temp 
							ON f.winlostdate = temp.winlostdate
							AND temp.transtype	= 'BAL'
				WHERE temp.winlostdate IS NULL
			END  

			-- bettrans range -- after BalanceUpDay
			BEGIN
				-- bet tickets
				INSERT INTO @betTicket(winlostdate, bettype, statusID, transdate, transdesc, stake, actual_stake, winlost, playercomm, outstanding)
				SELECT 
					winlostdate,
					bettype,
					CASE
						WHEN statusID IN (101, 102) THEN 102
						WHEN statusID IN (0, 1) THEN 0
						ELSE 131 END AS statusID,  
					CASE WHEN bettype <= 19999 THEN NULL ELSE transdate END,
					'' AS transdesc, -- Range time > BU : Remark do not show from bettrans.transdesc
					--CASE WHEN bettype <= 19999 THEN '' ELSE transdesc END AS transdesc,
					SUM(CASE 
						WHEN bettype IN (33, 43) AND liveawayscore = 0 AND livehomescore <> 0 AND ruben = 1 THEN stake/2 
						ELSE stake END
					) AS stake,  
					SUM(actual_stake) AS actual_stake,
					SUM(winlost) AS winlost,
					SUM(playercomm) AS playercomm,
					SUM(CASE WHEN statusID IN (0,1) THEN ABS(actual_stake) ELSE 0 END) AS outstanding
				FROM bodb02.dbo.bettrans WITH (NOLOCK)  
				WHERE
					custid = @custid  
					AND winlostdate >= @BalanceUpDay and winlostdate <= @endDate
					AND bettype NOT IN (903, 71, 913, 914)
					AND ((@IsCOMember = 0 AND bettype <> 912) OR (@IsCOMember = 1 AND bettype <> 911))
				GROUP BY
					winlostdate,
					bettype,
					CASE
						WHEN statusID IN (101, 102) THEN 102
						WHEN statusID IN (0, 1) THEN 0
						ELSE 131 END,
					CASE WHEN bettype <= 19999 THEN NULL ELSE transdate END
					--CASE WHEN bettype <= 19999 THEN '' ELSE transdesc END
			
				--include running Keno bet
				INSERT INTO @betTicket(winlostdate, bettype, statusID, transdate, transdesc, stake, actual_stake, winlost, playercomm, outstanding)
				SELECT
					winlostdate,
					gameid,
					0, --running bet
					NULL,  
					'' AS transdesc, 
					SUM(stake),  
					SUM(actual_stake),  
					0, --winlost
					0,  --playcomm
					SUM(actual_stake)
				FROM bodb02.dbo.translog WITH (NOLOCK)
				WHERE
					custid = @custid  
					AND winlostdate >= @BalanceUpDay and winlostdate <= @endDate  
					AND statusID IN (0,1) -- get only running game _ Keno
				GROUP BY 
					winlostdate
					, gameID
		
				--include running Microgaming + RNG Casino + Voidbridge
				INSERT INTO @betTicket(winlostdate, bettype, statusID, transdate, transdesc, stake, actual_stake, winlost, playercomm, outstanding)
				SELECT
					winlostdate,
					gameid,
					0,
					NULL,
					'' transdesc,
					SUM(stake),
					SUM(actual_stake),
					0, --winlost
					0,  --playcomm
					SUM(actual_stake)
				FROM bodb02.dbo.bettransRnG WITH (NOLOCK)
				WHERE
					custid = @custid  
					AND winlostdate >= @BalanceUpDay and winlostdate <= @endDate  
					AND statusID = 0 -- get only running game _ bettransRnG
				GROUP BY 
					winlostdate
					, gameID
		
				-- get only running game _ bettransRnG
				INSERT INTO @betTicket(winlostdate, bettype, statusID, transdate, transdesc, stake, actual_stake, winlost, playercomm, outstanding)
				SELECT
					winlostdate,
					gameid,
					0,
					NULL,
					'' transdesc,
					SUM(stake),
					SUM(actual_stake),
					0, --winlost
					0,  --playcomm
					SUM(actual_stake)
				FROM bodb02.dbo.bettransLC WITH (NOLOCK)
				WHERE
					custid = @custid  
					AND winlostdate >= @BalanceUpDay and winlostdate <= @endDate  
					AND statusID = 0 
				GROUP BY 
					winlostdate
					, gameID
				
				-- insert into statement rpt
				INSERT INTO @statementRpt (orderkey, winlostdate, transtype, transdesc, turnover,TotalAmt,commission)
				SELECT rpt.orderkey, rpt.winlostdate, rpt.transtype, rpt.transdesc, SUM(rpt.turnover), SUM(rpt.TotalAmt), SUM(rpt.commission)
				FROM (
					SELECT
						1 AS orderkey,
						winlostdate,
						'BET' AS transtype,
						NULL AS transdesc,
						SUM(CASE WHEN bettype IN (911, 912) THEN 0 ELSE stake END) AS turnover,
						SUM(winlost - actual_stake) AS TotalAmt,  
						SUM(playercomm) AS commission
					FROM @betTicket  
					WHERE
						bettype <= 19999  
						AND statusID = 131  
					GROUP BY winlostdate    
     		 
					-- Outstanding Bet tickets
					UNION ALL
					SELECT
						3,
						winlostdate,
						'BET',
						NULL,
						SUM(outstanding),
						0,
						0
					FROM @betTicket
					WHERE
						statusID = 0 
						AND bettype NOT IN (23001, 23002, 23101, 23102, 23201, 23202)
					GROUP BY winlostdate    
					

					-- OPENING BALANCE
					UNION ALL
					SELECT
						0,
						b.winlostdate,
						'BAL',
						NULL,
						0,
						SUM(b.winlost-b.actual_stake),
						0
					FROM @betTicket b
					WHERE
						b.bettype = 20000
					GROUP BY b.winlostdate    

					-- Transaction
					UNION ALL
					SELECT
						2,
						transdate,
						UPPER(typenamee),
						B.transdesc,
						0,
						(winlost - actual_stake),
						0
					FROM @betTicket AS B  
						INNER JOIN bodb02.dbo.bettype (NOLOCK) ON B.bettype = bettype.typeid  
					WHERE
						bettype > 20000  
						AND bettype NOT IN (23001, 23002, 23101, 23102, 23201, 23202)
						AND winlost <> actual_stake
				) AS rpt
					LEFT JOIN @statementRpt temp 
					ON rpt.winlostdate = temp.winlostdate AND temp.transtype = 'BAL'
					WHERE
						temp.winlostdate IS NULL
				GROUP BY 
					rpt.winlostdate
					, rpt.orderkey
					, rpt.transtype
					, rpt.transdesc
			END
		END
		
		-- bet summary - before BalanceUpDay
		IF (@endDate < @BalanceUpDay)  
		BEGIN
			INSERT INTO @statementRpt (orderkey, winlostdate, transtype, transdesc, turnover,TotalAmt,commission, balance)
			SELECT f.orderkey, f.winlostdate, f.transtype, f.transdesc, f.turnover, f.TotalAmt, f.commission, f.balance
			FROM dbo.LAP_f_Statement_Mem_Summary(@CustID, @startDate, @endDate) AS f
				LEFT JOIN @statementRpt temp 
						ON f.winlostdate = temp.winlostdate
						AND temp.transtype	= 'BAL'
			WHERE temp.winlostdate IS NULL
		END
	END

	--------- cancelled/void bet tickets ----------------------------------
	INSERT INTO @statementRpt(OrderKey, winlostdate, transtype, transdesc, TurnOver, TotalAmt, Commission, Balance)
	SELECT 2,   
		winlostdate,
		'BET',
		NULL,
		SUM(stake),
		0,
		0,
		NULL
	FROM bodb02.dbo.zzzbettrans WITH (NOLOCK)
	WHERE
		custid = @CustID   
		AND bettype BETWEEN 1 AND 19999
		AND winlostdate >= @startDate and winlostdate <= @endDate  
		AND bettype NOT IN (903, 913, 914)
		AND ((@IsCOMember = 0 AND bettype <> 912) OR (@IsCOMember = 1 AND bettype <> 911))
	GROUP BY winlostdate   
	-----------------------------------------------------------------------
	
	---------Get Data of PayOutTrans for Progressive Jackpot Win ----------
	INSERT INTO @statementRpt(OrderKey, winlostdate, transtype, transdesc, TurnOver, TotalAmt, Commission)
	SELECT
		4 AS OrderKey,
		winlostdate,
		'GP' AS transtype,
		NULL AS transdesc,
		0,
		SUM (WinAmount) AS TotalAmt,
		0
	FROM DBACC.bodb02.dbo.PayoutTrans WITH (NOLOCK)
	WHERE custid = @custid
		AND winlostdate BETWEEN @startDate AND @endDate
	GROUP BY winlostdate, CustID
	-----------------------------------------------------------------------------

	DECLARE @rowStart		INT
		, @rowEnd			INT
		
		, @fromExRateDate	SMALLDATETIME
		, @toExRateDate		SMALLDATETIME
		, @initBalance		DECIMAL(15,2)
		, @rowCount			INT

    SELECT  @PageIndex		= CASE WHEN @PageIndex > 0 THEN @PageIndex - 1 ELSE 0 END,
            @RowStart		= @PageSize * @PageIndex + 1,
            @RowEnd			= @RowStart + @PageSize - 1
	
	

	

	-- PRE/UPDATE accumulating balance
	INSERT INTO #tempStatementRpt (winlostdate, OrderKey, transtype, transdesc, TurnOver, TotalAmt, Commission, Balance)
	SELECT winlostdate, OrderKey, transtype, transdesc, TurnOver, TotalAmt, Commission, Balance
	FROM @statementRpt
	ORDER BY winlostdate, OrderKey, transtype

	-- ignore the first OPENING BALANCE
	/**SET @rowCount = 1 

	WHILE EXISTS(
		SELECT TOP 1 1 
		FROM #tempStatementRpt rpt WHERE rpt.RowNum > @rowCount 
	)
	BEGIN
		UPDATE TOP(1) rpt
		SET rpt.Balance		= CASE 
								WHEN transtype = 'BAL'	THEN ISNULL(rpt.Balance,0)  
								WHEN transtype = 'GP'	THEN ISNULL(temp.Balance,0)
								WHEN transtype = 'BET' AND OrderKey = 3	THEN ISNULL(temp.Balance,0) - ISNULL(rpt.TurnOver,0)
								ELSE  ISNULL(rpt.TotalAmt,0) + ISNULL(temp.Balance,0) END
			,rpt.TotalAmt	= CASE WHEN transtype = 'BAL' THEN 0  ELSE  ISNULL(rpt.TotalAmt,0) END
		FROM #tempStatementRpt rpt
			OUTER APPLY (
				SELECT top 1 Balance 
				FROM #tempStatementRpt
				WHERE RowNum = rpt.RowNum - 1
			) AS temp
		WHERE rpt.RowNum > @rowCount

		SET @rowCount += 1
	END**/

	-- SET @TotalRows
	SELECT @TotalRows		= COUNT(1)
		,@fromExRateDate	= MIN(winlostdate)
		,@toExRateDate		= MAX(winlostdate)
	FROM #tempStatementRpt rpt


	-- RETURN output result
	;WITH CTE_Exchange AS (
		SELECT CONVERT(DATETIME, FromDate) AS FromDate
			, CONVERT(DATETIME, DATEADD(DAY, 1, ToDate)) AS ToDate
			, Rate 
		FROM dbo.Lrf_f_GetExchangeRate(@fromExRateDate, @toExRateDate, @BaseCurrency, '') AS f
		WHERE f.ExchangeID = @currency
	)
	SELECT 
		rpt.RowNum
		,rpt.winlostdate
		,rpt.transtype
		,ISNULL(rpt.transdesc, dsc.transdesc)	AS transdesc
		,CAST(rpt.turnover * ISNULL(ex.Rate, 1) AS DECIMAL(15,2))	AS Turnover
		,CAST(rpt.TotalAmt * ISNULL(ex.Rate, 1) AS DECIMAL(15,2))	AS TotalAmt
		,CAST(rpt.commission * ISNULL(ex.Rate, 1) AS DECIMAL(15,2))	AS Commission
		--,CAST(rpt.Balance * ISNULL(ex.Rate, 1) AS DECIMAL(15,2))	AS Balance
	FROM #tempStatementRpt rpt
		LEFT JOIN @transDesc dsc 
			ON rpt.OrderKey		= dsc.orderkey 
			AND rpt.transtype	= dsc.transtype
		LEFT JOIN CTE_Exchange ex 
			ON rpt.winlostdate	>= ex.FromDate 
			AND rpt.winlostdate < ex.ToDate
	WHERE 
		rpt.RowNum BETWEEN @RowStart AND @RowEnd

	DROP TABLE #tempStatementRpt
END
GO