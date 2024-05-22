/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[LAP_Rpt_SabaCoins_Performance_ExtraInfo]
	@AgentList		VARCHAR(MAX),
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@UserName		VARCHAR(100)	= NULL
	
AS

/*
	Created: 20240417@Bobby
	Task : 202281 - Saba Coins Integration
	DB: DBACC.bodb02

	Revisions:
		- 20240417@Bobby: Init [RedmineID: #202281]

	Param's Explanation:
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @ProductList	VARCHAR(500);

	-- Get agent list
	DROP TABLE IF EXISTS #sumWinlostExtra
	DROP TABLE IF EXISTS #tmpAg
	DROP TABLE IF EXISTS #sabaBetType;
	DROP TABLE IF EXISTS #shadowRealCust;

	CREATE TABLE #TmpAg (CustId INT, Currency INT)
	CREATE CLUSTERED INDEX IX_TmpAg ON #TmpAg (CustId);

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO #TmpAg (CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SELECT ErrCode = 100,
			ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH;

	--TODO: shadow agent
	CREATE TABLE #shadowRealCust (recommend INT, realCustId INT, shadowAgentId INT, shadowCustId INT);
	WITH CTE_shadowRealCust AS (
		SELECT c.recommend AS shadowAgentId, custid AS shadowCustId, SUBSTRING(c.username2, 11, LEN(username2)) AS realCustId
		FROM dbo.Customer c WITH(NOLOCK)
		WHERE c.username2 LIKE 'sabacoins$%'
			AND c.roleid = 1
			--AND ISNUMERIC(SUBSTRING(c.username2, 11, LEN(username2))) = 1 --exclude dummy cust
	)
	INSERT INTO #shadowRealCust (recommend, realCustId, shadowAgentId, shadowCustId)
	SELECT c.recommend, cte.realCustId, cte.shadowAgentId, cte.shadowCustId
	FROM CTE_shadowRealCust cte
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON c.custid = cte.realCustId
		INNER JOIN #tmpAg a ON a.CustId = c.recommend
	;

	--TODO: filter username if any
	IF LEN(@UserName) > 0
	BEGIN
		WITH CTE_CustSearch AS (
			SELECT c.custid
			FROM dbo.Customer c WITH(NOLOCK) 
			INNER JOIN #shadowRealCust t ON t.realCustId = c.custid
			WHERE c. username = @UserName --- system Id
				OR c. username2 LIKE '%$' + @UserName -- external Id
		)
		DELETE d
		FROM #shadowRealCust d
		LEFT JOIN CTE_CustSearch cs ON cs.custid = d.realCustId
		WHERE cs.custid IS NULL
	END

	--TODO: Get sport type
	CREATE TABLE #sabaBetType (Bettype INT PRIMARY KEY);
	WITH CTE_SabaBettype AS (
		SELECT 11001 AS bettype
		UNION ALL
		SELECT bettype = bettype + 1
		FROM CTE_SabaBettype
		WHERE bettype < 11008
	)
	INSERT INTO #sabaBetType(bettype)
	SELECT bettype
	FROM CTE_SabaBettype;

	CREATE TABLE #SumWinlostExtra (
		ShadowCustId		INT,
		RewardPromotionAmt	MONEY,
		ExchangeAmt			MONEY
	);

	DECLARE @fdate		SMALLDATETIME
		, @tdate		SMALLDATETIME

	IF @ToDate > @MoveBetsDay
	BEGIN
		SELECT @fdate	= IIF(@FromDate >  @MoveBetsDay, @FromDate,DATEADD(DAY, 1 ,@MoveBetsDay))
			,@tdate		= @ToDate;

		INSERT INTO #sumWinlostExtra (shadowCustId, RewardPromotionAmt, ExchangeAmt)
		SELECT b.custid
			, SUM(IIF(b.bettype BETWEEN 11001 AND 11005, b.winlost-b.actual_stake, 0)) AS RewardPromotionAmt
			, SUM(IIF(b.bettype BETWEEN 11006 AND 11008, b.winlost-b.actual_stake, 0)) AS ExchangeAmt
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN #shadowRealCust AS a ON b.recommend = a.shadowAgentId AND b.custid = a.shadowCustId
			INNER JOIN #sabaBetType bt ON bt.bettype = b.bettype
		WHERE b.winlostdate BETWEEN @fdate AND @tdate
		GROUP BY b.custid;
	END

	IF @FromDate <= @MoveBetsDay
	BEGIN
		SELECT @fdate	= @FromDate
			,@tdate		= IIF(@ToDate >  @MoveBetsDay, @MoveBetsDay, @ToDate);

		INSERT INTO #sumWinlostExtra (shadowCustId, RewardPromotionAmt, ExchangeAmt)
		SELECT b.custid
			, SUM(IIF(b.bettype BETWEEN 11001 AND 11005, b.winlost, 0)) AS RewardPromotionAmt
			, SUM(IIF(b.bettype BETWEEN 11006 AND 11008, b.winlost, 0)) AS ExchangeAmt
		FROM bodb_LicenseeReport.dbo.rptLicenseeWinloss AS b WITH (NOLOCK)
			INNER JOIN #shadowRealCust AS a ON b.recommend = a.shadowAgentId AND b.custid = a.shadowCustId
			INNER JOIN #sabaBetType bt ON bt.bettype = b.bettype
		WHERE b.winlostdate BETWEEN @fdate AND @tdate
		GROUP BY b.CustId;
	END


	SELECT t.realCustId AS custid
		, SUM(rpt.RewardPromotionAmt) AS	RewardPromotionAmt
		, SUM(rpt.ExchangeAmt) AS			ExchangeAmt
	FROM #sumWinlostExtra rpt
		INNER JOIN #shadowRealCust t ON t.shadowCustId = rpt.ShadowCustId
	GROUP BY t.realCustId
END
GO
