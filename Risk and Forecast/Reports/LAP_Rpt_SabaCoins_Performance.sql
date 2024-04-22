/*<info serverAlias="DBACC-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[LAP_Rpt_SabaCoins_Performance]
	@AgentList		VARCHAR(MAX),
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
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

	DECLARE @productCheck	VARCHAR(500);

	-- Get agent list
	DROP TABLE IF EXISTS #sumWinlost
	DROP TABLE IF EXISTS #tmpAg
	DROP TABLE IF EXISTS #shadowRealCust;

	CREATE TABLE #tmpAg (CustId INT, Currency INT)
	CREATE CLUSTERED INDEX IX_TmpAg ON #tmpAg (CustId);

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO #tmpAg (CustId, Currency)
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

	CREATE TABLE #sumWinlost (
		ShadowCustId		INT,
		OpeningBalance		MONEY,
		Turnover			MONEY,
		Outstanding			MONEY,
		WinLoss				MONEY,
		ClosingBalance		MONEY
		--,UNIQUE CLUSTERED (ShadowCustId)
	);

	DECLARE @CutDate	DATETIME
		, @tmpdate		SMALLDATETIME
		, @fdate		SMALLDATETIME
		, @tdate		SMALLDATETIME

	SELECT @CutDate = MIN(winlostdate)
		, @fdate	= @FromDate
		, @tdate	= @ToDate
	FROM bodb_report.dbo.rptdepwinlost WITH (NOLOCK)

	--TODO: rptDepWinlost data range
	IF @tdate >= @CutDate
	BEGIN
		SELECT @tmpdate = IIF(@fdate > @CutDate, @fdate, @CutDate);

		INSERT INTO #sumWinlost (shadowCustId, OpeningBalance, ClosingBalance)
		SELECT b.custid
			, SUM(CASE b.winlostdate
					WHEN @fdate THEN b.OpeningBalance
					ELSE 0
				END) AS OpeningBalance
			, SUM(CASE b.winlostdate
					WHEN @tdate THEN b.ClosingBalance
					ELSE 0
				END) AS ClosingBalance
		FROM bodb_Report.dbo.rptDepWinlost AS b WITH (NOLOCK)
			INNER JOIN #shadowRealCust AS a ON b.recommend = a.shadowAgentId AND b.custid = a.shadowCustId
		WHERE b.winlostdate BETWEEN @tmpdate AND @tdate
		GROUP BY b.CustId;

		-- detail sum WL
		INSERT INTO #sumWinlost (shadowCustId, Turnover, Outstanding, winloss)
		SELECT p.custid
			, SUM(ISNULL(CASE
							WHEN p.sporttype IN (-2, -3, -5, -6, -7) THEN 0
							ELSE p.turnover
						END, 0)) AS Turnover
			, SUM(ISNULL(p.outstanding, 0)) AS outstanding
			, SUM(ISNULL(p.winlost, 0)) AS Winloss
		FROM bodb_Report.dbo.rptDepWinlostByProduct p WITH (NOLOCK)
			INNER JOIN #shadowRealCust AS a ON p.custid = a.shadowCustId
		WHERE p.winlostdate BETWEEN @tmpdate AND @tdate
		GROUP BY p.custid
		
	END

	--TODO: rptDepWinlost_bk data range
	IF @fdate < @CutDate
	BEGIN
		SELECT @tmpdate = IIF(@tdate < @CutDate, @tdate, DATEADD(DD, -1, @CutDate));

		INSERT INTO #sumWinlost (shadowCustId, OpeningBalance, ClosingBalance)
		SELECT b.custid
			, SUM(CASE b.winlostdate
					WHEN @fdate THEN b.OpeningBalance
					ELSE 0
				END) AS OpeningBalance
			, SUM(CASE b.winlostdate
					WHEN @tdate THEN b.ClosingBalance
					ELSE 0
				END) AS ClosingBalance
			
		FROM bodb_Report.dbo.rptDepWinlost_bk AS b WITH (NOLOCK)
			INNER JOIN #shadowRealCust AS a ON b.recommend = a.shadowAgentId AND b.custid = a.shadowCustId
		WHERE b.winlostdate BETWEEN @fdate AND @tmpdate
		GROUP BY b.custid;

		--detail sum WL
		INSERT INTO #sumWinlost (shadowCustId, Turnover, Outstanding, winloss)
		SELECT p.custid
			, SUM(ISNULL(CASE 
							WHEN p.sporttype IN (-2, -3, -5, -6, -7) THEN 0
							ELSE p.turnover
						END, 0)) AS Turnover
			, SUM(ISNULL(p.outstanding, 0)) AS outstanding
			, SUM(ISNULL(p.winlost, 0)) AS Winloss
		FROM bodb_Report.dbo.rptDepWinlostByProduct_bk AS p WITH (NOLOCK)
			INNER JOIN #shadowRealCust AS a ON p.custid = a.shadowCustId
		WHERE p.winlostdate BETWEEN @fdate AND @tmpdate
		GROUP BY p.custid
	END

	--TODO: output result
	SELECT t.realCustId AS custId, c.username
		, SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS nickname
		, SUM(ISNULL(rpt.OpeningBalance, 0)) AS OpeningBalance
		, SUM(ISNULL(rpt.Turnover, 0)) AS Turnover
		, SUM(ISNULL(rpt.Outstanding, 0)) AS Outstanding
		, SUM(ISNULL(rpt.WinLoss, 0)) AS WinLoss
		, SUM(ISNULL(rpt.ClosingBalance, 0)) AS ClosingBalance
	FROM #sumWinlost rpt
		INNER JOIN #shadowRealCust t ON t.shadowCustId = rpt.ShadowCustId
		INNER JOIN dbo.Customer c WITH (NOLOCK) ON c.custid = t.realCustId	
	GROUP BY t.realCustId, c.username
		, SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2))
END
GO
