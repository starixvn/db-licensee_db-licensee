/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_Outstanding]
    @showSB			BIT = 0,  
    @ShowRB			BIT = 0,  
    @showNG			BIT = 0,   
    @ShowBA			BIT = 0,
	@ShowVS			BIT = 0,
	@ShowCS			BIT = 0, --- RNG Casino
	@ShowBG			BIT = 0, --- Bingo 
	@ShowKN			BIT = 0, --- Keno
	@ShowMGCLC		BIT = 0,
	@ShowMGCRnG		BIT = 0,
	@ShowAGC		BIT = 0,
	@ShowVB			BIT = 0,
	@ShowAB			BIT = 0,
	@ShowCB			BIT = 0,
	@ShowFW			BIT	= 0,
	@ShowVS2		BIT = 0,
	@ShowLT			BIT = 0,
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
DB: DBEXT.bodb02
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
        @Today		SMALLDATETIME,
		@FromDate	DATETIME,
		@ToDate		DATETIME 

	SELECT  @PageIndex	= @PageIndex - 1 ,
            @RowStart	= @PageSize * @PageIndex + 1 ,
            @RowEnd		= @RowStart + @PageSize - 1 ,
            @Today		= CONVERT(DATE, GETDATE()) 
    
    SELECT	@FromDate	= CASE WHEN MAX(m.eventdate) <= @Today THEN MAX(m.eventdate) ELSE @Today END,
			@ToDate		= @Today
	FROM dbo.match14 m (NOLOCK)
	GROUP BY m.eventdate 	        
	
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
		BetCounts	INT       
	)       

	CREATE TABLE #AgentBettype (CustId INT, Currency TINYINT, Bettype SMALLINT, PRIMARY KEY (CustId, Currency, bettype))

    DECLARE @i BIGINT = 10000000
	
	--1. bettrans --  
	--1.1
	INSERT INTO #AgentBettype (CustId, Currency, Bettype)
	SELECT DISTINCT CustId, Currency, Bettype 
	FROM @TempAg 
	CROSS JOIN SportbettypeMatrix b WITH (NOLOCK) 
			WHERE 
			(@showSB = 1 AND (b.Bettype < 31 OR (b.Bettype BETWEEN 121 AND 999) OR (b.Bettype BETWEEN 1301 and 1399))) --new tennis's bettypes
			OR (@showRB = 1 AND b.Bettype IN (31,32,33))
			OR (@showNG = 1 AND b.Bettype BETWEEN 81 AND 120)
			OR (@ShowVS = 1 AND b.Bettype BETWEEN 1201 AND 1299)
			OR (@ShowVS2 = 1 AND b.Bettype BETWEEN 2701 AND 2829)
			OR (@ShowBG = 1 AND b.Bettype = 73)
			AND b.Bettype <= 2829
			AND (b.Bettype NOT BETWEEN 2101 AND 2399 OR b.Bettype NOT BETWEEN 2901 AND 2999) -- exclude OWRnG
			AND b.Bettype NOT BETWEEN 4001 AND 7999 -- exclude Voidbridge 	
	
	--1.2
	INSERT INTO @Outstanding
	SELECT 
		b.username,
		b.custid,                    
		b.currency,
		SUM(actual_stake) Outstanding,
		COUNT(1) AS BetCounts		   
	FROM #AgentBettype a
		INNER JOIN dbo.bettrans AS b WITH(NOLOCK)	
			ON  b.recommend = a.CustId AND b.Currency = a.Currency AND b.bettype = a.bettype 
	WHERE b.StatusID IN (0,1)	
		AND NOT EXISTS (SELECT 1 FROM bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) WHERE b.transid = BA.transid )				 	              
	GROUP BY
		b.username,
		b.custid,
		b.currency	 


	--2. translog --
	--2.1
	DELETE #AgentBettype 

	INSERT INTO #AgentBettype (CustId, Currency, Bettype)
	SELECT DISTINCT CustId, Currency, Bettype 
	FROM @TempAg 
	CROSS JOIN SportbettypeMatrix b WITH (NOLOCK) 
			WHERE 
			(
			(@ShowKN = 1 AND b.Bettype BETWEEN 1501 AND 1599)
			OR (@ShowMGCLC = 1 AND b.Bettype BETWEEN 2001 AND 2007)
			OR (@ShowCB =1 AND b.Bettype = 18000)
			OR (@ShowLT = 1 AND b.Bettype BETWEEN 1021 AND 1049)
			)
		
	--2.2		
	INSERT INTO @Outstanding
	SELECT
		t.Username,
		t.custid,
		t.currency,
		SUM(t.actual_stake) Outstanding,
		COUNT(1) BetCounts 
	FROM
		dbo.translog t WITH (NOLOCK) 
		INNER JOIN #AgentBettype a ON t.recommend = a.CustId AND t.Currency = a.Currency AND t.gameID = a.bettype
	WHERE
		t.StatusID IN (0,1)	
	GROUP BY
		t.Username,
		t.custid,
		t.currency     
	

	-- 3. bettrans RNG --
	-- 3.1
	DELETE #AgentBettype 

	INSERT INTO #AgentBettype (CustId, Currency, Bettype)
	SELECT DISTINCT CustId, Currency, Bettype 
	FROM @TempAg 
	CROSS JOIN SportbettypeMatrix b WITH (NOLOCK) 
	WHERE 			
		(
			(@ShowMGCRnG = 1 AND b.Bettype BETWEEN 2008 AND 2009)
			OR (@ShowCS  = 1 AND (b.Bettype BETWEEN 2101 AND 2399 OR b.Bettype BETWEEN 2901 AND 2999)) -- AND bettrans.matchID IN (208, 209, 210)
			OR (@ShowVB  = 1 AND b.Bettype BETWEEN 4001 AND 7999)
			OR (@ShowFW  = 1 AND b.Bettype BETWEEN  1011 AND 1020)
		)

	--3.2
	INSERT INTO @Outstanding
	SELECT
		g.Username,
		g.custid,
		g.currency,
		SUM(g.actual_stake) Outstanding,
		COUNT(DISTINCT CASE WHEN gameID BETWEEN 2101 AND 2399 
								OR g.gameID BETWEEN 2901 AND 2999
								OR gameID BETWEEN 4001 AND 7999 
								OR gameID BETWEEN 1011 AND 1020 THEN refno -- count sum tickets for RNG Casino, Voidridge, FW
						    WHEN gameID BETWEEN 2008 AND 2009 THEN transid
					END) BetCounts
	FROM
		dbo.BettransRNG g WITH (NOLOCK) 
		INNER JOIN #AgentBettype a ON g.recommend = a.CustId AND g.Currency = a.Currency AND g.gameID = a.bettype	
	WHERE
		statusid IN (0, 1) -- AND IsSum = 0		
	GROUP BY g.Username, g.custid, g.currency


	-- 4. bettransLC --
	--4.1
	DELETE #AgentBettype 

	INSERT INTO #AgentBettype (CustId, Currency, Bettype)
	SELECT DISTINCT CustId, Currency, Bettype 
	FROM @TempAg 
	CROSS JOIN SportbettypeMatrix b WITH (NOLOCK) 
	WHERE 			
		(
		(@ShowAGC = 1   AND b.bettype BETWEEN 1800 AND 1804)
		OR (@ShowAB = 1   AND b.bettype BETWEEN 2401 AND 2499)
		)

	--4.2
	INSERT INTO @Outstanding
	SELECT
		g.Username,
		g.custid,
		g.currency,
		SUM(g.actual_stake) Outstanding,
		COUNT(1) BetCounts 
	FROM
		dbo.bettransLC g WITH (NOLOCK) 
		INNER JOIN #AgentBettype a ON g.recommend = a.CustId AND g.Currency = a.Currency AND g.gameID = a.bettype			
	WHERE
		statusid IN (0, 1) -- AND IsSum = 0		
	GROUP BY g.Username, g.custid, g.currency

	-- 5. BA	
	IF @ShowBA = 1
	BEGIN
		INSERT INTO @Outstanding
        SELECT  
			b.username,
            b.custid,      
            b.currency,              
            SUM(actual_stake) Outstanding,
            COUNT(1) AS BetCounts
        FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @TempAg a ON b.recommend = a.CustId AND b.Currency = a.Currency           
        WHERE   
			(b.bettype <= 999 OR b.bettype BETWEEN 1301 and 1399)
			AND b.StatusID IN (0,1)			
			AND EXISTS (SELECT 1 FROM bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) WHERE b.transid = BA.transid)
        GROUP BY 
			b.username,
            b.custid,
            b.currency            
	END
	
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
				SELECT b.*,
					SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,
					LEN(c.username2) - CHARINDEX('$', c.username2)) AS nickname
				FROM
				(
					SELECT 
						b.custid
						,b.username
						,SUM(b.Outstanding) AS Outstanding
						,SUM(b.Outstanding * e.USD) AS OutstandingUSD
						,SUM(b.Outstanding * e.EUR) AS OutstandingEUR
						,SUM(b.Outstanding * e.GBP) AS OutstandingGBP
						,SUM(BetCounts) AS BetCounts					                   
					FROM  
						@Outstanding b
						INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today, @Today)) e ON e.exchangeid = b.currency							
					GROUP BY b.custid, b.username
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
						WHEN 2 THEN 
							CASE @BaseCurrency
								WHEN 'USD' THEN b.OutstandingUSD
								WHEN 'EUR' THEN b.OutstandingEUR
								WHEN 'GBP' THEN b.OutstandingGBP
								ELSE Outstanding
							END
						WHEN 3 THEN b.BetCounts
					END, b.custid) AS RowNum,
				b.* 
			FROM
			(
				SELECT b.*,
					SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,
					LEN(c.username2) - CHARINDEX('$', c.username2)) AS nickname
				FROM
				(
					SELECT 
						b.custid
						,b.username
						,SUM(b.Outstanding) AS Outstanding
						,SUM(b.Outstanding * e.USD) AS OutstandingUSD
						,SUM(b.Outstanding * e.EUR) AS OutstandingEUR
						,SUM(b.Outstanding * e.GBP) AS OutstandingGBP
						,SUM(BetCounts) AS BetCounts					                   
					FROM  
						@Outstanding b
						INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today, @Today)) e ON e.exchangeid = b.currency							
					GROUP BY b.custid, b.username
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
				SELECT b.*,
					SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,
					LEN(c.username2) - CHARINDEX('$', c.username2)) AS nickname
				FROM
				(
					SELECT 
						b.custid
						,b.username
						,SUM(b.Outstanding) AS Outstanding
						,SUM(b.Outstanding * e.USD) AS OutstandingUSD
						,SUM(b.Outstanding * e.EUR) AS OutstandingEUR
						,SUM(b.Outstanding * e.GBP) AS OutstandingGBP
						,SUM(BetCounts) AS BetCounts					                   
					FROM  
						@Outstanding b
						INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today, @Today)) e ON e.exchangeid = b.currency							
					GROUP BY b.custid, b.username
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
						WHEN 2 THEN 
							CASE @BaseCurrency
								WHEN 'USD' THEN b.OutstandingUSD
								WHEN 'EUR' THEN b.OutstandingEUR
								WHEN 'GBP' THEN b.OutstandingGBP
								ELSE Outstanding
							END
						WHEN 3 THEN b.BetCounts
					END DESC, b.custid) AS RowNum,
				b.* 
			FROM
			(
				SELECT b.*,
					SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,
					LEN(c.username2) - CHARINDEX('$', c.username2)) AS nickname
				FROM
				(
					SELECT 
						b.custid
						,b.username
						,SUM(b.Outstanding) AS Outstanding
						,SUM(b.Outstanding * e.USD) AS OutstandingUSD
						,SUM(b.Outstanding * e.EUR) AS OutstandingEUR
						,SUM(b.Outstanding * e.GBP) AS OutstandingGBP
						,SUM(BetCounts) AS BetCounts					                   
					FROM  
						@Outstanding b
						INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today, @Today)) e ON e.exchangeid = b.currency							
					GROUP BY b.custid, b.username
				) AS b
				INNER JOIN Customer c WITH (NOLOCK) ON b.custid = c.custid
			) b
		)        
		SELECT * 
		FROM Paging
		WHERE RowNum BETWEEN @RowStart AND @RowEnd
    END

    SELECT  
		ISNULL(SUM(Outstanding),0.00) AS SumOutstanding,
        ISNULL(SUM(Outstanding * e.USD),0.00) AS SumOutstandingUSD,
        ISNULL(SUM(Outstanding * e.EUR),0.00) AS SumOutstandingEUR,
		ISNULL(SUM(Outstanding * e.GBP),0.00) AS SumOutstandingGBP,
        SUM(BetCounts) AS SumBetCounts,
        COUNT(1) AS TotalRows
    FROM
		@Outstanding b
		INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today, @Today)) e ON e.exchangeid = b.currency
END

GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_Outstanding] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_Outstanding] TO [vnteam]
GO