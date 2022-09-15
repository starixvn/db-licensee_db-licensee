/*<info serverAlias="DBSID-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[SiteDB_Lrf_Rpt_Outstanding]
	@ProductList	VARCHAR(500),
	@ShowBA			BIT				= 0,
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@AgentList		VARCHAR(MAX),
	@OrderItem		TINYINT			= 1,
	@IsAscSort		BIT				= 1,
	@BaseCurrency	VARCHAR(12)		= ''
AS 
/*
	Created: 20220729@Victoria
	Task: Report Outstanding
	DB: DBSID-bodb02
	Original Lrf_Rpt_Outstanding

	Revisions:
		- 20220729@Victoria: Create SP[Redmine: #175297]
   		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]

	Param's Explanation:
		@OrderItem:
			1: username
			2: Outstanding
			3: BetCounts
			4: nickname

		@IsAscSort:
			1: ASC
			2: DESC
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempAg	TABLE (CustId INT, Currency INT)
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO @TempAg(CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;

	DECLARE @Outstanding TABLE (
		Username	NVARCHAR(50),
		CustId		INT,
		Currency	INT,
		Outstanding MONEY,
		BetCounts	INT,
		IsBA		BIT DEFAULT (0),
		ProductId	INT
	)

	CREATE TABLE #SportBettype (BetType SMALLINT, RefTable TINYINT, ProductId TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	DECLARE @ShowSB BIT = 0

	IF ',' + @ProductList + ',' LIKE '%,SB,%'
		SET @ShowSB = 1

	IF @ShowBA = 1
		SET @ProductList = @ProductList + ',SB'

	IF LEN(ISNULL(@ProductList, '')) > 0 
	BEGIN
		INSERT INTO #SportBettype (BetType, RefTable, ProductId)
		SELECT DISTINCT BetType, RefTable, ProductID
		FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)
		WHERE BetType NOT IN (SELECT BetType FROM dbo.Lrf_f_SelExcludedBetType())
	END

	--1. bettrans --
	INSERT INTO @Outstanding (
		CustId,
		Currency,
		Outstanding,
		BetCounts,
		IsBA,
		ProductId )
	SELECT
		b.custid,
		b.currency,
		SUM(b.actual_stake) AS Outstanding,
		COUNT(1) AS BetCount,
		CASE WHEN BA.TransID IS NULL THEN 0 ELSE 1 END AS IsBA,
		s.ProductId
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN #SportBettype AS s ON s.bettype = b.bettype
		INNER JOIN @TempAg AS a ON b.recommend = a.CustId
		LEFT JOIN dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON b.transid = BA.transid
	WHERE b.statusID IN (0, 1) AND s.RefTable = 0
	GROUP BY
		b.custid,
		b.currency,
		CASE WHEN BA.TransID IS NULL THEN 0 ELSE 1 END,
		s.ProductID

	IF @ShowSB = 0
	BEGIN
		DELETE @Outstanding
		WHERE IsBA = 0 AND ProductID = 1
	END

	IF @ShowBA = 0
	BEGIN
		DELETE @Outstanding
		WHERE IsBA = 1
	END

	--2. translog --
	INSERT INTO @Outstanding (
		CustId,
		Currency,
		Outstanding,
		BetCounts )
	SELECT
		t.custid,
		t.currency,
		SUM(t.actual_stake) AS Outstanding,
		COUNT(1) BetCounts
	FROM dbo.translog AS t WITH (NOLOCK)
		INNER JOIN @TempAg AS a ON t.recommend = a.CustId
	WHERE t.statusID IN (0, 1)
		AND EXISTS (SELECT 1 FROM #SportBettype s WHERE s.RefTable = 3 AND s.bettype = t.gameid)
	GROUP BY
		t.custid,
		t.currency

	-- 3. bettrans RNG -- 
	INSERT INTO @Outstanding (
		CustId,
		Currency,
		Outstanding,
		BetCounts )
	SELECT
		g.custid,
		g.currency,
		SUM(g.actual_stake) AS Outstanding,
		COUNT(DISTINCT refno) AS BetCounts
	FROM dbo.bettransRnG AS g WITH (NOLOCK)
		INNER JOIN @TempAg a ON g.recommend = a.CustId
		INNER JOIN #SportBettype s ON s.RefTable = 1 AND s.bettype = g.gameID
	WHERE g.statusID IN (0, 1) AND g.productID NOT IN (150, 173)
	GROUP BY
		g.custid,
		g.currency

	-- 4. bettransLC --
	INSERT INTO @Outstanding (
		CustId,
		Currency,
		Outstanding,
		BetCounts)
	SELECT
		g.custid,
		g.currency,
		SUM(g.actual_stake) AS Outstanding,
		COUNT(1) BetCounts
	FROM dbo.bettransLC AS g WITH (NOLOCK)
		INNER JOIN @TempAg AS a ON g.recommend = a.CustId
		INNER JOIN #SportBettype AS s ON s.bettype = g.gameid
	WHERE g.statusID IN (0, 1) AND
		(s.RefTable = 1 OR s.RefTable = 2)
	GROUP BY
		g.custid,
		g.currency

	IF @OrderItem < 1 OR @OrderItem > 4
	BEGIN
		SET @OrderItem = 1
	END

	DECLARE
		@RowStart	INT,
		@RowEnd		INT,
		@Today		SMALLDATETIME

	SELECT @PageIndex	= @PageIndex - 1 ,
		@RowStart	= @PageSize * @PageIndex + 1 ,
		@RowEnd		= @RowStart + @PageSize - 1 ,
		@Today		= CONVERT(DATE, GETDATE())

	DECLARE @Exchange TABLE (
		ExchangeId	INT,
		Rate		FLOAT
	)

	INSERT INTO @Exchange(ExchangeId, Rate)
	SELECT e.ExchangeId, e.Rate
	FROM dbo.SiteDB_Lrf_f_GetExchangeRate(@Today, @Today, @BaseCurrency, '') e
	WHERE EXISTS (SELECT 1 FROM @TempAg a WHERE a.Currency = e.ExchangeId)

	IF @OrderItem IN (1, 4) AND @IsAscSort = 1
	BEGIN
		;WITH Paging AS
		(
			SELECT
				ROW_NUMBER() OVER (ORDER BY CASE @OrderItem
												WHEN 1 THEN b.username
												WHEN 4 THEN b.nickname
											END) AS RowNum,
				b.*
			FROM
			(
				SELECT b.*,
					c.username,
					SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS Nickname
				FROM (
						SELECT
							b.custid,
							SUM(b.Outstanding * e.Rate) AS Outstanding,
							SUM(b.BetCounts) AS BetCounts
						FROM @Outstanding AS b
							INNER JOIN @Exchange AS e ON e.ExchangeId = b.Currency
						GROUP BY b.custid
					) AS b
					INNER JOIN CustDB.dbo.Customer AS c WITH (NOLOCK) ON b.custid = c.custid
			) b
		)
		SELECT *
		FROM Paging
		WHERE RowNum BETWEEN @RowStart AND @RowEnd
	END

	IF @OrderItem IN (2, 3) AND @IsAscSort = 1
	BEGIN
		;WITH Paging AS
		(
			SELECT
				ROW_NUMBER() OVER (ORDER BY CASE @orderItem 
												WHEN 2 THEN Outstanding
												WHEN 3 THEN b.BetCounts
											END, b.custid) AS RowNum,
				b.* 
			FROM
			(
				SELECT b.*,
					c.username,
					SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS Nickname
				FROM (
						SELECT
							b.custid,
							SUM(b.Outstanding * e.Rate) AS Outstanding,
							SUM(b.BetCounts) AS BetCounts
						FROM @Outstanding AS b
							INNER JOIN @Exchange AS e ON e.ExchangeId = b.Currency
						GROUP BY b.custid
					) AS b
					INNER JOIN CustDB.dbo.Customer AS c WITH (NOLOCK) ON b.custid = c.custid
			) b
		)
		SELECT *
		FROM Paging
		WHERE RowNum BETWEEN @RowStart AND @RowEnd
	END

	IF @OrderItem IN (1, 4) AND @IsAscSort = 0
	BEGIN
		;WITH Paging AS
		(
			SELECT
				ROW_NUMBER() OVER (ORDER BY CASE @OrderItem
												WHEN 1 THEN b.username
												WHEN 4 THEN b.nickname
											END DESC) AS RowNum,
				b.* 
			FROM
			(
				SELECT b.*,
					c.username,
					SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS Nickname
				FROM (
						SELECT
							b.custid,
							SUM(b.Outstanding * e.Rate) AS Outstanding,
							SUM(b.BetCounts) AS BetCounts
						FROM @Outstanding AS b
							INNER JOIN @Exchange AS e ON e.ExchangeId = b.Currency
						GROUP BY b.custid
					) AS b
					INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON b.custid = c.custid
			) b
		)
		SELECT *
		FROM Paging
		WHERE RowNum BETWEEN @RowStart AND @RowEnd
	END

	IF @OrderItem IN (2, 3) AND @IsAscSort = 0
	BEGIN
		;WITH Paging AS
		(
			SELECT
				ROW_NUMBER() OVER (ORDER BY CASE @orderItem 
												WHEN 2 THEN Outstanding
												WHEN 3 THEN b.BetCounts
											END DESC, b.custid) AS RowNum,
				b.* 
			FROM
			(
				SELECT b.*,
					c.username,
					SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS nickname
				FROM (
						SELECT
							b.custid,
							SUM(b.Outstanding * e.Rate) AS Outstanding,
							SUM(b.BetCounts) AS BetCounts
						FROM @Outstanding AS b
							INNER JOIN @Exchange AS e ON e.exchangeid = b.currency
						GROUP BY b.custid
					) AS b
					INNER JOIN CustDB.dbo.Customer AS c WITH (NOLOCK) ON b.custid = c.custid
			) b
		)
		SELECT *
		FROM Paging
		WHERE RowNum BETWEEN @RowStart AND @RowEnd
	END

	SELECT
		ISNULL(SUM(b.Outstanding * e.Rate), 0.00) AS SumOutstanding,
		SUM(b.BetCounts) AS SumBetCounts,
		COUNT(1) AS TotalRows
	FROM @Outstanding AS b
		INNER JOIN @Exchange AS e ON e.exchangeid = b.currency

	DROP TABLE #SportBettype
END
GO
