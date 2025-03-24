/*<info serverAlias="DBACC-bodb02" executers="wsv_lap" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LAP_Statement_Mem_Product]
	@CustId			INT,
	@WinLostDate	SMALLDATETIME,
    @ReportViewType	TINYINT	= 1,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@BaseCurrency	VARCHAR(12)		= '',
	@ModeView		TINYINT			= 1 
AS

/*
	Created: Bobby@20190904
	Task: 119648 - LAP - Implement Statement Service - Level 2
	DB: DBACC/bodb02

	Revisions:
		- 20190904@Bobby: Implement Statement Service - Level 2 [RedmineID: #119648]
		- 20190926@Bobby: Enhance Statement Level 1 - show outstanding for future [RedmineID: #120690] 
		- 20191003@Bobby: Integrate NPH Promotion product [RedmineID: #120333]
		- 20200803@Sophia: add Saba Loyalty [Redmine: #138493]
		- 20201001@Louis: Licensee Spread Setting [RedmineID: #142532]
		- 20210111@Kos: Hotfix - not showing Saba Promotion [RedmineID: #148567]
		- 20210203@Louis: Saba Red Envelope [RedmineID: #149923]
		- 20211109@Kos: Merge Sports Lottery into Sportsbook [RedmineID: #163191]
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]
		- 20231018@Evan: Integrate Saba Reward Risk-free Rebate + add missing bettype 17006 [redmine: #196881]
		- 20241701@Evan: Merge VS, VS2, VS3 as VS only [RedmineID: #199523]
		- 20240416@Evan: Integrate Saba Coins - add param @ReportViewType [RedmineID: #202281]
		- 20240808@Kelvin: Add new bettype 11009 for "Saba Nickname Edited" - change bettype range [11001 -> 11049] [RedmineID: #209038]
		- 20240910@Kelvin: Integrate Odds Boost Voucher [RedmineID: #210613]
		- 20250314@Kelvin: Integrate Saba Promotion - Number Game Lucky Draw Promotion [RedmineID: #219835]

	Param's Explanation:
		- @ModeView: TINYINT
			+ 1 - Bet_Statement
			+ 2 - Void_Cancelled_Bet
			+ 3 - Outstanding_Bet
			+ 4 - Promotion_Prize
  		- @ReportViewType : TINYINT
  			+ 1 - Main Wallet
  			+ 2 - Saba coins 
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @_winlostdate	SMALLDATETIME
		, @_custID			INT
		, @_recommend		INT
		, @_ModeView		TINYINT
		, @isCOMember		BIT --Cash Out member
		, @currency			INT
		, @modeDesc			VARCHAR(100)
		, @CB_ProductID		INT
		, @IsTest			BIT = 0

	CREATE TABLE #BetTicket
	(
		BetType		INT,
		Turnover	MONEY DEFAULT(0),
		WinLost		MONEY DEFAULT(0),
		PlayerComm	MONEY DEFAULT(0)
	)

	CREATE TABLE #StatementRpt (
		WinLostDate	SMALLDATETIME,
		ProductId	INT,
		Turnover	DECIMAL(15,2),
		TotalAmt	DECIMAL(15,2),
		Commission	DECIMAL(15,2)
	)

	DECLARE @PROMO_BETTPE TABLE  
    (  
		betTypeId		SMALLINT
    )
    
    INSERT INTO @PROMO_BETTPE (betTypeId)
	SELECT b.typeid FROM bettype b WITH(NOLOCK) 
	WHERE b.typeid BETWEEN 17000 AND 17099
		OR b.typeid BETWEEN 11001 AND 11049

	SELECT @_custID		= @CustID
		, @_winlostdate	= @WinLostDate
		, @_ModeView	= ISNULL(@ModeView, 1)

	IF @ReportViewType = 2
	BEGIN
		SELECT @_CustID = c.custid
		FROM Customer c WITH(NOLOCK)
		WHERE c.username2 = 'sabacoins$' + CAST(@_CustID AS VARCHAR(10))
	END

	SELECT TOP(1) @currency	= currency, @_recommend = recommend
	FROM dbo.custinfo WITH(NOLOCK)
	WHERE custid = @_custID
	
	SELECT TOP 1 @isCOMember = 1
	FROM dbo.TradeCust WITH(NOLOCK)
	WHERE custid = @_custID
		AND VendorID = 14

	SELECT @CB_ProductID	= 15
		, @modeDesc		= CASE @_ModeView
							WHEN 1 THEN 'Bet_Statement'
							WHEN 2 THEN 'Void_Cancelled_Bet'
							WHEN 3 THEN 'Outstanding_Bet'
							WHEN 4 THEN 'Promotion_Prize'
						END
		, @IsTest			= dbo.f_CheckSPVersion(@@PROCID)
		, @IsCOMember		= ISNULL(@IsCOMember,0)

	-- validate time range & custid
	IF (@_custID IS NULL
		OR @_winlostdate IS NULL
		OR @currency IS NULL)
	BEGIN
		RETURN
	END

	-- bettrans settled/outstanding/void/reject bet tickets
	IF @_ModeView IN (1,2,3,4) AND @_winlostdate > @MoveBetsDay
	BEGIN
		-- bet tickets
		INSERT INTO #BetTicket(BetType, Turnover, WinLost, PlayerComm)
		SELECT
			b.bettype,
			SUM(CASE
				WHEN b.statusID IN (0, 1) THEN ABS(b.actual_stake)
				ELSE b.stake END
			) AS turnover,
			SUM(CASE WHEN b.statusID IN (0, 1) THEN 0 ELSE b.winlost - b.actual_stake END) AS winlost,
			SUM(b.playercomm) AS playercomm
		FROM dbo.bettrans b WITH (NOLOCK)
			LEFT JOIN @PROMO_BETTPE pb ON pb.betTypeId = b.bettype
		WHERE
			b.custid = @_custID
			AND b.winlostdate = @_winlostdate
			AND b.bettype NOT IN (903, 71, 913, 914, 999, 997)
			AND ((ISNULL(@IsCOMember, 0) = 0 AND b.bettype <> 912) OR (@IsCOMember = 1 AND b.bettype <> 911))
			AND 1 = CASE
						WHEN @_ModeView = 1 AND b.statusID IN (111, 112, 113) AND pb.betTypeId IS NULL THEN 1
						WHEN @_ModeView = 2 AND b.statusID IN (101, 102, 103) AND pb.betTypeId IS NULL THEN 1
						WHEN @_ModeView = 3 AND b.statusID IN (0, 1) THEN 1
						WHEN @_ModeView = 4 AND pb.betTypeId IS NOT NULL THEN 1
						ELSE 0
					END
		GROUP BY b.bettype

		--include running Keno bet
		INSERT INTO #BetTicket(BetType, Turnover)
		SELECT
			gameid,
			SUM(actual_stake)
		FROM dbo.translog WITH (NOLOCK)
		WHERE
			statusID IN (0,1) -- get only running game _ Keno
			AND custid = @_custID
			AND winlostdate = @_winlostdate
			AND @_ModeView = 3
		GROUP BY gameID

		--include running Microgaming + RNG Casino + Voidbridge
		INSERT INTO #BetTicket(BetType, Turnover)
		SELECT
			gameid,
			SUM(actual_stake)
		FROM dbo.bettransRnG WITH (NOLOCK)
		WHERE
			custid = @_custid
			AND winlostdate = @_winlostdate
			AND statusID = 0 -- get only running game _ bettransRnG
			AND @_ModeView = 3
		GROUP BY gameID

		-- get only running game _ bettransRnG
		INSERT INTO #BetTicket(BetType, Turnover)
		SELECT
			gameid,
			SUM(actual_stake)
		FROM dbo.bettransLC WITH (NOLOCK)
		WHERE
			recommend = @_recommend
			AND winlostdate = @_winlostdate
			AND custid = @_custID
			AND statusID = 0
			AND @_ModeView = 3
		GROUP BY gameID
	END

	-- bettrans14 settled/reject/void/refund bet tickets
	IF @_ModeView IN (1, 2, 4) AND @_winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
	BEGIN
		INSERT INTO #BetTicket(BetType, Turnover, WinLost, PlayerComm)
		SELECT
			b.bettype,
			SUM(b.stake) AS turnover,
			SUM(b.winlost - b.actual_stake) AS winlost,
			SUM(b.playercomm) AS playercomm
		FROM dbo.bettrans14 b WITH (NOLOCK)
			LEFT JOIN @PROMO_BETTPE pb ON pb.betTypeId = b.bettype
		WHERE
			b.custid = @_custid
			AND b.winlostdate = @_winlostdate
			AND b.bettype NOT IN (903, 71, 913, 914, 999, 997)
			AND ((@IsCOMember = 0 AND b.bettype <> 912) OR (@IsCOMember = 1 AND b.bettype <> 911))
			AND 1 = CASE
						WHEN @_ModeView = 1 AND b.statusID IN (111,112,113) AND pb.betTypeId IS NULL THEN 1
						WHEN @_ModeView = 2 AND b.statusID IN (101,102,103) AND pb.betTypeId IS NULL THEN 1
						WHEN @_ModeView = 4 AND pb.betTypeId IS NOT NULL THEN 1
						ELSE 0
					END
		GROUP BY b.bettype
	END

	--------- bettrans_bk settled/reject/void/refund bet tickets -------------------------------
	IF @_ModeView IN (1,2,4) AND @_winlostdate < @BalanceUpDay
	BEGIN
		INSERT INTO #BetTicket(BetType, Turnover, WinLost, PlayerComm)
		SELECT
			b.bettype,
			SUM(b.stake) AS turnover,
			SUM(b.winlost - b.actual_stake) AS winlost,
			SUM(b.playercomm) AS playercomm
		FROM
			bodb_archive.dbo.bettrans_bk b WITH (NOLOCK)
			LEFT JOIN @PROMO_BETTPE pb ON pb.betTypeId = b.bettype
		WHERE 
			b.custid = @_custid
			AND b.winlostdate = @_winlostdate
			AND b.bettype NOT IN (903, 71, 913, 914, 999, 997)
			AND ((@IsCOMember = 0 AND b.bettype <> 912) OR (@IsCOMember = 1 AND b.bettype <> 911))
			AND 1 = CASE
						WHEN @_ModeView = 1 AND b.statusID IN (111,112,113) AND pb.betTypeId IS NULL THEN 1
						WHEN @_ModeView = 2 AND b.statusID IN (101,102,103) AND pb.betTypeId IS NULL THEN 1
						WHEN @_ModeView = 4 AND pb.betTypeId IS NOT NULL THEN 1
						ELSE 0
					END
		GROUP BY b.bettype
	END;

	-- Group products under SB
	DECLARE @SBProductCode VARCHAR(100)

	SET @SBProductCode = dbo.Lrf_f_GroupProductCode('SB');

	WITH CTE_SportProduct AS (
		SELECT
			CASE
				WHEN ',' + @SBProductCode + ',' LIKE '%,' + ProductPrefix + ',%' THEN 1
				ELSE productId
			END AS ProductId,
			BetType
		FROM [dbo].[f_SportBettypeMatrix_Sel] (0, 0, 0, 2, '','',@IsTest)
	)
	INSERT INTO #StatementRpt(ProductId, WinLostDate, Turnover, TotalAmt, Commission)
	SELECT ISNULL(lf.GroupProductId, s.ProductID) AS ProductID
		, @_winlostdate		AS WinLostDate
		, SUM(b.Turnover)	AS Turnover
		, SUM(b.WinLost)	AS TotalAmt
		, SUM(b.PlayerComm)	AS Commission
	FROM #BetTicket AS b
		INNER JOIN CTE_SportProduct AS s ON b.bettype = s.bettype
		LEFT JOIN dbo.Lrf_f_GroupProduct() lf ON s.ProductId = lf.ProductId
	GROUP BY ISNULL(lf.GroupProductId, s.ProductID)

	-- Get Data of PayOutTrans for Progressive Jackpot Win
	UNION
	SELECT @CB_ProductID AS ProductCode
		, @_winlostdate AS Winlostdate
		, 0
		, SUM(WinAmount) AS TotalAmt
		, 0
	FROM dbo.PayoutTrans WITH (NOLOCK)
	WHERE CustId = @_custid
		AND WinlostDate = @_winlostdate
		AND @_ModeView = 1
	HAVING SUM(WinAmount) <> 0

	-- Check exrate for future
	DECLARE @currentDate	SMALLDATETIME
		, @fromExRateDate	SMALLDATETIME
		, @toExRateDate		SMALLDATETIME

	SELECT @currentDate		= CAST(CURRENT_TIMESTAMP AS DATE)
		,@fromExRateDate	= CASE WHEN @_winlostdate > @currentDate THEN @currentDate ELSE @_winlostdate END
		,@toExRateDate		= @_winlostdate

	-- RETURN output result
	;WITH CTE_Exchange AS (
		SELECT f.FromDate
			, DATEADD(DAY, 1, f.ToDate) AS ToDate
			, Rate
		FROM dbo.Lrf_f_GetExchangeRate(@fromExRateDate, @toExRateDate, @BaseCurrency, '') AS f
		WHERE f.ExchangeID = @currency
	)
	SELECT rpt.winlostdate
		, p.ProductPrefix AS ProductCode
		, @modeDesc AS Transdesc
		, CAST(rpt.turnover * ISNULL(ex.Rate, fex.Rate) AS DECIMAL(15, 2))		AS Turnover
		, CAST(rpt.TotalAmt * ISNULL(ex.Rate, fex.Rate) AS DECIMAL(15, 2))		AS TotalAmt
		, CAST(rpt.commission * ISNULL(ex.Rate, fex.Rate) AS DECIMAL(15, 2))	AS Commission
	FROM
		#StatementRpt AS rpt
		INNER JOIN dbo.Products AS p WITH (NOLOCK) ON rpt.ProductID = p.ProductID
		LEFT JOIN CTE_Exchange AS ex ON rpt.winlostdate >= ex.FromDate AND rpt.winlostdate < ex.ToDate
		OUTER APPLY (
			-- future rate usage
			SELECT Rate
			FROM CTE_Exchange AS ex
			WHERE ex.ToDate IN (SELECT MAX(ToDate) FROM CTE_Exchange)
		) AS fex
	ORDER BY rpt.ProductId

	DROP TABLE #StatementRpt
	DROP TABLE #BetTicket
END
GO