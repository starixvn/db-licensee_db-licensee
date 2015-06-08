ALTER PROCEDURE [dbo].[Lrf_BetList_SelWinloss_Mem]
	@LicenseeID 	INT,
	@UserID			INT,
	@CustID			INT,
	@FromDate		DATETIME,
	@ToDate			DATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@ShowSB			BIT = 0,
	@ShowRB			BIT = 0,
	@ShowNG			BIT = 0,
	@ShowBA			BIT = 0,
	@ShowLC			BIT = 0,
	@ShowVS			BIT = 0,
	@ShowCS   		BIT=0, -- RNG Casino
	@ShowBG   		BIT=0, -- Bingo 
	@ShowKN   		BIT=0, -- Keno
	@ShowMG			BIT=0, -- MicroGamming
	@ShowBT			BIT=0, -- Bet Trade
	@PageSize		INT=1000,
	@PageIndex		INT=1,
	@TotalRows INT=0 OUTPUT,
	@SumWinlost MONEY=0 OUTPUT,
	@SumWinlostUSD MONEY=0 OUTPUT,
	@SumWinlostEUR MONEY=0 OUTPUT,
	@SumWinlostGBP MONEY=0 OUTPUT,
	@SumLicenseeWL MONEY=0 OUTPUT,
	@SumLicenseeWLUSD MONEY=0 OUTPUT,
	@SumLicenseeWLEUR MONEY=0 OUTPUT,
	@SumLicenseeWLGBP MONEY=0 OUTPUT,
	@SumComm MONEY=0 OUTPUT,
	@SumCommUSD MONEY=0 OUTPUT,
	@SumCommEUR MONEY=0 OUTPUT,
	@SumCommGBP MONEY=0 OUTPUT,
	@SumPlayerComm MONEY=0 OUTPUT,
	@SumPlayerCommUSD MONEY=0 OUTPUT,
	@SumPLayerCommEUR MONEY=0 OUTPUT,
	@SumPLayerCommGBP MONEY=0 OUTPUT,
	@drawfilter SMALLINT = 1,
	@Langkey VARCHAR(10) = 'en-US',
	@currencyID INT =0 

AS

/*
Created: Henry 
Date: 2012-01-09
Task : Betlist for Licensee Winloss Report
DB: DBRPT/bodb02

Revisions:
	 -20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily  
	 - 20120319@Henry: show main transid for sub-ticket of system parlay 
	 - 20120529@Henry: enhance performance
	 - 20120703@Henry: add value to column hdp1, hdp2 for Number Game
	 - 20120717@Jim: add paging filter
	 - 20120723@Jim: add playercomm value 
	 - 20120816@Henry: add ShowLiveCasino 
	 - 20120911@Jim : add virtual sport
     - 20130123@Daniel: Change link server alias
	 - 20130204@Jim: support RNG Casino and Bingo product
	 - 20130514@Jim:Restrict permission of Licensee Users by currency
	 - 20130716@Jim: update matchid for RNG Casino and Bingo
	 - 20130809@Jim: offer Virtual Horse Racing 	
	 - 20140307@Hannah: offer Keno
	 - 20140630@Hannah: offer BetRadar and Sporting Solution
	 - 20140908@Jim: restrict Virtual Horse Racing bettype (hot fix  #22012)
	 - 20141128@winnie: change currency keenocean	
	 - 20150124@winnie: Add base currency GBP
	 - 20150406@Winnie: Add 60 bettypes Betradar & Apply matrix of sporttype & bettype 
	 - 20150515@Winnie: fix bug
	 - 20150604@Edward: Support MicroGamming
	 - 20150608@Edward: Support Bet Trade
Param's Explanation:
	+ @drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover only)

*/

SET NOCOUNT ON

declare @fdate DATETIME, @tdate datetime
select @fdate = @FromDate, @tdate = @ToDate


DECLARE @BetListByDateMem AS TABLE(
	Sporttype		INT,
	TransID			BIGINT,
	BetID			BIGINT,
	Bettype			INT,
	hdp1			SMALLMONEY, 
	hdp2			SMALLMONEY, 
	Modds			SMALLMONEY,
	OddsType		TINYINT,
	Odds			SMALLMONEY, 
	Stake MONEY, 
	Actual_Stake	MONEY,
	Betteam			NVARCHAR(20),
	Status			NVARCHAR(10),
	RefNO			BIGINT,	
	Transdate		DATETIME,
	Winlostdate		DATETIME,
	Winlost			MONEY,
	LicenseeWL		MONEY,
	comm			MONEY,
	playercomm  	MONEY,
	Liveindicator	BIT,
	Livehomescore	SMALLINT,
	Liveawayscore	SMALLINT,
	IP				NVARCHAR(15),
	LeagueID		INT,
	MatchID			INT,
	MatchCode		NVARCHAR(50),
	Race			NVARCHAR(20),
	HomeID			INT,
	AwayID			INT, 	
	Betstatus		NVARCHAR(50),
	isNeutral		BIT,
	virtualrate		float,
	isShowOTExRate	BIT,
	currency INT,
	showtime NVARCHAR(50) -- table - shoe - hand of Live Casino
	,betcheck		NVARCHAR(50)
)

DECLARE @TempBetList AS TABLE(
	TransID			BIGINT,
	BetID			BIGINT,
	Bettype			INT,
	hdp1			SMALLMONEY, 
	hdp2			SMALLMONEY, 
	Modds			SMALLMONEY,
	OddsType		TINYINT,
	Odds			SMALLMONEY, 
	Stake MONEY, 
	Actual_Stake	MONEY,
	Betteam			NVARCHAR(20),
	Status			NVARCHAR(10),
	RefNO			BIGINT,	
	Transdate		DATETIME,
	Winlostdate		DATETIME,
	Winlost			MONEY,
	LicenseeWL		MONEY,
	comm			MONEY,
	playercomm      MONEY,
	Liveindicator	BIT,
	Livehomescore	SMALLINT,
	Liveawayscore	SMALLINT,
	IP				NVARCHAR(50),
	currency 		INT,
	MatchID 		INT
	,betcheck		NVARCHAR(50)
)

Declare @TempFromDate DATETIME
Declare @TempToDate DATETIME

----Get Sport Bettype Matrix------
DECLARE @SportBettype TABLE(ProductID INT,Bettype INT,EventType INT)
INSERT INTO @SportBettype
EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode=4

IF @ShowBT = 0
BEGIN
	DELETE @SportBettype WHERE ProductID = 1 AND Bettype IN (901, 902, 903)
END


IF @tdate > @MoveBetsDay
BEGIN
	IF @fdate <= @MoveBetsDay 
		SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
	ELSE
		SET @TempFromDate = @fdate

	--Get BA Tickets
	INSERT INTO @TempBetList
	SELECT
		b.TransID,
		ISNULL(b.BetID,0),
		b.Bettype,
		b.hdp1, 
		b.hdp2,
		b.modds,
		b.OddsType,
		b.Odds,
		b.stake,
		b.actual_stake, 
		b.betteam, --Betteam
		b.status AS Status,				
		b.refno,
		b.Transdate,	
		b.winlostdate,			
		(b.winlost-actual_stake),
		0,
		CASE WHEN b.bettype = 903 THEN b.awinlost ELSE b.comm END AS comm,
		b.playercomm,
		b.Liveindicator,
		b.Livehomescore,
		b.Liveawayscore,
		b.IP AS IP,
		b.currency,
		b.matchid
		,b.betcheck AS betcheck
	FROM
		dbo.bettrans AS b WITH (NOLOCK)		
		INNER JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
	WHERE
		b.winlostdate BETWEEN @TempFromDate AND @tdate AND
		b.custid=@custid AND (@currencyID=0 OR b.currency= @currencyID ) AND
		b.statusID IN (111,112,113)

	IF @ShowBA = 1
	BEGIN
		--sport book
		INSERT INTO @BetListByDateMem
		SELECT
			m.Sporttype, 
			b.TransID,
			b.BetID,
			b.Bettype,
			b.hdp1, 
			b.hdp2,
			b.modds,
			b.oddstype,
			b.odds,
			b.stake,
			b.actual_stake, 
			b.betteam, --Betteam
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			b.Winlost,
			b.LicenseeWL,
			b.comm,
			b.playercomm,	
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			'' AS Race,
			m.HomeID,
			m.AwayID, 		
			m.Betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			0,0,
			b.currency,
			'' As ShowTime
			,b.betcheck AS betcheck
		FROM
			@TempBetList b
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid=m.matchid 
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype		
		WHERE
			sbt.ProductID=1  AND sbt.EventType=1-- sportbook
			--(b.bettype < 31 OR (b.Bettype BETWEEN 121 AND 999) OR (b.Bettype BETWEEN 1301 AND 1399)) AND
			--b.bettype <>10
			
		--	Outright
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype, --Sporttype
				b.TransID,
				b.BetID,
				b.Bettype,
				0 AS hdp1, 
				0 AS hdp2, 
				b.modds,
				0 AS OddsType, 
				b.Odds, 
				b.stake,
			    b.actual_stake,  
				'' AS Betteam, --Betteam
				b.Status,				
				b.refno,
				b.Transdate,	
				b.winlostdate,						
				b.Winlost,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator , 
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP AS IP,
				m.LeagueID,
				m.OrId,--0, --MatchID	
				m.MatchCode,
				m.GroupMatch,--Race
				m.TeamID, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				0,0,
				b.currency,
				'' As ShowTime
				,NULL AS betcheck
			FROM
				@TempBetList b		
				INNER JOIN dbo.Outright AS m WITH (NOLOCK) ON b.matchid=m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
			WHERE
				--b.bettype = 10
				sbt.ProductID=1 AND sbt.EventType=2

			--Mix Parlay + System Parlay
			INSERT INTO @BetListByDateMem
			SELECT
				0, --Sporttype
				CASE WHEN b.bettype <> 29 THEN b.transid
				ELSE CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END
				END AS transid,	
				b.BetID,
				b.bettype,
				b.hdp1, 
				b.hdp2, 
				modds,
				0 AS OddsType, 
				b.Odds, 
				b.stake,
				b.actual_stake, 
				b.betteam, --Betteam
				b.Status,				
				b.refno,
				b.Transdate,	
				b.winlostdate,						
				b.Winlost,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP AS IP,
				0, --LeagueID
				0, --MatchID	
				'',--MatchCode
				'',--Race
				0, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				0,0,
				b.currency,
				'' As ShowTime
				,NULL AS betcheck
			FROM
				@TempBetList b
				INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
			WHERE
				b.matchid IN (9,29) AND sbt.ProductID=1 AND sbt.EventType=0
				--b.bettype IN (9,29) AND
				--b.matchid IN (9,29)
	END

	--Sport Book
	IF @ShowSB = 1
	BEGIN
		INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				modds,
				b.OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,  
				b.betteam, --Betteam
				b.status AS Status,				
				b.refno,
				b.Transdate,	
				b.winlostdate,			
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake) ,
				CASE WHEN b.bettype = 903 THEN b.awinlost ELSE b.comm END AS comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP AS IP,
				m.LeagueID,
				m.MatchID,	
				m.MatchCode,
				'' AS Race,	
				m.HomeID,
				m.AwayID, 		
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,0,
				b.currency,
				'' As ShowTime
				,b.betcheck AS betcheck
			FROM
				dbo.bettrans AS b WITH (NOLOCK)		
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid=m.matchid 		
				INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate AND
				b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
				--(b.bettype < 31 OR (b.bettype BETWEEN 121 AND 999 ) OR (b.Bettype BETWEEN 1301 AND 1399))  AND
				--b.bettype NOT IN (9,29,10)	AND
				sbt.ProductID=1 AND sbt.EventType=1 AND
				b.matchid > 0 AND
				b.statusID IN (111,112,113) AND
				b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets
		
		-- Outright
		INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype, --Sporttype
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				0 AS hdp1, 
				0 AS hdp2, 
				modds,
				0 AS OddsType, 
				b.Odds, 
				b.stake,
				b.actual_stake, 
				'' AS Betteam, --Betteam
				b.Status,				
				b.refno,
				b.Transdate,	
				b.winlostdate,						
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
				b.comm ,
				b.playercomm,
				0 AS LiveIndicator , 
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP AS IP,
				m.LeagueID,
				m.OrId,--0, --MatchID	
				m.MatchCode,
				m.GroupMatch,--Race
				m.TeamID, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				0,0,
				b.currency,
				'' As ShowTime
				,NULL AS betcheck
			FROM
				dbo.bettrans AS b WITH (NOLOCK)		
				INNER JOIN dbo.Outright AS m WITH (NOLOCK) ON b.matchid=m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate AND
				b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
				--b.bettype = 10 AND
				sbt.ProductID=1 AND sbt.EventType=2 AND
				b.statusID IN (111,112,113) AND
				b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets
				

		-- Mix Parlay + System Parlay		
		INSERT INTO @BetListByDateMem
			SELECT
				0, --Sporttype
				CASE WHEN b.bettype <> 29 THEN b.transid
				ELSE CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END
				END AS transid,	
				ISNULL(b.BetID,0),
				b.bettype,
				b.hdp1, 
				b.hdp2, 
				modds,
				0 AS OddsType, 
				b.Odds, 
				b.stake,
				b.actual_stake, 
				b.betteam, --Betteam
				b.Status,				
				b.refno,
				b.Transdate,	
				b.winlostdate,						
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake) ,
				b.comm ,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP AS IP,
				0, --LeagueID
				0, --MatchID	
				'',--MatchCode
				'',--Race
				0, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				0,0,
				b.currency,
				'' As ShowTime
				,NULL AS betcheck
			FROM
				dbo.bettrans b WITH (NOLOCK)	
				INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate AND
				b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
				--b.bettype IN (9,29) AND
				sbt.ProductID=1 AND sbt.EventType=0 AND
				b.matchid IN (9,29) AND
				b.statusID IN (111,112,113) AND
				b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets
				
	END
	
	--Number Game
	IF @ShowNG = 1
	BEGIN
		INSERT INTO @BetListByDateMem
		SELECT
			m.Sporttype, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1 AS hdp1, 
			b.hdp2 AS hdp2,
			modds,
			b.oddstype,
			b.Odds,
			b.stake,
			b.actual_stake, 
			b.betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-actual_stake) ,
			b.comm ,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			'' AS Race,	
			m.HomeID,
			m.AwayID, 		
			m.Betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			0,0,
			b.currency,
			'' As ShowTime
			,NULL AS betcheck
		FROM
			dbo.bettrans AS b WITH (NOLOCK)		
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid=m.matchid 		
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @tdate AND
			b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
			--b.bettype BETWEEN 81 AND 120 AND
			sbt.ProductID=3 AND
			b.statusID IN (111,112,113)
		
	END
	
	--Live Casino
	IF @ShowLC=1
	BEGIN
		INSERT INTO @BetListByDateMem
		SELECT
			m.Sporttype, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1 AS hdp1, 
			b.hdp2 AS hdp2,
			modds,
			b.oddstype,
			b.Odds,
			b.stake,
			b.actual_stake, 
			b.betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-actual_stake) ,
			b.comm ,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			'' AS Race,	
			m.HomeID,
			m.AwayID, 		
			m.Betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			0,0,
			b.currency,
			isnull(m.showtime,'') as showtime
			,NULL AS betcheck
		FROM
			dbo.bettrans AS b WITH (NOLOCK)		
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid=m.matchid 		
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @tdate AND
			b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
			--b.bettype BETWEEN 1101 AND 1199 AND
			sbt.ProductID=4 AND
			b.statusID IN (111,112,113)
	END
	
	IF @ShowVS=1
	BEGIN
		INSERT INTO @BetListByDateMem
		SELECT
			m.Sporttype, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1 AS hdp1, 
			b.hdp2 AS hdp2,
			modds,
			b.oddstype,
			b.Odds,
			b.stake,
			b.actual_stake, 
			b.betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-actual_stake) ,
			b.comm ,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			'' AS Race,	
			m.HomeID,
			m.AwayID, 		
			m.Betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			0,0,
			b.currency,
			'' as showtime
			,NULL AS betcheck
		FROM
			dbo.bettrans AS b WITH (NOLOCK)		
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid=m.matchid
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @tdate AND
			b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
			sbt.ProductID=5 AND
			sbt.EventType=1 AND
			--b.bettype BETWEEN 1201 AND 1299 AND
			--b.bettype NOT IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype()) AND
			b.statusID IN (111,112,113)
		UNION ALL
		SELECT 
			r.sporttype,
			b.transid,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1 AS hdp1, 
			b.hdp2 AS hdp2,
			modds,
			b.oddstype,
			b.Odds,
			b.stake,
			b.actual_stake, 
			b.betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-actual_stake) ,
			b.comm ,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			r.LeagueID,
			o.EventID MatchID,	
			CONVERT(varchar(50),o.RacerNum) MatchCode,
			b.oddsid  AS Race,	
			o.RacerID HomeID,
			0 as AwayID, 		
			r.Betstatus,
			ISNULL(0, CONVERT(BIT,0)) AS IsNeutral,
			0,0,
			b.currency,
			CONVERT(VARCHAR(20),r.EventTime) as showtime
			,NULL AS betcheck
		FROM dbo.bettrans AS b WITH (NOLOCK)	
			INNER JOIN VSOutright o with (nolock) ON b.oddsid=o.Orid
			INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID	
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @tdate AND
			b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
			--b.bettype IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype()) AND
			sbt.ProductID=5 AND sbt.EventType=3 AND
			b.statusID IN (111,112,113)	

				
			
	END
	------- RNG Casino
	IF @ShowCS=1
	BEGIN
		INSERT INTO @BetListByDateMem
		SELECT
			251 as Sporttype, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1 AS hdp1, 
			b.hdp2 AS hdp2,
			modds,
			ISNULL(b.oddstype,0),
			b.Odds,
			b.stake,
			b.actual_stake, 
			ISNULL(b.betteam,0),
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-actual_stake) ,
			b.comm ,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0 LeagueID,
			71 MatchID,	
			0 MatchCode,
			'' AS Race,	
			0 HomeID,
			0 AwayID, 		
			0 Betstatus,
			 CONVERT(BIT,0) AS IsNeutral,
			0,0,
			b.currency,
			'' as showtime
			,NULL AS betcheck
		FROM
			dbo.bettrans AS b WITH (NOLOCK)		
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @tdate AND
			b.custid=@custid AND (@currencyID=0 OR b.currency= @currencyID ) AND
			--b.bettype =71 AND
			sbt.ProductID=6 AND
			b.statusID IN (111,112,113)
	END
	------- Bingo
		IF @ShowBG=1
	BEGIN
		INSERT INTO @BetListByDateMem
		SELECT
			252 Sporttype, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1 AS hdp1, 
			b.hdp2 AS hdp2,
			modds,
			ISNULL(b.oddstype,0),
			b.Odds,
			b.stake,
			b.actual_stake, 
			ISNULL(b.betteam,0),
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-actual_stake) ,
			b.comm ,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0 LeagueID,
			73 MatchID,	
			0 MatchCode,
			'' AS Race,	
			0 HomeID,
			0 AwayID, 		
			0 Betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			0,0,
			b.currency,
			'' as showtime
			,NULL AS betcheck
		FROM
			dbo.bettrans AS b WITH (NOLOCK)		
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @tdate AND
			b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
			--b.bettype =73 AND
			sbt.ProductID=7 AND
			b.statusID IN (111,112,113)
	END
	-- Horse Racing
	IF @ShowRB = 1
	BEGIN
		INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype, --Sporttype
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				modds,
				0 AS OddsType, 
				b.Odds, 
				b.stake,
				b.actual_stake,  
				'' AS Betteam, --Betteam
				b.Status,				
				b.refno,
				b.Transdate,	
				b.winlostdate,						
				(b.winlost-actual_stake),
				awinlost,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator , 
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP AS IP,
				m.LeagueID,
				m.OrId,--0, --MatchID	
				m.MatchCode,
				m.GroupMatch,--Race
				m.TeamID, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.virtualrate,
				isnumeric(m.programID),
				b.currency,
				'' As ShowTime
				,NULL AS betcheck
			FROM
				dbo.bettrans AS b WITH (NOLOCK)		
				INNER JOIN dbo.Outright AS m WITH (NOLOCK) ON b.matchid=m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate AND
				b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
				--b.bettype IN (31, 32, 33) AND
				sbt.ProductID=2 AND
				b.statusID IN (111,112,113)
				
	END
	-- Keno
	IF @ShowKN=1 -- 1
	BEGIN
		INSERT INTO @BetListByDateMem
		SELECT
			202 AS Sporttype, 
			b.transid AS transid,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1 AS hdp1, 
			b.hdp2 AS hdp2,
			b.modds,
			b.oddstype,
			b.Odds,
			b.stake,
			b.actual_stake, 
			ChoiceId AS betteam,
			b.status AS Status,				
			b.refno,
			b.transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-actual_stake) ,
			b.comm ,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0 AS LeagueID,
			GameId AS MatchID,	
			'' AS MatchCode,
			'' AS Race,	
			0 AS HomeID,
			0 AS AwayID, 		
			0 AS Betstatus,
			CONVERT(BIT, 0) AS IsNeutral,
			0,0,
			b.currency,
			'' AS showtime
			,NULL AS betcheck
		FROM
			dbo.bettrans AS b WITH (NOLOCK)		
			CROSS APPLY dbo.f_ParseTransDesc(b.transdesc, b.bettype)
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
					
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @tdate AND
			b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
			--b.bettype BETWEEN 1501 AND 1599 AND
			sbt.ProductID=8 AND
			b.statusID IN (111,112,113)
	END

	--MicroGamming
	IF @ShowMG=1
	BEGIN
		INSERT INTO @BetListByDateMem
		SELECT
			203 AS Sporttype, 
			b.transid AS transid,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1 AS hdp1, 
			b.hdp2 AS hdp2,
			b.modds,
			b.oddstype,
			b.Odds,
			b.stake,
			b.actual_stake, 
			'' AS betteam,
			b.status AS Status,				
			b.refno,
			b.transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-actual_stake) ,
			b.comm ,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0 AS LeagueID,
			0 AS MatchID,	
			'' AS MatchCode,
			'' AS Race,	
			0 AS HomeID,
			0 AS AwayID, 		
			0 AS Betstatus,
			CONVERT(BIT, 0) AS IsNeutral,
			0,0,
			b.currency,
			'' AS showtime
			,NULL AS betcheck
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
					
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @tdate AND
			b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
			sbt.ProductID=203 AND
			b.statusID IN (111,112,113)
	END
END

IF @fdate <= @MoveBetsDay
BEGIN
	IF @tdate >= @MoveBetsDay
		SET @TempToDate = @MoveBetsDay
	ELSE
		SET  @TempToDate = @tdate
	
	IF @BalanceUpDay < @fdate 
		SELECT @BalanceUpDay=@fdate

	--Get BA Tickets
	DELETE FROM @TempBetList
		
	INSERT INTO @TempBetList
	SELECT
		b.TransID,
		ISNULL(b.BetID,0),
		b.Bettype,
		b.hdp1, 
		b.hdp2,
		b.modds,
		b.OddsType,
		b.Odds,
		b.stake,
		b.actual_stake,  
		b.betteam, --Betteam
		b.status AS Status,				
		b.refno,
		b.Transdate,	
		b.winlostdate,			
		(b.winlost-actual_stake),
		0,
		CASE WHEN b.bettype = 903 THEN b.awinlost ELSE b.comm END AS comm,
		b.playercomm,
		b.Liveindicator,
		b.Livehomescore,
		b.Liveawayscore,
		b.IP AS IP,
		b.currency,
		b.matchid
		,b.betcheck AS betcheck
	FROM
		dbo.bettrans14 AS b WITH (NOLOCK)		
		INNER JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
	WHERE
		b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate AND
		b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
		b.statusID IN (111,112,113)
	

	IF @ShowBA = 1
	BEGIN
		--sport book
		INSERT INTO @BetListByDateMem
		SELECT
			m.Sporttype, 
			b.TransID,
			b.BetID,
			b.Bettype,
			b.hdp1, 
			b.hdp2,
			b.modds,
			b.oddstype,
			b.odds,
			b.stake,
			b.actual_stake,  
			b.betteam, --Betteam
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			b.Winlost,
			b.LicenseeWL,
			b.comm,	
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			'' AS Race,
			m.HomeID,
			m.AwayID, 		
			m.Betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			0,0,
			b.currency,
			'' As ShowTime
			,b.betcheck AS betcheck
		FROM
			@TempBetList b
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid=m.matchid 		
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
		WHERE
			--(b.bettype < 31 OR (b.Bettype BETWEEN 121 AND 999) OR (b.Bettype BETWEEN 1301 AND 1399)) AND
			--b.bettype <>10
			sbt.ProductID=1 AND sbt.EventType=1
			
		--	Outright
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype, --Sporttype
				b.TransID,
				b.BetID,
				b.Bettype,
				0 AS hdp1, 
				0 AS hdp2, 
				b.modds,
				0 AS OddsType, 
				b.Odds, 
				b.stake,
				b.actual_stake,   
				'' AS Betteam, --Betteam
				b.Status,				
				b.refno,
				b.Transdate,	
				b.winlostdate,						
				b.Winlost,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator , 
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP AS IP,
				m.LeagueID,
				m.OrId,--0, --MatchID	
				m.MatchCode,
				m.GroupMatch,--Race
				m.TeamID, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				0,0,
				b.currency,
				'' As ShowTime
				,NULL AS betcheck
			FROM
				@TempBetList b		
				INNER JOIN dbo.Outright14 AS m WITH (NOLOCK) ON b.matchid=m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
			WHERE
				--b.bettype = 10
				sbt.ProductID=1 AND sbt.EventType=2
				
			--Mix Parlay + System Parlay
			INSERT INTO @BetListByDateMem
			SELECT
				0, --Sporttype
				CASE WHEN b.bettype <> 29 THEN b.transid
				ELSE CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END
				END AS transid,	
				b.BetID,
				b.bettype,
				b.hdp1, 
				b.hdp2, 
				modds,
				0 AS OddsType, 
				b.Odds, 
				b.stake,
				b.actual_stake,  
				b.betteam, --Betteam
				b.Status,				
				b.refno,
				b.Transdate,	
				b.winlostdate,						
				b.Winlost,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP AS IP,
				0, --LeagueID
				0, --MatchID	
				'',--MatchCode
				'',--Race
				0, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				0,0,
				b.currency,
				'' As ShowTime
				,NULL AS betcheck
			FROM
				@TempBetList b
				INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
			WHERE
				--b.bettype IN (9,29) AND
				b.matchid IN (9,29) 
				AND sbt.ProductID=1 AND sbt.EventType=0
	END

	--Sport Book
	IF @ShowSB = 1
	BEGIN	
		INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				b.hdp1, 
				b.hdp2, 
				modds,
				b.Oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,  
				b.betteam, --Betteam
				b.status AS Status,				
				b.refno,
				b.Transdate,	
				b.winlostdate,						
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
				CASE WHEN b.bettype = 903 THEN b.awinlost ELSE b.comm END AS comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP AS IP,
				m.LeagueID,
				m.MatchID,	
				m.MatchCode,
				'' AS Race,	--Race
				m.HomeID,
				m.AwayID, 		
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,0,
				b.currency,
				'' As ShowTime
				,b.betcheck AS betcheck
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)		
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid=m.matchid 		
				INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype			
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate AND
				b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
				--(b.bettype < 31 OR (b.bettype BETWEEN 121 AND 999 ) OR (b.Bettype BETWEEN 1301 AND 1399)) AND
				--b.bettype NOT IN (9,29,10) AND
				sbt.ProductID=1 AND sbt.EventType=1 AND
				b.matchid>0 AND
				b.statusID IN (111,112,113) AND
				b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets
				

		-- Mix Parlay + System Parlay
		INSERT INTO @BetListByDateMem
			SELECT
				0, --Sporttype
				CASE WHEN b.bettype <> 29 THEN b.transid
				ELSE CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END
				END AS transid,	
				ISNULL(b.BetID,0),
				b.bettype,
				b.hdp1, 
				b.hdp2, 
				modds,
				0 AS OddsType, 
				b.Odds, 
				b.stake,
				b.actual_stake,   
				b.betteam, --Betteam
				b.Status,				
				b.refno,
				b.Transdate,	
				b.winlostdate,						
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
				b.comm ,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP AS IP,
				0, --LeagueID
				0, --MatchID
				'',--MatchCode
				'',--Race	
				0, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS isNeutral,
				0,0,
				b.currency,
				'' As ShowTime
				,NULL AS betcheck
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype	
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate AND
				b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
				--b.bettype IN (9,29) AND
				sbt.ProductID=1 AND sbt.EventType=0 AND
				b.matchid IN (9,29) AND
				b.statusID IN (111,112,113) AND
				b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets
			
		--outright		
		INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype, --Sporttype
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				0 AS hdp1, 
				0 AS hdp2, 
				modds,
				0 AS OddsType, 
				b.Odds, 
				b.stake,
				b.actual_stake,  
				'' AS Betteam, --Betteam
				b.Status,				
				b.refno,
				b.Transdate,	
				b.winlostdate,						
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
				b.comm,
				b.playercomm,
				0 AS LiveIndicator, 
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP AS IP,
				m.LeagueID,
				m.OrId,--0, --MatchID	
				m.MatchCode,
				m.GroupMatch AS Race,--Race
				m.TeamID, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS isNeutral,
				0,0,
				b.currency,
				'' As ShowTime
				,NULL AS betcheck
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)		
				INNER JOIN dbo.Outright14 AS m WITH (NOLOCK) ON b.matchid=m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate AND
				b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
				--b.bettype = 10 AND
				sbt.ProductID=1 AND sbt.EventType=2 AND
				b.statusID IN (111,112,113) AND
				b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets
				
	END	
	
	--Number Game
	IF @ShowNG = 1
	BEGIN
		INSERT INTO @BetListByDateMem
		SELECT
			m.Sporttype, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1 AS hdp1, 
			b.hdp2 AS hdp2,
			modds,
			b.Oddstype,
			b.Odds,
			b.stake,
			b.actual_stake,   		
			b.betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-actual_stake),
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			'' AS Race,	
			m.HomeID,
			m.AwayID, 		
			m.Betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			0,0,
			b.currency,
			'' As ShowTime
			,NULL AS betcheck
		FROM
			dbo.bettrans14 AS b WITH (NOLOCK)		
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid=m.matchid 		
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype	
		WHERE
			b.winlostdate BETWEEN @BalanceUpDay AND @tdate AND
			b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
			--(b.bettype BETWEEN 81 AND 120) AND
			sbt.ProductID=3 AND
			b.statusID IN (111,112,113)
	END
	
	--Live Casino
	IF @ShowLC = 1
	BEGIN
		INSERT INTO @BetListByDateMem
		SELECT
			m.Sporttype, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1 AS hdp1, 
			b.hdp2 AS hdp2,
			modds,
			b.Oddstype,
			b.Odds,
			b.stake,
			b.actual_stake,   		
			b.betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-actual_stake),
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			'' AS Race,	
			m.HomeID,
			m.AwayID, 		
			m.Betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			0,0,
			b.currency,
			isnull(m.showtime,'') as showtime
			,NULL AS betcheck
		FROM
			dbo.bettrans14 AS b WITH (NOLOCK)		
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid=m.matchid 	
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype		
		WHERE
			b.winlostdate BETWEEN @BalanceUpDay AND @tdate AND
			b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
			--b.bettype BETWEEN 1101 AND 1199 AND
			sbt.ProductID=4 AND
			b.statusID IN (111,112,113)
	END
	
	IF @ShowVS = 1
	BEGIN
		INSERT INTO @BetListByDateMem
		SELECT
			m.Sporttype, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1 AS hdp1, 
			b.hdp2 AS hdp2,
			modds,
			b.Oddstype,
			b.Odds,
			b.stake,
			b.actual_stake,   		
			b.betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-actual_stake),
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			'' AS Race,	
			m.HomeID,
			m.AwayID, 		
			m.Betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			0,0,
			b.currency,
			'' as showtime
			,NULL AS betcheck
		FROM
			dbo.bettrans14 AS b WITH (NOLOCK)		
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid=m.matchid 		
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype	
		WHERE
			b.winlostdate BETWEEN @BalanceUpDay AND @tdate AND
			b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
			--b.bettype BETWEEN 1201 AND 1299 AND
			--b.bettype NOT IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype()) AND
			sbt.ProductID=5 AND sbt.EventType=1 AND
			b.statusID IN (111,112,113)
	 UNION ALL
		SELECT 
			r.sporttype,
			b.transid,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1 AS hdp1, 
			b.hdp2 AS hdp2,
			modds,
			b.oddstype,
			b.Odds,
			b.stake,
			b.actual_stake, 
			b.betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-actual_stake) ,
			b.comm ,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			r.LeagueID,
			o.EventID MatchID,	
			convert(varchar(50),o.RacerNum) MatchCode,
			b.oddsid AS Race,	
			o.RacerID HomeID,
			0 as AwayID, 		
			r.Betstatus,
			ISNULL(0, CONVERT(BIT,0)) AS IsNeutral,
			0,0,
			b.currency,
			CONVERT(VARCHAR(20),r.EventTime) as showtime
			,NULL AS betcheck
		FROM dbo.bettrans14 AS b WITH (NOLOCK)	
			INNER JOIN VSOutright14 o with (nolock) ON b.oddsid=o.Orid
			INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype		
		WHERE
			b.winlostdate BETWEEN @BalanceUpDay AND @tdate AND
			b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
			--b.bettype IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype()) AND 
			sbt.ProductID=5 AND sbt.EventType=3 AND
			b.statusID IN (111,112,113)	
		
	END
	--- RNG Casino
	IF @ShowCS = 1
	BEGIN
		INSERT INTO @BetListByDateMem
		SELECT
			251 Sporttype, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1 AS hdp1, 
			b.hdp2 AS hdp2,
			modds,
			ISNULL(b.Oddstype,0),
			b.Odds,
			b.stake,
			b.actual_stake,   		
			ISNULL(b.betteam,0) ,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-actual_stake),
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0 LeagueID,
			71 MatchID,	
			0 MatchCode,
			'' AS Race,	
			0 HomeID,
			0 AwayID, 		
			0 Betstatus,
			 CONVERT(BIT,0) AS IsNeutral,
			0,0,
			b.currency,
			'' as showtime
			,NULL AS betcheck
		FROM
			dbo.bettrans14 AS b WITH (NOLOCK)		
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype		
		WHERE
			b.winlostdate BETWEEN @BalanceUpDay AND @tdate AND
			b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
			--b.bettype =71 AND
			sbt.ProductID=6 AND
			b.statusID IN (111,112,113)
	END
	----- Bingo
	IF @ShowBG = 1
	BEGIN
		INSERT INTO @BetListByDateMem
		SELECT
			252 Sporttype, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1 AS hdp1, 
			b.hdp2 AS hdp2,
			modds,
			ISNULL(b.Oddstype,0),
			b.Odds,
			b.stake,
			b.actual_stake,   		
			ISNULL(b.betteam,0),
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-actual_stake),
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0 LeagueID,
			73 MatchID,	
			0 MatchCode,
			'' AS Race,	
			0 HomeID,
			0 AwayID, 		
			0 Betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			0,0,
			b.currency,
			'' as showtime
			,NULL AS betcheck
		FROM
			dbo.bettrans14 AS b WITH (NOLOCK)		
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype		
		WHERE
			b.winlostdate BETWEEN @BalanceUpDay AND @tdate AND
			b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
			--b.bettype =73 AND
			sbt.ProductID=7 AND
			b.statusID IN (111,112,113)
	END
	--Horse Racing
	IF @ShowRB = 1
	BEGIN
		INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype, --Sporttype
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				b.hdp1, 
				b.hdp2, 
				modds,
				0 AS OddsType, 
				b.Odds, 
				b.stake,
				b.actual_stake,   
				'' AS Betteam, --Betteam
				b.Status,				
				b.refno,
				b.Transdate,	
				b.winlostdate,						
				(b.winlost-actual_stake),
				awinlost,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator, 
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP AS IP,
				m.LeagueID,
				m.OrId,--0, --MatchID	
				m.MatchCode,
				m.GroupMatch AS Race,--Race
				m.TeamID, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS isNeutral,
				b.virtualrate,
				isnumeric(m.programID),
				b.currency,
				'' As ShowTime
				,NULL AS betcheck
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)		
				INNER JOIN dbo.Outright14 AS m WITH (NOLOCK) ON b.matchid=m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype	
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate AND
				b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
				--b.bettype IN (31, 32, 33) AND
				sbt.ProductID=2 AND
				b.statusID IN (111,112,113)
				
	END
	-- Keno 
	IF @ShowKN = 1
	BEGIN
		INSERT INTO @BetListByDateMem
		SELECT
			202 AS Sporttype, 
			b.transid as transid,
			ISNULL(b.BetID,0),
			b.Bettype,
			0 AS hdp1, 
			0 AS hdp2,
			b.modds,
			b.Oddstype,
			b.Odds,
			b.stake,
			b.actual_stake,   		
			ChoiceID AS betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-actual_stake),
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0 AS LeagueID,
			GameId AS MatchID,	
			'' AS MatchCode,
			'' AS Race,	
			0 AS HomeID,
			0 AS AwayID, 		
			0 AS Betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			0,0,
			b.currency,
			'' AS showtime
			,NULL AS betcheck
		FROM
			dbo.bettrans14 AS b WITH (NOLOCK)		
			CROSS APPLY dbo.f_ParseTransDesc(b.transdesc, b.bettype)
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
		WHERE
			b.winlostdate BETWEEN @BalanceUpDay AND @tdate AND
			b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
			--b.bettype BETWEEN 1501 AND 1599 AND
			sbt.ProductID=8 AND
			b.statusID IN (111,112,113)
	END

	--MicroGamming
	IF @ShowMG = 1
	BEGIN
		INSERT INTO @BetListByDateMem
		SELECT
			203 AS Sporttype, 
			b.transid as transid,
			ISNULL(b.BetID,0),
			b.Bettype,
			0 AS hdp1, 
			0 AS hdp2,
			b.modds,
			b.Oddstype,
			b.Odds,
			b.stake,
			b.actual_stake,   		
			'' AS betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-actual_stake),
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0 AS LeagueID,
			0 AS MatchID,	
			'' AS MatchCode,
			'' AS Race,	
			0 AS HomeID,
			0 AS AwayID, 		
			0 AS Betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			0,0,
			b.currency,
			'' AS showtime
			,NULL AS betcheck
		FROM
			dbo.bettrans14 AS b WITH (NOLOCK)		
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
		WHERE
			b.winlostdate BETWEEN @BalanceUpDay AND @tdate AND
			b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
			sbt.ProductID=203 AND
			b.statusID IN (111,112,113)
	END
END		
IF @fdate < @BalanceUpDay
BEGIN
	IF @tdate >= DATEADD(dd, -1, @BalanceUpDay)
		SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
	ELSE
		SET @TempToDate = @tdate
	
	DELETE FROM @TempBetList
		
	--Get BA Tickets
	INSERT INTO @TempBetList
	SELECT
		b.TransID,
		ISNULL(b.BetID,0),
		b.Bettype,
		b.hdp1, 
		b.hdp2,
		b.modds,
		b.OddsType,
		b.Odds,
		b.stake,
		b.actual_stake,  
		b.betteam, --Betteam
		b.status AS Status,				
		b.refno,
		b.Transdate,	
		b.winlostdate,			
		(b.winlost-actual_stake),
		0,
		CASE WHEN b.bettype = 903 THEN b.awinlost ELSE b.comm END AS comm,
		b.playercomm,
		b.Liveindicator,
		b.Livehomescore,
		b.Liveawayscore,
		b.IP AS IP,
		b.currency,
		b.matchid
		,b.betcheck AS betcheck
	FROM
		bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)		
		INNER JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
	WHERE
		b.winlostdate BETWEEN @fdate AND @TempToDate AND
		b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
		b.ruben = 1 AND
		b.status NOT IN ('VOID','REJECT','REFUND')
	
	IF @ShowBA = 1
	BEGIN
		--sport book
		INSERT INTO @BetListByDateMem
		SELECT
			m.Sporttype, 
			b.TransID,
			b.BetID,
			b.Bettype,
			b.hdp1, 
			b.hdp2,
			b.modds,
			b.oddstype,
			b.odds,
			b.stake,
			b.actual_stake,  
			b.betteam, --Betteam
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			b.Winlost,
			b.LicenseeWL,
			b.comm,	
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			'' AS Race,
			m.HomeID,
			m.AwayID, 		
			m.Betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			0,0,
			b.currency,
			'' As ShowTime
			,b.betcheck AS betcheck
		FROM
			@TempBetList b
			INNER JOIN bodb_archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid=m.matchid 	
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype	
		WHERE
			--(b.bettype < 31 OR (b.Bettype BETWEEN 121 AND 999) OR (b.Bettype BETWEEN 1301 AND 1399)) AND
			--b.bettype NOT IN (9,29,10)
			sbt.ProductID=1 AND sbt.EventType=1
			
		--	Outright
		INSERT INTO @BetListByDateMem
		SELECT
			l.sporttype, --Sporttype
			b.TransID,
			b.BetID,
			b.Bettype,
			0 AS hdp1, 
			0 AS hdp2, 
			b.modds,
			0 AS OddsType, 
			b.Odds, 
			b.stake,
			b.actual_stake,  
			'' AS Betteam, --Betteam
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			b.Winlost,
			b.LicenseeWL,
			b.comm,
			b.playercomm,
			0 AS LiveIndicator , 
			b.LiveHomescore, 
			b.LiveAwayscore,
			b.IP AS IP,
			m.LeagueID,
			m.OrId,--0, --MatchID	
			m.MatchCode,
			m.GroupMatch,--Race
			m.TeamID, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) AS IsNeutral,
			0,0,
			b.currency,
			'' As ShowTime
			,NULL AS betcheck
		FROM
			@TempBetList b		
			INNER JOIN bodb_archive.dbo.Outright_bk AS m WITH (NOLOCK) ON b.matchid=m.orid
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID		
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype	
		WHERE
			--b.bettype = 10
			sbt.ProductID=1 AND sbt.EventType=2
			
		--Mix Parlay + System parlay
		INSERT INTO @BetListByDateMem
		SELECT
			0, --Sporttype
			CASE WHEN b.bettype <> 29 THEN b.transid
				ELSE CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END
				END AS transid,	
			b.BetID,
			b.bettype,
			b.hdp1, 
			b.hdp2, 
			modds,
			0 AS OddsType, 
			b.Odds, 
			b.stake,
			b.actual_stake,   
			b.betteam, --Betteam
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			b.Winlost,
			b.LicenseeWL,
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0, --LeagueID
			0, --MatchID	
			'',--MatchCode
			'',--Race
			0, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) AS IsNeutral,
			0,0,
			b.currency,
			'' As ShowTime
			,NULL AS betcheck
		FROM
			@TempBetList b
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
		WHERE
			--b.bettype IN (9,29) AND
			sbt.ProductID=1 AND sbt.EventType=0 AND
			b.matchid IN (9,29)		
	END
		
	--Sport Book
	IF @ShowSB = 1
	BEGIN
		INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				modds,
				b.Oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,  
				b.betteam, --Betteam
				b.status AS Status,				
				b.refno,
				b.Transdate,	
				b.winlostdate,			
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
				CASE WHEN b.bettype = 903 THEN b.awinlost ELSE b.comm END AS comm,
			    b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP AS IP,
				m.LeagueID,
				m.MatchID,	
				m.MatchCode,
				'' AS Race,	
				m.HomeID,
				m.AwayID, 		
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,0,
				b.currency,
				'' As ShowTime
				,b.betcheck AS betcheck
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)		
				INNER JOIN bodb_archive.dbo.match_BK AS m WITH (NOLOCK) ON b.matchid=m.matchid 		
				INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate AND
				b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
				b.ruben = 1 AND
				b.status NOT IN ('VOID', 'REJECT', 'REFUND') AND 
				--(b.bettype < 31 OR (b.bettype BETWEEN 121 AND 999) OR (b.Bettype BETWEEN 1301 AND 1399)) AND
				--b.bettype NOT IN (9,29, 10) AND
				sbt.ProductID=1 AND sbt.EventType=1 AND
				b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets
				
		
		-- Outright
		INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype, --Sporttype
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				0 AS hdp1, 
				0 AS hdp2, 
				modds,
				0 AS OddsType, 
				b.Odds, 
				b.stake,
				b.actual_stake,  
				'' AS Betteam, --Betteam
				b.Status,				
				b.refno,
				b.Transdate,	
				b.winlostdate,						
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
				b.comm,
			    b.playercomm,
				0 AS LiveIndicator , 
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP AS IP,
				m.LeagueID,
				m.OrId,--0, --MatchID	
				m.MatchCode,
				m.GroupMatch,--Race
				m.TeamID, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				0,0,
				b.currency,
				'' As ShowTime
				,NULL AS betcheck
			FROM
				bodb_archive.dbo.bettrans_bk  AS b WITH (NOLOCK)		
				INNER JOIN bodb_archive.dbo.Outright_bk AS m WITH (NOLOCK) ON b.matchid=m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate AND
				b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
				b.ruben = 1 AND
				b.status NOT IN ('VOID', 'REJECT', 'REFUND') AND 
				--b.bettype = 10 AND
				sbt.ProductID=1 AND sbt.EventType=2 AND
				b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets

		-- Mix Parlay	+ System Parlay	
		INSERT INTO @BetListByDateMem
			SELECT
				0, --Sporttype
				CASE WHEN b.bettype <> 29 THEN b.transid
				ELSE CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END
				END AS transid,	
				ISNULL(b.BetID,0),
				b.bettype,
				b.hdp1, 
				b.hdp2, 
				modds,
				0 AS OddsType, 
				b.Odds, 
				b.stake,
				b.actual_stake,   
				b.betteam, --Betteam
				b.Status,				
				b.refno,
				b.Transdate,	
				b.winlostdate,						
				(b.winlost-actual_stake),
				 - (b.winlost-actual_stake) ,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP AS IP,
				0, --LeagueID
				0, --MatchID	
				'',--MatchCode
				'',--Race
				0, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				0,0,
				b.currency,
				'' As ShowTime
				,NULL AS betcheck
			FROM
				bodb_archive.dbo.bettrans_bk b WITH (NOLOCK)	
				INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate AND
				b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
				b.ruben = 1 AND 
				b.status NOT IN ('VOID', 'REJECT','REFUND') AND
				sbt.ProductID=1 AND sbt.EventType=0 AND
				--b.bettype IN (9,29) AND
				--b.matchid = 0
				b.matchid IN (0,9,29) AND --should NOT remove 0 IN archive
				b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets
	END
	
	--Number game
	IF @ShowNG = 1
	BEGIN
		INSERT INTO @BetListByDateMem
		SELECT
		m.Sporttype, 
		b.TransID,
		ISNULL(b.BetID,0),
		b.Bettype,
		b.hdp1 AS hdp1, 
		b.hdp2 AS hdp2,
		modds,
		b.Oddstype,
		b.Odds,
		b.stake,
		b.actual_stake,  		
		b.betteam,
		b.status AS Status,				
		b.refno,
		b.Transdate,	
		b.winlostdate,			
		(b.winlost-actual_stake),
		- (b.winlost-actual_stake),
		b.comm,
		b.playercomm,
		b.Liveindicator,
		b.Livehomescore,
		b.Liveawayscore,
		b.IP AS IP,
		m.LeagueID,
		m.MatchID,	
		m.MatchCode,
		'' AS Race,	
		m.HomeID,
		m.AwayID, 		
		m.Betstatus,
		ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
		0,0,
		b.currency,
		'' As ShowTime
		,NULL AS betcheck
	FROM
		bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)		
		INNER JOIN bodb_archive.dbo.match_BK AS m WITH (NOLOCK) ON b.matchid=m.matchid 
		INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype		
	WHERE
		b.winlostdate BETWEEN @fdate AND @TempToDate AND
		b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
		--b.bettype BETWEEN 81 AND 120 AND
		sbt.ProductID=3 AND
		b.ruben = 1 AND
		b.status NOT IN ('VOID', 'REJECT', 'REFUND')
	END
	
	--Live Casino
	IF @ShowLC = 1
	BEGIN
		INSERT INTO @BetListByDateMem
		SELECT
			m.Sporttype, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1 AS hdp1, 
			b.hdp2 AS hdp2,
			modds,
			b.Oddstype,
			b.Odds,
			b.stake,
			b.actual_stake,  		
			b.betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-actual_stake),
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			'' AS Race,	
			m.HomeID,
			m.AwayID, 		
			m.Betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			0,0,
			b.currency,
			isnull(m.showtime,'') as showtime
			,NULL AS betcheck
		FROM
			bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)		
			INNER JOIN bodb_archive.dbo.match_BK AS m WITH (NOLOCK) ON b.matchid=m.matchid 		
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
		WHERE
			b.winlostdate BETWEEN @fdate AND @TempToDate AND
			b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
			--b.bettype BETWEEN 1101 AND 1199 AND
			sbt.ProductID=4 AND
			b.ruben = 1 AND
			b.status NOT IN ('VOID', 'REJECT', 'REFUND')
	END
	
	IF @ShowVS = 1
	BEGIN
		INSERT INTO @BetListByDateMem
		SELECT
			m.Sporttype, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1 AS hdp1, 
			b.hdp2 AS hdp2,
			modds,
			b.Oddstype,
			b.Odds,
			b.stake,
			b.actual_stake,  		
			b.betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-actual_stake),
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			'' AS Race,	
			m.HomeID,
			m.AwayID, 		
			m.Betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			0,0,
			b.currency,
			'' as showtime
			,NULL AS betcheck
		FROM
			bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)		
			INNER JOIN bodb_archive.dbo.match_BK AS m WITH (NOLOCK) ON b.matchid=m.matchid 		
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
		WHERE
			b.winlostdate BETWEEN @fdate AND @TempToDate AND
			b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
			--b.bettype BETWEEN 1201 AND 1299 AND
			--b.bettype NOT IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype()) AND
			sbt.ProductID=5 AND sbt.EventType=1 AND
			b.ruben = 1 AND
			b.status NOT IN ('VOID', 'REJECT', 'REFUND')
		UNION ALL
		SELECT 
			r.sporttype,
			b.transid,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1 AS hdp1, 
			b.hdp2 AS hdp2,
			modds,
			b.oddstype,
			b.Odds,
			b.stake,
			b.actual_stake, 
			b.betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-actual_stake) ,
			b.comm ,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			r.LeagueID,
			o.EventID MatchID,	
			convert(varchar(50),o.RacerNum) MatchCode,
			b.oddsid AS Race,	
			o.RacerID HomeID,
			0 as AwayID, 		
			r.Betstatus,
			ISNULL(0, CONVERT(BIT,0)) AS IsNeutral,
			0,0,
			b.currency,
			CONVERT(VARCHAR(20),r.EventTime) as showtime
			,NULL AS betcheck
		FROM bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)	
			INNER JOIN DBARC.bodb_Archive.dbo.VSOutright_bk o with (nolock) ON b.oddsid=o.Orid
			INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID	
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
		WHERE
			b.winlostdate BETWEEN @fdate AND @TempToDate AND
			b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
			--b.bettype IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype()) AND
			sbt.ProductID=5 AND sbt.EventType=3 AND
			b.statusID IN (111,112,113)		
	END
	---- RNG Casino
	
	IF @ShowCS = 1
	BEGIN
		INSERT INTO @BetListByDateMem
		SELECT
			251 Sporttype, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1 AS hdp1, 
			b.hdp2 AS hdp2,
			modds,
			ISNULL(b.Oddstype,0),
			b.Odds,
			b.stake,
			b.actual_stake,  		
			ISNULL(b.betteam,0) ,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-actual_stake),
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0 LeagueID,
			71 MatchID,	
			0 MatchCode,
			'' AS Race,	
			0 HomeID,
			0 AwayID, 		
			0 Betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			0,0,
			b.currency,
			'' as showtime
			,NULL AS betcheck
		FROM
			bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)		
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype	
		WHERE
			b.winlostdate BETWEEN @fdate AND @TempToDate AND
			b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
			--b.bettype =71  AND
			sbt.ProductID=6 AND
			b.ruben = 1 AND
			b.status NOT IN ('VOID', 'REJECT', 'REFUND')
	END
	-----Bingo
	IF @ShowBG = 1
	BEGIN
		INSERT INTO @BetListByDateMem
		SELECT
			252 Sporttype, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1 AS hdp1, 
			b.hdp2 AS hdp2,
			modds,
			ISNULL(b.Oddstype,0),
			b.Odds,
			b.stake,
			b.actual_stake,  		
			ISNULL(b.betteam,0),
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-actual_stake),
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0 LeagueID,
			73 MatchID,	
			0 MatchCode,
			'' AS Race,	
			0 HomeID,
			0 AwayID, 		
			0 Betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			0,0,
			b.currency,
			'' as showtime
			,NULL AS betcheck
		FROM
			bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)		
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype	
		WHERE
			b.winlostdate BETWEEN @fdate AND @TempToDate AND
			b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
			--b.bettype =73  AND
			sbt.ProductID=7 AND
			b.ruben = 1 AND
			b.status NOT IN ('VOID', 'REJECT', 'REFUND')
	END	
	
	-- Racebook
	IF @ShowRB = 1
	BEGIN
		INSERT INTO @BetListByDateMem
		SELECT
			l.sporttype, --Sporttype
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1, 
			b.hdp2,
			modds,
			0 AS OddsType, 
			b.Odds, 
			b.stake,
			b.actual_stake,   
			'' AS Betteam, --Betteam
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			(b.winlost-actual_stake),
			awinlost,
			b.comm,	
		    b.playercomm,
			0 AS LiveIndicator , 
			b.LiveHomescore, 
			b.LiveAwayscore,
			b.IP AS IP,
			m.LeagueID,
			m.OrId,--0, --MatchID	
			m.MatchCode,
			m.GroupMatch,--Race
			m.TeamID, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) AS IsNeutral,
			b.virtualrate,
			isnumeric(m.programID),
			b.currency,
			'' As ShowTime
			,NULL AS betcheck
		FROM
			bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)		
			INNER JOIN bodb_archive.dbo.Outright_bk AS m WITH (NOLOCK) ON b.matchid=m.orid
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
		WHERE
			b.winlostdate BETWEEN @fdate AND @TempToDate AND
			b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
			b.ruben = 1 AND 
			b.status NOT IN ('VOID','REJECT','REFUND') AND
			--b.bettype IN (31, 32, 33)
			sbt.ProductID=2
	END	
	-- Keno
	IF @ShowKN = 1
	BEGIN
		INSERT INTO @BetListByDateMem
		SELECT
			202 AS Sporttype, 
			b.transid AS transid,
			ISNULL(b.BetID,0),
			b.Bettype,
			0 AS hdp1, 
			0 AS hdp2,
			b.modds,
			b.Oddstype,
			b.Odds,
			b.stake,
			b.actual_stake,  		
			ChoiceID AS betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-actual_stake),
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0 AS LeagueID,
			GameId AS MatchID,	
			'' AS MatchCode,
			'' AS Race,	
			0 AS HomeID,
			0 AS AwayID, 		
			0 AS Betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			0,0,
			b.currency,
			'' AS showtime
			,NULL AS betcheck
		FROM
			bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)		
			CROSS APPLY dbo.f_ParseTransDesc(b.transdesc, b.bettype)
			 INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
		WHERE
			b.winlostdate BETWEEN @fdate AND @TempToDate AND
			b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
			--b.bettype BETWEEN 1501 AND 1599 AND
			sbt.ProductID=8 AND
			b.ruben = 1 AND
			b.status NOT IN ('VOID', 'REJECT', 'REFUND')
	END

	--MicroGamming
	IF @ShowMG = 1
	BEGIN
		INSERT INTO @BetListByDateMem
		SELECT
			203 AS Sporttype, 
			b.transid AS transid,
			ISNULL(b.BetID,0),
			b.Bettype,
			0 AS hdp1, 
			0 AS hdp2,
			b.modds,
			b.Oddstype,
			b.Odds,
			b.stake,
			b.actual_stake,  		
			'' AS betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-actual_stake),
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0 AS LeagueID,
			0 AS MatchID,	
			'' AS MatchCode,
			'' AS Race,	
			0 AS HomeID,
			0 AS AwayID, 		
			0 AS Betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			0,0,
			b.currency,
			'' AS showtime
			,NULL AS betcheck
		FROM
			bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)		
			 INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
		WHERE
			b.winlostdate BETWEEN @fdate AND @TempToDate AND
			b.custid=@custid AND  (@currencyID=0 OR b.currency= @currencyID ) AND
			sbt.ProductID=203 AND
			b.ruben = 1 AND
			b.status NOT IN ('VOID', 'REJECT', 'REFUND')
	END
END

IF @ShowBT = 1
BEGIN
	UPDATE betList
	SET betList.Odds	= originBetList.Odds
		,betList.Stake	= originBetList.Stake
		,betList.comm	= CASE WHEN betList.Bettype = 902 THEN commBetList.comm ELSE betList.comm END
	FROM @BetListByDateMem AS betList
		INNER JOIN @BetListByDateMem AS originBetList ON betList.RefNO = originBetList.TransID
		INNER JOIN @BetListByDateMem AS commBetList ON betList.RefNO = commBetList.RefNO
	WHERE betList.Sporttype = 1 AND betList.Bettype IN (901, 902)
		AND commBetList.Bettype = 903

	DELETE @BetListByDateMem WHERE Sporttype = 1 AND Bettype = 903
END

--@currency
SELECT CurrencyID
	,LicenseeID
INTO #Currency
FROM  DBLIC.bodb_licensee.dbo.CurrencyUser WITH (NOLOCK)
WHERE  usrID=@userID 
	AND LicenseeID=@LicenseeID 
	AND SystemID=1
	AND isActive=1
	
	
--DECLARE	@currency INT 
--SELECT	@currency = currency 
--FROM custinfo c (NOLOCK) 
--INNER JOIN 	#currency cy ON c.currency=cy.currencyID
--WHERE custid = @custid


--FROM  OPENQUERY(DBLIC, 'SELECT * FROM bodb_licensee.dbo.f_SelLicenseeCust(0)') lc
---------------------------------------
--DROP TABLE #currency
---------------------------------------


SELECT * INTO #TempExchange 
FROM Lrf_f_GetExchangeDaily(@FDate,@TDate)
WHERE exchangeid IN 
(
SELECT  DISTINCT lc.Currency   
				FROM  OPENQUERY(DBLIC, 'SELECT * FROM bodb_licensee.dbo.f_SelLicenseeCust(0)') lc
						INNER JOIN  #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID 
)
---------------------------------------
DROP TABLE #currency
---------------------------------------

--exclude draw for no draw option (2)
DELETE FROM @BetListByDateMem
WHERE @drawfilter = 2 AND status = 'DRAW' AND ABS(modds) <> 0.25

DECLARE @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1


SELECT 
	@TotalRows = count(transid),
	@SumWinlost=SUM(ISNULL(winlost,0)),
	@SumLicenseeWL=SUM(ISNULL(LicenseeWL,0)),
	@SumComm=SUM(ISNULL(comm,0)),
	@SumPlayerComm=SUM(ISNULL(playercomm,0)),
	--USD
	@SumWinlostUSD=SUM(ISNULL(winlost*e.USD,0)),
	@SumLicenseeWLUSD=SUM(ISNULL(LicenseeWL*e.USD,0)),
	@SumCommUSD=SUM(ISNULL(comm*e.USD,0)) ,
	@SumPlayerCommUSD=SUM(ISNULL(playercomm*e.USD,0)),
	--EUR
	@SumWinlostEUR=SUM(ISNULL(winlost*e.EUR,0)),
	@SumLicenseeWLEUR=SUM(ISNULL(LicenseeWL*e.EUR,0)),
	@SumCommEUR=SUM(ISNULL(comm*e.EUR,0)),
	@SumPlayerCommEUR=SUM(ISNULL(playercomm*e.EUR,0)),
	--GBP
	@SumWinlostGBP=SUM(ISNULL(winlost*e.GBP,0)),
	@SumLicenseeWLGBP=SUM(ISNULL(LicenseeWL*e.GBP,0)),
	@SumCommGBP=SUM(ISNULL(comm*e.GBP,0)),
	@SumPlayerCommGBP=SUM(ISNULL(playercomm*e.GBP,0))		
FROM @BetListByDateMem b
INNER JOIN 
	#TempExchange e 
	ON e.ExchangeDate = b.winlostdate   AND e.exchangeid = b.currency

SELECT A.*
FROM 
	(	
	SELECT	ROW_NUMBER () OVER (ORDER BY TransID) AS RowNum,
			d.* , 
			--BASE RM
			d.stake*e.MYR		AS	StakeMYR,
			d.actual_stake*e.MYR		AS	actual_stakeMYR,
			d.winlost*e.MYR		AS	WinlostMYR,
			d.LicenseeWL*e.MYR	AS	LicenseeWLMYR,
			d.comm*e.MYR		AS	commMYR,
			d.playercomm*e.MYR  AS playercommMYR,
			--BASEUSD
			d.stake*e.USD			AS	StakeUSD,
			d.actual_stake*e.USD	AS	actual_stakeUSD,
			d.winlost*e.USD			AS	WinlostUSD,
			d.LicenseeWL*e.USD		AS	LicenseeWLUSD,
			d.comm*e.USD			AS	commUSD,
			d.playercomm*e.USD 		AS playercommUSD,
			--BASEEUR
			d.stake*e.EUR			AS	StakeEUR,
			d.actual_stake*e.EUR	AS	actual_stakeEUR,
			d.winlost*e.EUR			AS	WinlostEUR,
			d.LicenseeWL*e.EUR		AS	LicenseeWLEUR,
			d.comm*e.EUR			AS	commEUR,
			d.playercomm*e.EUR	    AS playercommEUR,
			--BASEGBP
			d.stake*e.GBP			AS	StakeGBP,
			d.actual_stake*e.GBP	AS	actual_stakeGBP,
			d.winlost*e.GBP			AS	WinlostGBP,
			d.LicenseeWL*e.GBP		AS	LicenseeWLGBP,
			d.comm*e.GBP			AS	commGBP,
			d.playercomm*e.GBP	    AS playercommGBP 	

	FROM	@BetListByDateMem d 
			INNER JOIN #TempExchange e 
			ON e.ExchangeDate =  d.winlostdate AND e.exchangeid = d.currency
	) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

DECLARE @BettransDetail TABLE(  
	refno BIGINT,  
	odds SMALLMONEY,  
	stake MONEY,
	status NVARCHAR(10),  
	apositiontaking SMALLMONEY,  
	bettype SMALLINT,
	Betteam nvarchar (10),
	stakeEUR MONEY,
	stakeUSD MONEY,
	stakeGBP MONEY
	 )   


IF @ShowRB = 1
BEGIN
	IF @tdate > @MoveBetsDay 
	BEGIN
		INSERT INTO @BettransDetail
		SELECT 
			BM.refno, 
			BM.odds, 
			BM.stake,
			BM.status, 
			BM.apositiontaking, 
			BM.bettype  ,
			BM.Betteam,
			BM.stake * e.EUR,
			BM.stake * e.USD,
			BM.stake * e.GBP
		FROM bettransm BM WITH (NOLOCK)
		INNER JOIN @BetListByDateMem B ON BM.refno = B.transid
		INNER JOIN #TempExchange e ON e.ExchangeDate = b.winlostdate   AND e.exchangeid = b.currency
		INNER JOIN @SportBettype sbt ON bm.Bettype=sbt.Bettype
		WHERE sbt.ProductID=2 --B.Bettype IN (33,43)
	END
		
	IF @fdate <= @MoveBetsDay
	BEGIN
		INSERT INTO @BettransDetail
		SELECT 
			BM.refno, 
			BM.odds, 
			BM.stake,
			BM.status, 
			BM.apositiontaking, 
			BM.bettype  ,
			BM.Betteam,
			BM.stake * e.EUR,  
			BM.stake * e.USD,
			BM.stake * e.GBP
		FROM bettransm14 BM WITH (NOLOCK)
		INNER JOIN @BetListByDateMem B ON BM.refno = B.transid
		INNER JOIN #TempExchange e ON e.ExchangeDate = b.winlostdate   AND e.exchangeid = b.currency
		INNER JOIN @SportBettype sbt ON bm.Bettype=sbt.Bettype
		WHERE sbt.ProductID=2--B.Bettype IN (33,43)
	END	
	IF @fdate < @BalanceUpDay
	BEGIN
		INSERT INTO @BettransDetail
		SELECT 
			BM.refno, 
			BM.odds, 
			BM.stake,
			BM.status, 
			BM.apositiontaking, 
			BM.bettype  ,
			BM.Betteam,
			BM.stake * e.EUR,  
			BM.stake * e.USD,
			BM.stake * e.GBP
		FROM bodb_archive.dbo.bettransm BM WITH (NOLOCK)
		INNER JOIN @BetListByDateMem B ON BM.refno = B.transid
		INNER JOIN #TempExchange e ON e.ExchangeDate = b.winlostdate   AND e.exchangeid = b.currency
		INNER JOIN @SportBettype sbt ON bm.Bettype=sbt.Bettype
		WHERE sbt.ProductID=2--B.Bettype IN (33,43)
	END
END
IF @ShowVS=1
BEGIN 
	IF @tdate > @MoveBetsDay 
	BEGIN
		INSERT INTO @BettransDetail
		SELECT 
			BM.refno, 
			BM.odds, 
			BM.stake,
			BM.status, 
			BM.apositiontaking, 
			BM.bettype  ,
			BM.Betteam,
			BM.stake * e.EUR,
			BM.stake * e.USD,
			BM.stake * e.GBP
		FROM bettransm BM WITH (NOLOCK)
		INNER JOIN @BetListByDateMem B ON BM.refno = B.refno
		INNER JOIN #TempExchange e ON e.ExchangeDate = b.winlostdate   AND e.exchangeid = b.currency
		INNER JOIN @SportBettype sbt ON bm.Bettype=sbt.Bettype
		WHERE sbt.ProductID=5--B.Bettype=1233
	END
	IF @fdate <= @MoveBetsDay
	BEGIN
		INSERT INTO @BettransDetail
		SELECT 
			BM.refno, 
			BM.odds, 
			BM.stake,
			BM.status, 
			BM.apositiontaking, 
			BM.bettype  ,
			BM.Betteam,
			BM.stake * e.EUR,  
			BM.stake * e.USD,
			BM.stake * e.GBP
		FROM bettransm14 BM WITH (NOLOCK)
		INNER JOIN @BetListByDateMem B ON BM.refno = B.refno
		INNER JOIN #TempExchange e ON e.ExchangeDate = b.winlostdate   AND e.exchangeid = b.currency
		INNER JOIN @SportBettype sbt ON bm.Bettype=sbt.Bettype
		WHERE sbt.ProductID=5--B.Bettype=1233
	END	
	IF @fdate < @BalanceUpDay
	BEGIN
		INSERT INTO @BettransDetail
		SELECT 
			BM.refno, 
			BM.odds, 
			BM.stake,
			BM.status, 
			BM.apositiontaking, 
			BM.bettype  ,
			BM.Betteam,
			BM.stake * e.EUR,  
			BM.stake * e.USD,
			BM.stake * e.GBP
		FROM bodb_archive.dbo.bettransm BM WITH (NOLOCK)
		INNER JOIN @BetListByDateMem B ON BM.refno = B.refno
		INNER JOIN #TempExchange e ON e.ExchangeDate = b.winlostdate   AND e.exchangeid = b.currency
		INNER JOIN @SportBettype sbt ON bm.Bettype=sbt.Bettype
		WHERE sbt.ProductID=5
		--WHERE B.Bettype=1233
	END	
END 

IF @ShowLC=1
BEGIN
	IF @tdate > @MoveBetsDay 
	BEGIN
		INSERT INTO @BettransDetail
		SELECT 
			BG.refno, 
			BG.odds, 
			BG.stake,
			BG.status, 
			BG.apositiontaking, 
			BG.bettype  ,
			BG.Betteam,
			BG.stake * e.EUR,
			BG.stake * e.USD,
			BG.stake * e.GBP
		FROM bettransg BG WITH (NOLOCK)
		INNER JOIN @BetListByDateMem B ON BG.refno = B.refno and BG.custid = @CustID
		INNER JOIN #TempExchange e ON e.ExchangeDate = b.winlostdate   AND e.exchangeid = b.currency
		INNER JOIN @SportBettype sbt ON bg.Bettype=sbt.Bettype
		WHERE sbt.ProductID=4--B.Bettype BETWEEN 1101 AND 1199
	END
		
	IF @fdate <= @MoveBetsDay
	BEGIN
		INSERT INTO @BettransDetail
		SELECT 
			BG.refno, 
			BG.odds, 
			BG.stake,
			BG.status, 
			BG.apositiontaking, 
			BG.bettype  ,
			BG.Betteam  ,
			BG.stake * e.EUR,
			BG.stake * e.USD,
			BG.stake * e.GBP
		FROM bettransg14 BG WITH (NOLOCK)
		INNER JOIN @BetListByDateMem B ON BG.refno = B.refno and BG.custid = @CustID
		INNER JOIN #TempExchange e  ON e.ExchangeDate = b.winlostdate   AND e.exchangeid = b.currency
		INNER JOIN @SportBettype sbt ON bg.Bettype=sbt.Bettype
		WHERE sbt.ProductID=4--B.Bettype BETWEEN 1101 AND 1199
	END	
	
	IF @fdate < @BalanceUpDay
	BEGIN
		INSERT INTO @BettransDetail
		SELECT 
			BG.refno, 
			BG.odds, 
			BG.stake,
			BG.status, 
			BG.apositiontaking, 
			BG.bettype  ,
			BG.Betteam  ,
			BG.stake * e.EUR,
			BG.stake * e.USD,
			BG.stake * e.GBP
		FROM bodb_archive.dbo.bettransG BG WITH (NOLOCK)
		INNER JOIN @BetListByDateMem B ON BG.refno = B.refno and BG.custid = @CustID
		INNER JOIN #TempExchange e  ON e.ExchangeDate = b.winlostdate   AND e.exchangeid = b.currency
		INNER JOIN @SportBettype sbt ON bg.Bettype=sbt.Bettype
		WHERE sbt.ProductID=4--B.Bettype BETWEEN 1101 AND 1199
	END
END

SELECT * FROM @BettransDetail ORDER BY RefNo,Bettype



DROP TABLE #TempExchange
/*
	[Lrf_BetList_SelWinloss_Mem]
	@CustID			=1265745,
	@FromDate		='2012-09-01',
	@ToDate			='2012-09-10',
	@MoveBetsDay	='2012-09-03',
	@BalanceUpDay	='2012-09-05',
	@ShowSB			 = 1,
	@ShowRB			 = 1,
	@ShowNG			 = 1,
	@ShowBA			 = 1,
	@ShowLC			 = 1,
	@ShowVS			 = 1,
	@ShowCS			 = 1,
	@ShowBG			 = 1,
	@ShowMG			 = 1
*/

GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelWinloss_Mem] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelWinloss_Mem] TO [vnteam] 