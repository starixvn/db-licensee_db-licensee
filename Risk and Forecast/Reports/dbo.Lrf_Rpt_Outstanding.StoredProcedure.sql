/*<info serverAlias="DBBOF-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_Outstanding]
	@ProductList	VARCHAR (500),
	@PageSize		INT = 1000,
	@PageIndex		INT = 1,
	@AgentList		VARCHAR(MAX),
	@OrderItem		TINYINT = 1,
	@IsAscSort		BIT = 1,
	@BaseCurrency	VARCHAR(5) = ''
AS 
/*
Created: 20101201@Jacob
Task : Report Outstanding
DB: DB042-bodb02
Original Age_Rpt_Outstanding_Ag

Revisions:
    - 20101201@Jacob: Copy source code from Age_Rpt_Outstanding_Ag
    - 2011216@Alex:Add username2
    - 20110303@Jacob: Allow to choose all type of licensee AND all currency + suppport based currency
    - 20110513@Henry: change bettype to new range   
    - 20110719@Henry: remove PT
    - 20110012@Elly: add BetCounts, add @showSB, @ShowRB, @ShowNG, and @showBA
    - 20110921@Henry: add Sum BetCounts
    - 20111208@Jim: Change condition bettype 
	- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	- 20120815@Jim: add live casino 
	- 20120906@Jim: add virtual sport
	- 20121004@Jim: replace @currencyname input param by @currencyID
	- 20130225@Jim: support RNG Casino, Bingo
	- 20130618@Jim: Restrict permission of Licensee Users by currency
	- 20140407@Florent: support Keno product
	- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
	- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
	- 20150129@Jim: add base on GBP
	- 20150612@Jim: support MicroGaming
	- 20150910@Jim: Integrate Microgaming RNG games (feature #43078)
	- 20150917@Florent: Change datasource for AG Casino (#Redmine 43172)
	- 20151108@Jim: Separated MicroGaming into 2 product
	- 20151228@Bobby: Implement RNG Casino sporttype(208,209,210)
	- 20151228@Bobby: #51661 - Count running OW-RnG ticket in bettrans instead of betransRnG
	- 20160401@Percy: Support Voidbridge single wallet [Redmine: #55057]
	- 20160619@Jim: Allbet - Live Casino Integration for Licensees [Redmine: #59624]
	- 20160913@Jim : LRF - Implement Colossus Bets [Redmine: #63785]
	- 20161115@Jim: LRF - Integrate new product Fishing World [RedmineID : #66737]
	- 20170228@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID, Remove @LicenseeType [Redmine: #71679]
	- 20170316@Paul: Missing FW data for Bet count column [RedmineID : #73475]
	- 20170710@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
	- 20170731@Harper: LRF - Integrate Lottery [RedmineID: #79997]
	- 20170814@Harper: One RNG - Offer New Tablet Games [RedmineID: #78424]
	- 20171108@Paul: Support sorting [RedmineID: #86214]
	- 20180129@Harper: Remove LC from product list [RedmineID: #85965]
	- 20180409@Joseph: Implement new sports for VS2: BasketBall - Virual Soccer World Cup [Redmine: #90881]
	- 20180802@Sophia: use LicenseeBATransaction_active instead of LicenseeBATransaction, change code to use index on DB042 [Redmind: #98631]
	- 20180904@Amanda: LAP - Integrate PP [RedmineID: #92318]
	- 20190329@Amanda: Missing PP data for Bet count column [RedmineID: #109471]
	- 20190327@Amanda: Fix bug - Add AB back to SP (AB has been deleted before) [RedmineID: #110927]
	- 20190322@Amanda: Remove MGCLC & MGRnG [RedmineID: #107704]
	- 20190620@Amanda: Centralize function to get exchange rate [Redmine: #112531]
	- 20190708@Amanda: Add new product Card Club [RedmineID: #115449]
	- 20191121@Amanda: Exclude PP Promotion and Tournament Prize [RedmineID: #123804]
	- 20191212@Vickie: Integrate SpadeGaming [RedmineID: #124103]
	- 20200108@Vickie: Add new product Virtual Games [RedmineID: #124911]
	- 20200406@Hogan: Add new product Table Games [RedmineID: #131447]

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

	IF @OrderItem < 1 OR @OrderItem > 4
	BEGIN
		SET @OrderItem = 1
	END

    DECLARE
		@RowStart	INT,
        @RowEnd		INT,
        @Today		SMALLDATETIME

	SELECT  @PageIndex	= @PageIndex - 1 ,
            @RowStart	= @PageSize * @PageIndex + 1 ,
            @RowEnd		= @RowStart + @PageSize - 1 ,
            @Today		= CONVERT(DATE, GETDATE())    
        
	
	DECLARE @TempAg		TABLE (CustId INT, Currency INT)
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO @TempAg(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;


	DECLARE @Outstanding TABLE
	(
		username	NVARCHAR(50),
		custid		INT,
		currency	INT,
		outstanding MONEY,
		BetCounts	INT , 
		IsBA		BIT DEFAULT (0),
		ProductID   INT 
	)
	
	CREATE TABLE #SportBettype (bettype SMALLINT, RefTable TINYINT, ProductID TINYINT)

	DECLARE @IsTest BIT = 0
	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)
	
	DECLARE @Exchange TABLE
	(
		ExchangeID	INT,
		Rate		FLOAT
	)
	
	INSERT INTO @Exchange(ExchangeID, Rate)
	SELECT	ExchangeID, Rate
	FROM dbo.Lrf_f_GetExchangeRate(@Today, @Today, @BaseCurrency, '') e
	WHERE EXISTS (SELECT 1 FROM @TempAg a WHERE a.Currency = e.ExchangeId)

	IF LEN(ISNULL(@ProductList, '')) > 0 
	BEGIN
		-- Insert Bettype
		INSERT INTO #SportBettype ( bettype, RefTable, ProductID )
		SELECT DISTINCT BetType, RefTable, ProductID
		FROM f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)
		
		IF CHARINDEX('PP', @ProductList) > 0
		BEGIN
			DELETE #SportBettype
			WHERE bettype IN (4300, 4299) AND ProductID = 32 -- PP
		END
	END	

	--1. bettrans --
	INSERT INTO @Outstanding (custid, currency, Outstanding, BetCounts, isBA, ProductID)
	SELECT 
		b.custid,                    
		b.currency,
		SUM(actual_stake) Outstanding,
		COUNT(1) AS BetCount,
		CASE WHEN BA.TransID IS NULL THEN 0 ELSE 1 END AS isBA,
		s.ProductID		
	FROM dbo.bettrans AS b WITH(NOLOCK)	
		INNER JOIN #SportBettype s ON  s.bettype  = b.bettype 
		INNER JOIN @TempAg a
			ON b.recommend = a.CustId AND b.Currency = a.Currency 	
		LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) on b.transid = BA.transid		
	WHERE b.StatusID IN (0,1) 
		AND s.RefTable = 0     
	GROUP BY		
		b.custid,
		b.currency, CASE WHEN BA.TransID IS NULL THEN 0 ELSE 1 END,
		s.ProductID
	
	IF CHARINDEX('SB', @ProductList) > 0
		BEGIN
			DELETE @Outstanding
			WHERE IsBA = 0 AND ProductID = 1
		END

	IF CHARINDEX('BA', @ProductList) > 0
		BEGIN
			DELETE @Outstanding
			WHERE IsBA = 1
		END

	--2. translog --
	INSERT INTO @Outstanding (custid, currency, Outstanding, BetCounts)
	SELECT
		t.custid,
		t.currency,
		SUM(t.actual_stake) Outstanding,
		COUNT(1) BetCounts 
	FROM dbo.translog t WITH (NOLOCK) 
		INNER JOIN @TempAg a
			ON t.recommend = a.CustId AND t.Currency = a.Currency 	
	WHERE t.StatusID IN (0,1)	
		AND EXISTS (SELECT 1 FROM #SportBettype s WHERE s.RefTable = 3 AND s.bettype = t.gameid)
	GROUP BY
		t.custid,
		t.currency     
	

	-- 3. bettrans RNG -- 
	INSERT INTO @Outstanding (custid, currency, Outstanding, BetCounts)
	SELECT
		g.custid,
		g.currency,
		SUM(g.actual_stake) Outstanding, 
		COUNT(DISTINCT refno) BetCounts
	FROM dbo.BettransRNG g WITH (NOLOCK) 
		INNER JOIN @TempAg a
			ON g.recommend = a.CustId AND g.Currency = a.Currency 	
		INNER JOIN #SportBettype s ON s.RefTable = 1 AND s.bettype = g.gameID 
	WHERE statusid IN (0,1) 
		---AND EXISTS (SELECT 1 FROM #SportBettype s WHERE s.RefTable = 1 AND s.bettype = g.gameID)
	GROUP BY g.custid, g.currency
	 

	-- 4. bettransLC --
	--4.2
	INSERT INTO @Outstanding (custid, currency, Outstanding, BetCounts)
	SELECT		
		g.custid,
		g.currency,
		SUM(g.actual_stake) Outstanding,
		COUNT(1) BetCounts 
	FROM dbo.bettransLC g WITH (NOLOCK) 
		INNER JOIN @TempAg a ON g.recommend = a.CustId AND g.Currency = a.Currency
		INNER JOIN #SportBettype s ON s.bettype = g.gameid
	WHERE
		statusid IN (0, 1) AND
		(s.RefTable = 1 OR s.RefTable = 2) -- AGC & AB
	GROUP BY g.custid, g.currency

	
	IF @OrderItem IN (1, 4) AND @IsAscSort = 1
	BEGIN
		;WITH Paging AS
		(
			SELECT
				ROW_NUMBER() OVER (
					ORDER BY CASE @OrderItem
						WHEN 1 THEN b.username
						WHEN 4 THEN b.nickname
					END) AS RowNum,
				b.* 
			FROM
			(
				SELECT b.*, c.username,
					SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,
					LEN(c.username2) - CHARINDEX('$', c.username2)) AS nickname
				FROM
				(
					SELECT 
						b.custid						
						,SUM(b.Outstanding * e.Rate) AS Outstanding
						,SUM(BetCounts) AS BetCounts					                   
					FROM  
						@Outstanding b
						INNER JOIN @Exchange e ON e.exchangeid = b.currency
					GROUP BY b.custid
				) AS b
				INNER JOIN Customer c WITH (NOLOCK) ON b.custid = c.custid
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
				ROW_NUMBER() OVER (
					ORDER BY CASE @orderItem 
						WHEN 2 THEN Outstanding
						WHEN 3 THEN b.BetCounts
					END, b.custid) AS RowNum,
				b.* 
			FROM
			(
				SELECT b.*, c.username,
					SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,
					LEN(c.username2) - CHARINDEX('$', c.username2)) AS nickname
				FROM
				(
					SELECT 
						b.custid						
						,SUM(b.Outstanding * e.Rate) AS Outstanding
						,SUM(BetCounts) AS BetCounts					                   
					FROM  
						@Outstanding b
						INNER JOIN @Exchange e ON e.exchangeid = b.currency
					GROUP BY b.custid
				) AS b
				INNER JOIN Customer c WITH (NOLOCK) ON b.custid = c.custid
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
				ROW_NUMBER() OVER (
					ORDER BY CASE @OrderItem
						WHEN 1 THEN b.username
						WHEN 4 THEN b.nickname
					END DESC) AS RowNum,
				b.* 
			FROM
			(
				SELECT b.*, c.username,
					SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,
					LEN(c.username2) - CHARINDEX('$', c.username2)) AS nickname
				FROM
				(
					SELECT 
						b.custid						 
						,SUM(b.Outstanding * e.Rate) AS Outstanding
						,SUM(BetCounts) AS BetCounts					                   
					FROM  
						@Outstanding b
						INNER JOIN @Exchange e ON e.exchangeid = b.currency
					GROUP BY b.custid 
				) AS b
				INNER JOIN Customer c WITH (NOLOCK) ON b.custid = c.custid
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
				ROW_NUMBER() OVER (
					ORDER BY CASE @orderItem 
						WHEN 2 THEN Outstanding
						WHEN 3 THEN b.BetCounts
					END DESC, b.custid) AS RowNum,
				b.* 
			FROM
			(
				SELECT b.*, c.username,
					SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,
					LEN(c.username2) - CHARINDEX('$', c.username2)) AS nickname
				FROM
				(
					SELECT 
						b.custid						 
						,SUM(b.Outstanding * e.Rate) AS Outstanding
						,SUM(BetCounts) AS BetCounts					                   
					FROM  
						@Outstanding b
						INNER JOIN @Exchange e ON e.exchangeid = b.currency
					GROUP BY b.custid 
				) AS b
				INNER JOIN Customer c WITH (NOLOCK) ON b.custid = c.custid
			) b
		)        
		SELECT * 
		FROM Paging
		WHERE RowNum BETWEEN @RowStart AND @RowEnd
    END

    SELECT  
        ISNULL(SUM(Outstanding * e.Rate),0.00) AS SumOutstanding,
        SUM(BetCounts) AS SumBetCounts,
        COUNT(1) AS TotalRows
    FROM
		@Outstanding b
		INNER JOIN @Exchange e ON e.exchangeid = b.currency

		DROP TABLE #SportBettype

END

GO