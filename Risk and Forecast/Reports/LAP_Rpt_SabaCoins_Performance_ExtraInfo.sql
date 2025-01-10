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
		- 20240710@Bobby: Enhance perf [RedmineID: #207858]
		- 20240808@Kelvin: Add new bettype 11009 for "Saba Nickname Edited" - change bettype range [11001 -> 11049] [RedmineID: #209038]
		- 20241227@Kelvin: LAP - Saba Coins phase 2 - Support multiple wallets [RedmineID: #215890]

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

	--TODO: shadow vs real member
	--==============================================================================================================================	
	CREATE TABLE #tmpRealCust (realCustId INT, recommend INT, username VARCHAR(30), username2 VARCHAR(50), SabaID BIGINT)

	--Get list RealCust -target index=IX_agent nonclustered
	INSERT INTO #tmpRealCust (realCustId, recommend, username, username2, SabaID)
	SELECT c.custid, c.recommend, c.username, c.username2, d.SabaID
	FROM dbo.Customer c WITH(NOLOCK)
		INNER JOIN dbo.Dep_CustSabaInfo d WITH(NOLOCK) ON d.CustID = c.custid
		INNER JOIN #tmpAg a ON a.CustId = c.recommend
	WHERE c.roleid = 1 AND d.CustType = 0 --Real member

	--TODO: filter username if any
	IF LEN(@UserName) > 0
	BEGIN
		WITH CTE_CustSearch AS (
			SELECT t.realCustId
			FROM #tmpRealCust t
			WHERE t.username = @UserName --- system Id
				OR t.username2 LIKE '%$' + @UserName -- external Id
		)
		DELETE d
		FROM #tmpRealCust d
			LEFT JOIN CTE_CustSearch cs ON cs.realCustId = d.realCustId
		WHERE cs.realCustId IS NULL
	END

	--Get list ShadowCust
	CREATE TABLE #tmpShadowCust (shadowCustId INT PRIMARY KEY, SabaID BIGINT)

	;WITH CTE_SabaID AS
		(SELECT DISTINCT SabaID FROM #tmpRealCust)
	INSERT INTO #tmpShadowCust(shadowCustId, SabaID)
	SELECT s.CustID AS shadowCustId, s.SabaID
	FROM dbo.Dep_CustSabaInfo s WITH(NOLOCK)
		INNER JOIN CTE_SabaID cte ON cte.SabaID = s.SabaID
	WHERE s.CustType = 1 --Shadow member
	--==============================================================================================================================

	--TODO: Get sport type	
	CREATE TABLE #sabaBetType (Bettype INT PRIMARY KEY, AmountType SMALLINT);
	WITH CTE_SabaBettype AS (
		SELECT 11001 AS bettype 
		UNION ALL
		SELECT bettype = bettype + 1
		FROM CTE_SabaBettype
		WHERE bettype < 11049
	)
	INSERT INTO #sabaBetType(bettype, AmountType)
	SELECT bettype
		  ,CASE WHEN bettype IN (11006,11007,11008) THEN 1 ELSE 0 END AS AmountType -- 0: Reward/Promotion,  1: Exchange To Cash
	FROM CTE_SabaBettype;

	CREATE TABLE #SumWinlostExtra (
		SabaID				BIGINT,
		RewardPromotionAmt	MONEY,
		ExchangeAmt			MONEY
	);

	DECLARE @fdate		SMALLDATETIME
		, @tdate		SMALLDATETIME

	IF @ToDate > @MoveBetsDay
	BEGIN
		SELECT @fdate	= IIF(@FromDate >  @MoveBetsDay, @FromDate,DATEADD(DAY, 1 ,@MoveBetsDay))
			,@tdate		= @ToDate;

		INSERT INTO #sumWinlostExtra (SabaID, RewardPromotionAmt, ExchangeAmt)
		SELECT a.SabaID
			, SUM(IIF(bt.AmountType = 0, b.winlost-b.actual_stake, 0)) AS RewardPromotionAmt
			, SUM(IIF(bt.AmountType = 1, b.winlost-b.actual_stake, 0)) AS ExchangeAmt
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN #tmpShadowCust AS a ON b.custid = a.shadowCustId
			INNER JOIN #sabaBetType bt ON bt.bettype = b.bettype
		WHERE b.winlostdate BETWEEN @fdate AND @tdate
		GROUP BY a.SabaID;
	END

	IF @FromDate <= @MoveBetsDay
	BEGIN
		SELECT @fdate	= @FromDate
			,@tdate		= IIF(@ToDate >  @MoveBetsDay, @MoveBetsDay, @ToDate);

		INSERT INTO #sumWinlostExtra (SabaID, RewardPromotionAmt, ExchangeAmt)
		SELECT a.SabaID
			, SUM(IIF(bt.AmountType = 0, b.winlost, 0)) AS RewardPromotionAmt
			, SUM(IIF(bt.AmountType = 1, b.winlost, 0)) AS ExchangeAmt
		FROM bodb_LicenseeReport.dbo.rptLicenseeWinloss AS b WITH (NOLOCK)
			INNER JOIN #tmpShadowCust AS a ON b.custid = a.shadowCustId
			INNER JOIN #sabaBetType bt ON bt.bettype = b.bettype
		WHERE b.winlostdate BETWEEN @fdate AND @tdate
		GROUP BY a.SabaID;
	END

	--TODO: output
	SELECT t.SabaID
		, t.realCustId AS custid
		, SUM(rpt.RewardPromotionAmt) AS	RewardPromotionAmt
		, SUM(rpt.ExchangeAmt) AS			ExchangeAmt
	FROM #sumWinlostExtra rpt
		INNER JOIN #tmpRealCust t ON t.SabaID = rpt.SabaID
	GROUP BY t.SabaID, t.realCustId
END
GO
