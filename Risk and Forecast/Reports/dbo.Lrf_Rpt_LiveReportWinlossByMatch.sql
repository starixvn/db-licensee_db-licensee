/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_LiveReportWinlossByMatch]   	
    @ShowSB			BIT	= 0,
    @ShowBA			BIT	= 0,	
	@ShowVS			BIT = 0,
	@ShowVS2		BIT = 0,	
    @SportId		INT = 0,
    @FromDate		SMALLDATETIME,  
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@Liveindicator	INT = 1,
	@AgentList		VARCHAR(MAX)
AS 
/*
Created: 20111031@
Task : Live Report Summary by Sport 
DB: DB052.bodb02

Revisions:
	- 20120110@Henry: remove @LicenseeType + enhance performance + remove currency UUS
	- 20120214@Jim: change to use table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	- 20120614@Jim: optimize code 
	- 20120726@Jim: add player commission value 
	- 20120820@Jim : add live casino 
	- 20120830@Henry: split column for clearer + Add Virtual Sports
	- 20121004@Jim: replace @currency input param by @currencyID
	- 20121115@Henry: Only Sportsbook needs to exclude BA
	- 20130618@Jim:  Restrict permission of Licensee Users by currency
	- 20130625@Jim: support to view currency UUS 
	- 20140602@Hannah: Separate Live/ Non - Live data in Live Report
	- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
	- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
	- 20150127@Jim: support base on GBP Currency
	- 20150612@Jim: support MicroGaming
	- 20150623@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission
	- 20151001@Jim: remove MicroGaming
	- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
	- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
	- 20170329@Paul: Implement Cash Out [RedmineID: #71727]
	- 20170710@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]	
	- 20180129@Harper: Remove LC from product list [RedmineID: #85965]

Return 3 tables:
WinlostBySport
WinlostByCurrency
WinlostByBetType
Param's Explanation:
	@SportId: Not includes mixparlay, outright, numbergame, horseracing
	@Liveindicator : indicate that whether the report will get live data or not
		+ 0: Non - Live data only
		+ 1: Live data only
		+ 2: All

	+ @AgentList: xml structure
					<ROOT>
					<Agent AgentId="12345" Currency="3"/>  
					<Agent AgentId="12345" Currency="5"/>  
					</ROOT> 
Example:

DECLARE @FromDate DATETIME
DECLARE @ToDate DATETIME
DECLARE @MoveBetsDay DATETIME
SELECT @FromDate = DATEADD(DAY, -15, GETDATE())
SELECT @ToDate = GETDATE()
SELECT @MoveBetsDay = MAX(eventdate) FROM match14 WITH(NOLOCK)

EXEC [Lrf_Rpt_LiveReportWinlossByMatch]	 @LicenseeId = 1, @CurrencyID = 0, @FromDate=@FromDate, @SportId =1, @ToDate=@ToDate, @MoveBetsDay = @MoveBetsDay

*/
SET NOCOUNT ON

DECLARE @TempFromDate DATETIME 
DECLARE @TempToDate DATETIME 
DECLARE @FDate SMALLDATETIME  
DECLARE @TDate SMALLDATETIME 
	
--to Deal With Parameter Sniffing
SELECT @FDate = @FromDate, @TDate = @ToDate 

DECLARE @TempAg AS TABLE ( CustId INT,Currency INT )
DECLARE @DocHandler INT

BEGIN TRY
	EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	INSERT INTO @TempAg (custID, currency)
	SELECT AgentId, Currency
	FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

	EXEC sp_xml_removedocument @DocHandler
END TRY

BEGIN CATCH
	SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

	RETURN
END CATCH; 
    
DECLARE @bettype AS TABLE (bettype INT PRIMARY KEY)
DECLARE @ProductList VARCHAR (500)

DECLARE @IsTest BIT = 0
SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

IF @ShowVS = 1
BEGIN
	SELECT @ProductList = COALESCE(@ProductList + ',' + 'VS', 'VS')
END  

IF @ShowVS2 = 1
BEGIN
	SELECT @ProductList = COALESCE(@ProductList + ',' + 'VS2', 'VS2')
END 

IF LEN(ISNULL(@ProductList, '')) > 0 
BEGIN
	-- Insert Bettype
	INSERT INTO @bettype ( bettype )
	SELECT DISTINCT BetType
	FROM f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)

END	

CREATE TABLE #tmpWinloss (
	winlostdate		DATETIME,  
	Currency		INT,
	MatchId			INT,	
	HomeId			INT,
	AwayId			INT,
	TurnOver		MONEY,   	
	Winlost			MONEY,  
	LicenseeWL		MONEY, 
	Comm			MONEY,  
	PlayerComm		MONEY,	
	AmtDueTo3rd		MONEY,
	Betcount		INT,
	Bettype			INT,
	showtime 		NVARCHAR(50) -- table - shoe - hand of Live Casino
)	

IF @TDate > @MoveBetsDay
BEGIN
	IF @FDate <= @MoveBetsDay 
		SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
	ELSE
		SET @TempFromDate = @FDate	

	IF @ShowBA = 1 
	BEGIN		
		INSERT INTO #tmpWinloss			
		SELECT
			b.winlostdate,  
			b.currency,
			m.matchid, 		
			m.homeid, 
			m.awayid,
			SUM(stake) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  		
			0 AS LicenseeWL,
			SUM (comm ) as Comm,
			SUM (  b.playercomm  ) as PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			COUNT(b.transid) BetCount,
			b.bettype,
			'' AS ShowTime 
		FROM bettrans b  WITH (NOLOCK) 
			INNER JOIN [match] m WITH(NOLOCK) ON b.matchid=m.matchid	
			INNER JOIN 	@TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency 
		WHERE
			 b.winlostdate BETWEEN @TempFromDate AND @TDate AND  			
			b.matchid > 0 AND
			(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)
						  OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
			) AND
			b.bettype NOT IN (9,29,901,902,903,904) AND 
			(b.bettype < 911 OR b.bettype > 914) AND
			b.statusID IN (111,112,113) AND
			b.tpositiontaking=0 AND
			m.sporttype = @SportId AND
			((@Liveindicator = 0 and b.liveindicator = 0)
			OR (@Liveindicator = 1 and b.liveindicator = 1)
			OR (@Liveindicator = 2))
		GROUP BY  b.winlostdate, b.currency, b.matchid, m.matchid, m.homeid, m.awayid,b.bettype				

		-- BA for parlay
		INSERT INTO #tmpWinloss			
		SELECT
			b.winlostdate,  
			b.currency,
			m.matchid, 		
			m.homeid, 
			m.awayid,
			SUM(stake) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  		
			0 AS LicenseeWL,
			SUM (comm ) as Comm,
			SUM (  b.playercomm  ) as PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			COUNT(b.transid) BetCount,
			b.bettype,
			'' AS ShowTime 
		FROM bettrans b  WITH (NOLOCK) 
			INNER JOIN [match] m WITH(NOLOCK) ON b.matchid=m.matchid	
			INNER JOIN 	@TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency		
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  			
			b.matchid > 0 AND
			b.bettype IN (9,29) AND
			b.statusID IN (111,112,113) AND
			b.tpositiontaking=0 AND
			m.sporttype = @SportId AND
			((@Liveindicator = 0 and b.livehomescore = 0)
			OR (@Liveindicator = 1 and b.livehomescore = 1)
			OR (@Liveindicator = 2))
		GROUP BY  b.winlostdate, b.currency, b.matchid, m.matchid, m.homeid, m.awayid,b.bettype
	END
	
	IF (@ShowSB=1)
	BEGIN
		INSERT INTO #tmpWinloss			
		SELECT
			b.winlostdate,  
			b.currency,
			m.matchid, 		
			m.homeid, 
			m.awayid,
			SUM(stake) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  	
			SUM(-1 * (b.winlost - b.actual_stake)) AS LicenseeWL,
			SUM (comm ) as Comm,
			SUM (  b.playercomm  ) as PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			COUNT(b.transid) BetCount,
			b.bettype, 
			'' AS ShowTime 
		FROM bettrans b  WITH (NOLOCK) 
			INNER JOIN [match] m WITH(NOLOCK) ON b.matchid=m.matchid	
			INNER JOIN 	@TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency	
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)
							OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
			) AND
			b.bettype NOT IN (9,29,901,902,903,904) AND 
			(b.bettype < 911 OR b.bettype > 914) AND
			b.matchid > 0 AND
			b.statusID IN (111,112,113) AND
			m.sporttype = @SportId AND
			b.tpositiontaking<>0 AND
			((@Liveindicator = 0 and b.liveindicator = 0)
			OR (@Liveindicator = 1 and b.liveindicator = 1)
			OR (@Liveindicator = 2))
		GROUP BY  b.winlostdate, b.currency, b.matchid, m.matchid, m.homeid, m.awayid,b.bettype

		-- SB for parlay
		INSERT INTO #tmpWinloss			
		SELECT
			b.winlostdate,  
			b.currency,
			m.matchid, 		
			m.homeid, 
			m.awayid,
			SUM(stake) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  	
			SUM(-1 * (b.winlost - b.actual_stake)) AS LicenseeWL,
			SUM (comm ) as Comm,
			SUM (  b.playercomm  ) as PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			COUNT(b.transid) BetCount,
			b.bettype, 
			'' AS ShowTime 
		FROM bettrans b  WITH (NOLOCK) 
			INNER JOIN [match] m WITH(NOLOCK) ON b.matchid=m.matchid
			INNER JOIN 	@TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency	
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			b.bettype IN (9,29) AND
			b.matchid > 0 AND
			b.statusID IN (111,112,113) AND
			m.sporttype = @SportId AND
			b.tpositiontaking<>0 AND
			((@Liveindicator = 0 and b.livehomescore = 0)
			OR (@Liveindicator = 1 and b.livehomescore = 1)
			OR (@Liveindicator = 2))
		GROUP BY  b.winlostdate, b.currency, b.matchid, m.matchid, m.homeid, m.awayid,b.bettype
	END

	IF ( @ShowVS = 1 OR @ShowVS2 = 1)
	BEGIN
		INSERT INTO #tmpWinloss			
		SELECT
			b.winlostdate,  
			b.currency,
			m.matchid, 		
			m.homeid, 
			m.awayid,
			SUM(stake) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  	
			SUM(-1 * (b.winlost - b.actual_stake)) AS LicenseeWL,
			SUM (comm ) as Comm,
			SUM (  b.playercomm  ) as PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			COUNT(b.transid) BetCount,
			b.bettype, 
			'' AS ShowTime 
		FROM bettrans b  WITH (NOLOCK) 
			INNER JOIN [match] m WITH(NOLOCK) ON b.matchid=m.matchid				
			INNER JOIN @bettype bt ON b.bettype = bt.bettype
			INNER JOIN 	@TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			b.matchid > 0 AND
			b.statusID IN (111,112,113) AND
			b.bettype <> 2799 AND
			m.sporttype = @SportId AND
			((@Liveindicator = 0 and b.liveindicator = 0)
			OR (@Liveindicator = 1 and b.liveindicator = 1)
			OR (@Liveindicator = 2))
		GROUP BY  b.winlostdate, b.currency, b.matchid, m.matchid, m.homeid, m.awayid,b.bettype,
					CASE WHEN b.bettype BETWEEN 1101 AND 1199  THEN ISNULL(m.showtime,'') ELSE '' END 
		
		-- Parlay for Betradar
		INSERT INTO #tmpWinloss			
		SELECT
			b.winlostdate,  
			b.currency,
			m.matchid, 		
			m.homeid, 
			m.awayid,
			SUM(stake) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  	
			SUM(-1 * (b.winlost - b.actual_stake)) AS LicenseeWL,
			SUM (comm ) as Comm,
			SUM (  b.playercomm  ) as PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			COUNT(b.transid) BetCount,
			b.bettype, 
			'' AS ShowTime 
		FROM bettrans b  WITH (NOLOCK) 
			INNER JOIN [match] m WITH(NOLOCK) ON b.matchid=m.matchid
			INNER JOIN 	@TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency	
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			b.bettype IN (2799) AND
			b.matchid > 0 AND
			b.statusID IN (111,112,113) AND
			m.sporttype = @SportId AND
			b.tpositiontaking<>0 AND
			((@Liveindicator = 0 and b.livehomescore = 0)
			OR (@Liveindicator = 1 and b.livehomescore = 1)
			OR (@Liveindicator = 2))
		GROUP BY  b.winlostdate, b.currency, b.matchid, m.matchid, m.homeid, m.awayid,b.bettype

	END	
END

	
IF @FDate <= @MoveBetsDay 
BEGIN
	IF @TDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET  @TempToDate = @TDate
			
	IF @ShowBA = 1
	BEGIN		
		INSERT INTO #tmpWinloss			
		SELECT
			b.winlostdate,  
			b.currency,
			m.matchid, 		
			m.homeid, 
			m.awayid,	
			SUM(stake) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  		
			0 AS LicenseeWL,
			SUM (comm ) as Comm,
			SUM (  playercomm  ) as PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			COUNT(b.transid) BetCount,
			b.bettype,
			'' AS ShowTime 
		FROM bettrans14 b  WITH (NOLOCK) 
			--INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
			INNER JOIN [match14] m WITH(NOLOCK) ON b.matchid = m.matchid
			INNER JOIN 	@TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
		WHERE
			b.winlostdate BETWEEN @FDate AND @TempToDate  AND
			(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)
						  OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
			) AND
			b.bettype NOT IN (9,29,901,902,903,904) AND 
			(b.bettype < 911 OR b.bettype > 914) AND
			b.tpositiontaking=0 AND
			b.statusID IN (111,112,113) AND
			m.sporttype = @SportId 	AND
			((@Liveindicator = 0 and b.liveindicator = 0)
			OR (@Liveindicator = 1 and b.liveindicator = 1)
			OR (@Liveindicator = 2))
		GROUP BY  b.winlostdate, b.currency, b.matchid, m.matchid, m.homeid, m.awayid,b.bettype
		
		-- BA for parlay
		INSERT INTO #tmpWinloss			
		SELECT
			b.winlostdate,  
			b.currency,
			m.matchid, 		
			m.homeid, 
			m.awayid,	
			SUM(stake) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  		
			0 AS LicenseeWL,
			SUM (comm ) as Comm,
			SUM (  playercomm  ) as PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			COUNT(b.transid) BetCount,
			b.bettype,
			'' AS ShowTime 
		FROM bettrans14 b  WITH (NOLOCK) 
			--INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
			INNER JOIN [match14] m WITH(NOLOCK) ON b.matchid = m.matchid
			INNER JOIN 	@TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
		WHERE
			b.winlostdate BETWEEN @FDate AND @TempToDate  AND
			b.bettype IN (9,29) AND
			b.tpositiontaking=0 AND
			b.statusID IN (111,112,113) AND
			m.sporttype = @SportId 	AND
			((@Liveindicator = 0 and b.livehomescore = 0)
			OR (@Liveindicator = 1 and b.livehomescore = 1)
			OR (@Liveindicator = 2))
		GROUP BY  b.winlostdate, b.currency, b.matchid, m.matchid, m.homeid, m.awayid,b.bettype

	END			
			
	IF (@ShowSB=1)
	BEGIN
		INSERT INTO #tmpWinloss			
		SELECT
			b.winlostdate,  
			b.currency,
			m.matchid, 		
			m.homeid, 
			m.awayid,	
			SUM(stake) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  		
			SUM(-1 * (b.winlost - b.actual_stake)) AS LicenseeWL,
			SUM (comm ) as Comm,
			SUM (playercomm  ) as PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			COUNT(b.transid) BetCount,
			b.bettype,
			'' AS ShowTime 
		FROM bettrans14 b  WITH (NOLOCK) 
			INNER JOIN [match14] m WITH(NOLOCK) ON b.matchid = m.matchid
			INNER JOIN 	@TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency	
		WHERE
			b.winlostdate BETWEEN @FDate AND @TempToDate  AND
			(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)
			    	 	  OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
			) AND
			b.bettype NOT IN (9,29,901,902,903,904) AND 
			(b.bettype < 911 OR b.bettype > 914) AND
			b.tpositiontaking<>0 AND
			b.statusID IN (111,112,113) AND
			m.sporttype = @SportId AND
			((@Liveindicator = 0 and b.liveindicator = 0)
			OR (@Liveindicator = 1 and b.liveindicator = 1)
			OR (@Liveindicator = 2))			
		GROUP BY  b.winlostdate, b.currency, b.matchid, m.matchid, m.homeid, m.awayid,b.bettype				

		-- SB for parlay
		INSERT INTO #tmpWinloss			
		SELECT
			b.winlostdate,  
			b.currency,
			m.matchid, 		
			m.homeid, 
			m.awayid,	
			SUM(stake) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  		
			SUM(-1 * (b.winlost - b.actual_stake)) AS LicenseeWL,
			SUM (comm ) as Comm,
			SUM (playercomm  ) as PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			COUNT(b.transid) BetCount,
			b.bettype,
			'' AS ShowTime 
		FROM bettrans14 b  WITH (NOLOCK) 
			INNER JOIN [match14] m WITH(NOLOCK) ON b.matchid = m.matchid
			INNER JOIN 	@TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency	
		WHERE
			b.winlostdate BETWEEN @FDate AND @TempToDate  AND
			b.bettype IN (9,29) AND
			b.tpositiontaking<>0 AND
			b.statusID IN (111,112,113) AND
			m.sporttype = @SportId AND
			((@Liveindicator = 0 and b.livehomescore = 0)
			OR (@Liveindicator = 1 and b.livehomescore = 1)
			OR (@Liveindicator = 2))			
		GROUP BY  b.winlostdate, b.currency, b.matchid, m.matchid, m.homeid, m.awayid,b.bettype
	END		
			
	IF (@ShowVS = 1 OR @ShowVS2 = 1)
	BEGIN		
		INSERT INTO #tmpWinloss			
		SELECT
			b.winlostdate,  
			b.currency,
			m.matchid, 		
			m.homeid, 
			m.awayid,	
			SUM(stake) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  		
			SUM(-1 * (b.winlost - b.actual_stake)) AS LicenseeWL,
			SUM (comm ) as Comm,
			SUM (playercomm  ) as PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			COUNT(b.transid) BetCount,
			b.bettype,
			'' AS ShowTime 
		FROM bettrans14 b  WITH (NOLOCK) 
			INNER JOIN [match14] m WITH(NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @bettype bt ON b.bettype = bt.bettype	
			INNER JOIN 	@TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency	
		WHERE
			b.winlostdate BETWEEN @FDate AND @TempToDate  AND
			b.statusID IN (111,112,113) AND
			m.sporttype = @SportId AND
			b.bettype <> 2799 AND
			((@Liveindicator = 0 and b.liveindicator = 0)
			OR (@Liveindicator = 1 and b.liveindicator = 1)
			OR (@Liveindicator = 2))
		GROUP BY  b.winlostdate, b.currency, b.matchid, m.matchid, m.homeid, m.awayid,b.bettype, 
				CASE WHEN b.bettype BETWEEN 1101 AND 1199  THEN ISNULL(m.showtime,'') ELSE '' END
		
		-- Parlay of Betradar
		INSERT INTO #tmpWinloss			
		SELECT
			b.winlostdate,  
			b.currency,
			m.matchid, 		
			m.homeid, 
			m.awayid,	
			SUM(stake) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  		
			SUM(-1 * (b.winlost - b.actual_stake)) AS LicenseeWL,
			SUM (comm ) as Comm,
			SUM (playercomm  ) as PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			COUNT(b.transid) BetCount,
			b.bettype,
			'' AS ShowTime 
		FROM bettrans14 b  WITH (NOLOCK) 
			INNER JOIN [match14] m WITH(NOLOCK) ON b.matchid = m.matchid
			INNER JOIN 	@TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency	
		WHERE
			b.winlostdate BETWEEN @FDate AND @TempToDate  AND
			b.bettype IN (2799) AND
			b.tpositiontaking<>0 AND
			b.statusID IN (111,112,113) AND
			m.sporttype = @SportId AND
			((@Liveindicator = 0 and b.livehomescore = 0)
			OR (@Liveindicator = 1 and b.livehomescore = 1)
			OR (@Liveindicator = 2))			
		GROUP BY  b.winlostdate, b.currency, b.matchid, m.matchid, m.homeid, m.awayid,b.bettype
	END		
	
END	
-- Get winlost by match 
CREATE NONCLUSTERED INDEX IX_tmpWinloss on #tmpWinloss (Currency)

SELECT * INTO #TempExchange
FROM Lrf_f_GetExchangeDaily(@FDate,@TDate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM #tmpWinloss)

SELECT
	b.matchid,	
	b.homeid,	
	b.awayid,
	--b.bettype,
	CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN b.bettype ELSE 0 END as bettype,
	CASE WHEN b.bettype BETWEEN 1101 AND 1199  THEN ISNULL(b.showtime,'') ELSE '' END AS ShowTime ,
	SUM(TurnOver)	AS Turnover,   
	SUM(Winlost)		AS Winlost,  
	SUM(LicenseeWL) AS LicenseeWL,
	SUM(Comm) AS Comm,
	SUM(PlayerComm) AS PlayerComm,
	SUM(AmtDueto3rd) AS AmtDueto3rd,
	SUM(Betcount)	AS Betcount,
	
	--BaseEUR  
	CAST(SUM(TurnOver*e.EUR) AS MONEY)	AS TurnoverEUR,   
	CAST(SUM(Winlost*e.EUR) AS MONEY)	AS WinlostEUR,  
	CAST(SUM(LicenseeWL*e.EUR) AS MONEY) AS LicenseeWLEUR,
	CAST(SUM(Comm * e.EUR) AS MONEY) AS CommEUR,
	CAST(SUM(PlayerComm * e.EUR) AS MONEY) AS PlayerCommEUR,
	CAST(SUM(AmtDueto3rd*e.EUR) AS MONEY) AS AmtDueto3rdEUR,
	-- baseUSD
	CAST(SUM(TurnOver*e.USD) AS MONEY)	AS TurnoverUSD,   
	CAST(SUM(Winlost*e.USD) AS MONEY)	AS WinlostUSD,  
	CAST(SUM(LicenseeWL*e.USD) AS MONEY) AS LicenseeWLUSD,
	CAST(SUM(Comm * e.USD) AS MONEY) AS CommUSD,
	CAST(SUM(PlayerComm * e.USD) AS MONEY) AS PlayerCommUSD,
	CAST(SUM(AmtDueto3rd*e.USD) AS MONEY) AS AmtDueto3rdUSD,
	-- baseGBP
	CAST(SUM(TurnOver*e.GBP) AS MONEY)	AS TurnoverGBP,   
	CAST(SUM(Winlost*e.GBP) AS MONEY)	AS WinlostGBP,  
	CAST(SUM(LicenseeWL*e.GBP) AS MONEY) AS LicenseeWLGBP,
	CAST(SUM(Comm * e.GBP) AS MONEY) AS CommGBP,
	CAST(SUM(PlayerComm * e.GBP) AS MONEY) AS PlayerCommGBP,
	CAST(SUM(AmtDueto3rd*e.GBP) AS MONEY) AS AmtDueto3rdGBP
	
FROM #tmpWinloss b  WITH (NOLOCK) 	
	INNER JOIN  #TempExchange e
	ON e.ExchangeDate = b.winlostdate  AND e.exchangeid = b.currency
group by b.matchid, b.homeid, b.awayid,CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN b.bettype ELSE 0 END ,CASE WHEN b.bettype BETWEEN 1101 AND 1199  THEN ISNULL(b.showtime,'') ELSE '' END

DROP TABLE #TempExchange
DROP TABLE #tmpWinloss
	
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_LiveReportWinlossByMatch] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_LiveReportWinlossByMatch] TO [vnteam]  