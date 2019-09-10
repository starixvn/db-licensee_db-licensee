/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet,bodbDownlineNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[LAP_Statement_Mem_Product]  
    @CustID			INT,  
    @Winlostdate	SMALLDATETIME,  
    @MoveBetsDay	SMALLDATETIME,  
	@BalanceUpDay	SMALLDATETIME,  
    @BaseCurrency	VARCHAR(3) = '',
	@ModeView		TINYINT = 1 
AS
/*
Created:Bobby@20190904   
Task : 119648 - LAP - Implement Statement Service - Level 2
DB: DBACC/bodb02

Revisions:  
	- 20190904@Bobby: Implement Statement Service - Level 2 [RedmineID: #119648]

Param's Explanation:     
	- @ModeView: TINYINT
		+ 1 - Bet_Statement
		+ 2 - Void_Cancelled_Bet
		+ 3 - Outstanding_Bet
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @_winlostdate			SMALLDATETIME
		, @_custID					INT
		, @_recommend				INT
		, @_ModeView				TINYINT
		, @isCOMember				BIT --Cash Out member
		, @currency					INT 
		, @modeDesc					VARCHAR(100)
		, @CB_ProductID				INT
		, @IsTest					BIT = 0


	CREATE TABLE #betTicket	  
    (
		bettype			INT,
        turnover		MONEY DEFAULT(0),
        winlost			MONEY DEFAULT(0),
        playercomm		MONEY DEFAULT(0)
    )

	CREATE TABLE #statementRpt (
		winlostdate		SMALLDATETIME,
		productid		INT,
        turnover		DECIMAL(15,2),
        totalamt		DECIMAL(15,2),
        commission		DECIMAL(15,2)
	)

	SELECT TOP(1) @currency	= currency, @_recommend = recommend
	FROM dbo.custinfo WITH(NOLOCK) 
	WHERE custid = @custid  
	
	SELECT TOP 1 @isCOMember = 1
	FROM dbo.TradeCust WITH(NOLOCK)
	WHERE custid = @_custID
		AND VendorID = 14

	SELECT @_custID		= @CustID
		, @_winlostdate	= @Winlostdate
		, @_ModeView	= ISNULL(@ModeView, 1)
		, @CB_ProductID	= 15
		, @modeDesc		= CASE @_ModeView 
							WHEN 1 THEN 'Bet_Statement'
							WHEN 2 THEN 'Void_Cancelled_Bet'
							WHEN 3 THEN 'Outstanding_Bet'
						END
		, @IsTest		= dbo.f_CheckSPVersion(@@PROCID)
		, @IsCOMember    = ISNULL(@IsCOMember,0)

	-- validate time range & custid
	IF (@_custID IS NULL
		OR @_winlostdate IS NULL
		OR @currency IS NULL)
	BEGIN
		SELECT @_winlostdate AS Winlostdate
			,'' AS ProductCode
			,'' AS transdesc
			,TurnOver,TotalAmt,Commission
		FROM #statementRpt
		RETURN
	END

	--------- bettrans settled/outstanding/void/reject bet tickets -----------------------------
	IF (@_ModeView IN (1,2,3) AND @_winlostdate > @MoveBetsDay)
	BEGIN
		-- bet tickets
		INSERT INTO #betTicket(bettype, turnover, winlost, playercomm)
		SELECT 
			b.bettype,
			SUM(CASE 
				WHEN b.bettype IN (33, 43) AND b.liveawayscore = 0 AND b.livehomescore <> 0 AND b.ruben = 1 THEN b.stake/2 
				WHEN b.statusID IN (0,1) THEN ABS(b.actual_stake)
				ELSE b.stake END
			) AS turnover,  
			SUM(CASE WHEN b.statusID IN (0,1) THEN 0 ELSE b.winlost-b.actual_stake END) AS winlost,
			SUM(b.playercomm) AS playercomm
		FROM 
			bodb02.dbo.bettrans b WITH (NOLOCK)

		WHERE
			b.custid = @_custID  
			AND b.winlostdate = @_winlostdate
			AND b.bettype < 19999 -- bet tickets 
			AND b.bettype NOT IN (903, 71, 913, 914)
			AND ((ISNULL(@IsCOMember,0) = 0 AND b.bettype <> 912) OR (@IsCOMember = 1 AND b.bettype <> 911))
			AND 1 = CASE 
						WHEN @_ModeView = 1 AND b.statusID IN (111,112,113) THEN 1 
						WHEN @_ModeView = 2 AND b.statusID IN (101,102,103) THEN 1 
						WHEN @_ModeView = 3 AND b.statusID IN (0,1) THEN 1 
					ELSE 0 END
		GROUP BY
			b.bettype
			
		--include running Keno bet
		INSERT INTO #betTicket(bettype, turnover)
		SELECT
			b.gameid,
			SUM(actual_stake)
		FROM bodb02.dbo.translog b WITH (NOLOCK)
		WHERE
			statusID IN (0,1) -- get only running game _ Keno
			AND custid = @_custID  
			AND winlostdate = @_winlostdate
			AND @_ModeView = 3

		GROUP BY gameID
		
		--include running Microgaming + RNG Casino + Voidbridge
		INSERT INTO #betTicket(bettype, turnover)
		SELECT
			gameid,
			SUM(actual_stake)
		FROM bodb02.dbo.bettransRnG WITH (NOLOCK)
		WHERE
			custid = @_custid  
			AND winlostdate = @_winlostdate
			AND statusID = 0 -- get only running game _ bettransRnG
			AND @_ModeView = 3

		GROUP BY 
			gameID
		
		-- get only running game _ bettransRnG
		INSERT INTO #betTicket(bettype, turnover)
		SELECT
			gameid,
			SUM(actual_stake)
		FROM bodb02.dbo.bettransLC WITH (NOLOCK)
		WHERE
			recommend = @_recommend
			AND winlostdate = @_winlostdate
			AND custid = @_custID  
			AND statusID = 0 
			AND @_ModeView = 3

		GROUP BY 
			gameID
	END
	
	--------- bettrans14 settled/reject/void/refund bet tickets --------------------------------
	IF (@_ModeView IN (1,2) AND @_winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay)
	BEGIN
		INSERT INTO #betTicket(bettype, turnover, winlost, playercomm)
		SELECT 
			b.bettype,
			SUM(b.stake) AS turnover,  
			SUM(b.winlost - b.actual_stake) AS winlost,
			SUM(b.playercomm) AS playercomm
		FROM
			bodb02.dbo.bettrans14 b WITH (NOLOCK)

		WHERE 
			b.custid = @_custid  
			AND b.winlostdate = @_winlostdate
			AND b.bettype NOT IN (903, 71, 913, 914)
			AND ((@IsCOMember = 0 AND b.bettype <> 912) OR (@IsCOMember = 1 AND b.bettype <> 911))
			AND 1 = CASE 
						WHEN @_ModeView = 1 AND b.statusID IN (111,112,113) THEN 1 
						WHEN @_ModeView = 2 AND b.statusID IN (101,102,103) THEN 1 
					ELSE 0 END

		GROUP BY b.bettype
	END
	
	--------- bettrans_bk settled/reject/void/refund bet tickets -------------------------------
	IF (@_ModeView IN (1,2) AND @_winlostdate < @BalanceUpDay)
	BEGIN
		INSERT INTO #betTicket(bettype, turnover, winlost, playercomm)
		SELECT 
			b.bettype,
			SUM(b.stake) AS turnover,  
			SUM(b.winlost - b.actual_stake) AS winlost,
			SUM(b.playercomm) AS playercomm
		FROM
			bodb_archive.dbo.bettrans_bk b WITH (NOLOCK)

		WHERE 
			b.custid = @_custid  
			AND b.winlostdate = @_winlostdate
			AND b.bettype NOT IN (903, 71, 913, 914)
			AND ((@IsCOMember = 0 AND b.bettype <> 912) OR (@IsCOMember = 1 AND b.bettype <> 911))
			AND 1 = CASE 
						WHEN @_ModeView = 1 AND b.statusID IN (111,112,113) THEN 1 
						WHEN @_ModeView = 2 AND b.statusID IN (101,102,103) THEN 1 
					ELSE 0 END

		GROUP BY b.bettype

		
	END;

	WITH CTE_SportProduct AS (
		SELECT sp.productId, sp.bettype
		FROM [dbo].[f_SportBettypeMatrix_Sel] (0, 0, 0, 2, '','',@IsTest) AS sp
	)
	INSERT INTO #statementRpt(ProductID, Winlostdate, Turnover, TotalAmt, Commission)
	SELECT s.ProductID
		, @_winlostdate		AS Winlostdate
		, SUM(turnover)		AS turnover
		, SUM(winlost)		AS TotalAmt
		, SUM(playercomm)	AS Commission
	FROM #betTicket b
		INNER JOIN CTE_SportProduct s ON b.bettype = s.bettype

	GROUP BY s.productId

	---------Get Data of PayOutTrans for Progressive Jackpot Win ----------
	UNION
	SELECT @CB_ProductID AS ProductCode
		, @_winlostdate AS Winlostdate
		, 0
		, SUM(WinAmount) AS TotalAmt
		, 0
	FROM bodb02.dbo.PayoutTrans WITH (NOLOCK)
	WHERE custid = @_custid
		AND winlostdate = @_winlostdate
		AND @_ModeView = 1
	HAVING SUM(WinAmount) <> 0


	-- RETURN output result
	;WITH CTE_Exchange AS (
		SELECT CONVERT(DATETIME, FromDate) AS FromDate
			, CONVERT(DATETIME, DATEADD(DAY, 1, ToDate)) AS ToDate
			, Rate 
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@_winlostdate, @_winlostdate, @BaseCurrency, '') AS f
		WHERE f.ExchangeID = @currency
	)
	SELECT rpt.winlostdate
		,p.ProductPrefix AS productcode
		,@modeDesc AS transdesc
		,CAST(rpt.turnover * ISNULL(ex.Rate, 1) AS DECIMAL(15,2))	AS turnover
		,CAST(rpt.TotalAmt * ISNULL(ex.Rate, 1) AS DECIMAL(15,2))	AS totalamt
		,CAST(rpt.commission * ISNULL(ex.Rate, 1) AS DECIMAL(15,2))	AS commission

	FROM 
		#statementRpt rpt
	INNER JOIN dbo.Products p WITH (NOLOCK) 
		ON rpt.ProductID = p.ProductID
	LEFT JOIN CTE_Exchange ex 
		ON rpt.winlostdate	>= ex.FromDate 
		AND rpt.winlostdate < ex.ToDate
	ORDER BY 
		rpt.ProductID

	DROP TABLE #statementRpt
END
GO