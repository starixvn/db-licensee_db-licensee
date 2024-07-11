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
		- 20240710@Bobby: Enhance perf [RedmineID: #207858]

	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

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

	--TODO: shadow vs real member
	DROP TABLE IF EXISTS #tmpShadowCust;
	CREATE TABLE #shadowRealCust (recommend INT, realCustId INT, shadowCustId INT PRIMARY KEY, username VARCHAR(30), username2 VARCHAR(50));

	SELECT custid AS shadowCustId, CONVERT(INT, SUBSTRING(c.username2, 11, LEN(username2))) AS realCustId
	INTO #tmpShadowCust
	FROM dbo.Customer c WITH(NOLOCK)
	WHERE c.username2 LIKE 'sabacoins$%';

	--TODO: filter owner Licensee -- target index=IX_custid clustered
	INSERT INTO #shadowRealCust (recommend, realCustId, shadowCustId, username, username2)
	SELECT c.recommend, c.custid, tmp.shadowCustId, c.username, c.username2
	FROM dbo.Customer c WITH(NOLOCK)
		INNER JOIN #tmpShadowCust tmp ON c.custid = tmp.realCustId
	WHERE c.roleid = 1
	;

	--TODO: filter owner Licensee
	DELETE d
	FROM #shadowRealCust d
	LEFT JOIN #tmpAg a ON a.CustId = d.recommend 
	WHERE a.CustId IS NULL

	--TODO: filter username if any
	IF LEN(@UserName) > 0
	BEGIN
		WITH CTE_CustSearch AS (
			SELECT t.realCustId
			FROM #shadowRealCust t 
			WHERE t.username = @UserName --- system Id
				OR t.username2 LIKE '%$' + @UserName -- external Id
		)
		DELETE d
		FROM #shadowRealCust d
		LEFT JOIN CTE_CustSearch cs ON cs.realCustId = d.realCustId
		WHERE cs.realCustId IS NULL
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
		FROM (
			SELECT 
				m.winlostdate
				,m.custid
				,m.OpeningBalance
				, (
				   m.OpeningBalance + ISNULL(t.Deposit, 0) + ISNULL(t.Aff2MemTransfer, 0) - ISNULL(t.Withdrawal, 0)
				   + ISNULL(t.Bonus, 0) + ISNULL(t.Adjustment, 0) - ISNULL(t.Outstanding, 0) + ISNULL(t.Winloss, 0)
				   + ISNULL(t.playercomm, 0) + ISNULL(t.Transfer3rd, 0) + ISNULL(t.Transfer3rdOthers, 0) - ISNULL(t.Comm_Bettrade_Full, 0)
				   + ISNULL(t.Promotion, 0)
				   + ISNULL(b.Bonus, 0) + ISNULL(b.Adjustment, 0)
				) ClosingBalance
			 
		FROM bodb_report.dbo.rptDepWinlost_Main m WITH (NOLOCK)
			INNER JOIN #shadowRealCust AS a ON a.shadowCustId = m.CustID
			LEFT JOIN bodb_report.dbo.rptDepWinlost_Trans t WITH (NOLOCK) ON m.custid = t.custid
				AND m.winlostdate = t.winlostdate
				AND t.Sporttype = -1
				AND t.PartnerID = -1
			LEFT JOIN bodb_report.dbo.rptDepWinlost_BonusWallet b WITH (NOLOCK) ON m.custid = b.custid
				AND m.winlostdate = b.winlostdate -- New Bonus Wallet  
			
			WHERE m.winlostdate IN(@tmpdate, @tdate)
		) AS b 
		GROUP BY b.CustId;

		-- detail sum WL
		INSERT INTO #sumWinlost (shadowCustId, Turnover, Outstanding, winloss)
		SELECT p.custid
			, SUM(ISNULL(p.turnover, 0)) AS Turnover
			, SUM(ISNULL(p.outstanding, 0)) AS outstanding
			, SUM(ISNULL(p.Winloss, 0)) AS Winloss
		FROM bodb_report.dbo.rptDepWinlost_Trans p WITH (NOLOCK)
			INNER JOIN #shadowRealCust AS a ON p.custid = a.shadowCustId
		WHERE p.winlostdate BETWEEN @tmpdate AND @tdate
			AND p.SportType = 0
			AND p.PartnerID = -1
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
			INNER JOIN #shadowRealCust AS a ON b.custid = a.shadowCustId
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
			AND p.sporttype = 0
		GROUP BY p.custid
	END

	--TODO: output result
	SELECT t.realCustId AS custId, t.username
		, SUBSTRING(t.username2, CHARINDEX('$', t.username2) + 1, LEN(t.username2) - CHARINDEX('$', t.username2)) AS nickname
		, SUM(ISNULL(rpt.OpeningBalance, 0)) AS OpeningBalance
		, SUM(ISNULL(rpt.Turnover, 0)) AS Turnover
		, SUM(ISNULL(rpt.Outstanding, 0)) AS Outstanding
		, SUM(ISNULL(rpt.WinLoss, 0)) AS WinLoss
		, SUM(ISNULL(rpt.ClosingBalance, 0)) AS ClosingBalance
	FROM #sumWinlost rpt
		INNER JOIN #shadowRealCust t ON t.shadowCustId = rpt.ShadowCustId
	GROUP BY t.realCustId, t.username
		, SUBSTRING(t.username2, CHARINDEX('$', t.username2) + 1, LEN(t.username2) - CHARINDEX('$', t.username2))
END
GO
