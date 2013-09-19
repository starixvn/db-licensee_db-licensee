/*
	Lrf_BetList_SelByDayAll_Mem
	@Custid=5754258,
	@FromDate='2012-08-04 00:00:00:000'
*/
ALTER PROCEDURE [dbo].[Lrf_BetList_SelByDayAll_Mem]
	@LicenseeID INT ,
	@UserID		INT,
	@custid		INT,
	@fromdate	SMALLDATETIME,
	@transtype	INT = 0, 
	@langkey	NVARCHAR(10) = 'en-US',
	@PageSize INT=1000,
	@PageIndex INT=1,
	@TotalRows INT=0 OUTPUT,
	@SumWinlost MONEY=0 OUTPUT,
	@SumLicenseeWL MONEY=0 OUTPUT,
	@SumComm MONEY=0 OUTPUT,
	@SumPlayerComm MONEY=0 OUTPUT,
	@SumWinlostUSD MONEY=0 OUTPUT,
	@SumLicenseeWLUSD MONEY=0 OUTPUT,
	@SumCommUSD MONEY=0 OUTPUT,
	@SumPlayerCommUSD MONEY=0 OUTPUT,
	@SumWinlostEUR MONEY=0 OUTPUT,
	@SumLicenseeWLEUR MONEY=0 OUTPUT,
	@SumCommEUR MONEY=0 OUTPUT,
	@SumPlayerCommEUR MONEY=0 OUTPUT,
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT
AS
/*
Created: Henry@20101210
Task : Bet List for Daily Statement
DB: DB052.bodb02
Original: Age_BetList_SelByDayAll_Mem
Revisions:
    
	-- 20110214@Jacob: Add column discount IN the result SET
	-- 20110303@Henry: suppport based currency
	- 20110408@Amy: Change function to get Odds value AND odds type
	- 20110712@Henry: Add column LicenseeWL
	- 20110725@Henry: Get refund tickets
	- 20110729@Henry: offer 3 new bettypes for Number Game + Combination Mix Parlay
	- 20111128@Henry: Compare Checktime and CURRENT_TIMESTAMP to show waiting or running status
	- 20111212@Jim: Edit condition bettype<19000
	- 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
	- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
	- 20120319@Henry: show main transid for sub-ticket of system parlay 
	- 20120724@Jim: add player commision value 
	- 20120817@Jim: add live casino
	- 20120913@Jim: add virtual sport 
	- 20130410@Jim: return betteam value for Parlay (mix parlay & system parlay) ticket
	- 20130514@Jim: Restrict permission of Licensee Users by currency
Param's Explanation: 
	+ @transtype: 1-Betting Statement; 2-VOID/Cancelled Bet; 3-Outstanding Bet 
	
*/


SET NOCOUNT ON

DECLARE @IsBet14 BIT


/*
WON: 112   LOSE: 113   DRAW: 111 REFUND: 103
VOID: 102	REJECT: 101
RUNNING: 0  WAITING: 1
*/
DECLARE	@tmpStatus TABLE ([statusID] INT)
IF(@transtype = 1) 
BEGIN
	INSERT INTO @tmpStatus([statusID])
	SELECT 111 UNION ALL SELECT 112 UNION ALL SELECT 113 UNION ALL SELECT 103
END
ELSE IF(@transtype = 2)
BEGIN
	INSERT INTO @tmpStatus([statusID])
	SELECT 101 UNION ALL SELECT 102
END 
ELSE IF(@transtype = 3)
BEGIN
	INSERT INTO @tmpStatus([statusID])
	SELECT 0 UNION ALL SELECT 1
END

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)


IF NOT EXISTS (SELECT	c.Currency 
FROM Custinfo c WITH (NOLOCK) 
	INNER JOIN #Currency cy ON c.currency=cy.CurrencyID
WHERE c.custid = @CustID 
		)
BEGIN 
	DROP TABLE #Currency
	SELECT @ErrCode = 101, @ErrMsg = 'You have not permission to view this CustID,please check again'
		RETURN
END 		
ELSE 
	BEGIN 
		------------------------------------
		DROP TABLE #Currency
		------------------------------------

		DECLARE @Data TABLE (
			sporttype INT, 
			leagueid INT, 
			homeid INT, 
			awayid INT, 
			bettype SMALLINT,	
			matchcode NVARCHAR(50),
			race NVARCHAR(50),
			matchid INT, 
			transid BIGINT, 
			transdate DATETIME, 
			winlostdate DATETIME,
			refno NVARCHAR(50), 
			betid BIGINT,
			oddsid INT, 	
			hdp1 SMALLMONEY, 
			hdp2 SMALLMONEY, 
			Modds SMALLMONEY,
			oddstype tinyint,
			odds SMALLMONEY, 
			betteam NVARCHAR(50), 
			status NVARCHAR(50), 
			betstatus NVARCHAR(50), 
			Stake MONEY, 
			Actual_Stake	MONEY,
			winlost MONEY,
			licenseeWL 	MONEY,
			comm MONEY,
			playercomm MONEY,	
			discount DECIMAL(9,8),
			livehomescore SMALLINT, 
			liveawayscore SMALLINT, 
			liveindicator BIT,
			finalhomescore SMALLINT, 
			finalawayscore SMALLINT, 
			hthomescore SMALLINT, 
			htawayscore SMALLINT, 
			--creator VARCHAR(50), 
			ip NVARCHAR(20), 
			username NVARCHAR(50),
			isNeutral BIT	,
			currency SMALLINT,
			showtime NVARCHAR(50) -- table - shoe - hand of Live Casino
		)

		IF EXISTS (SELECT TOP 1 * FROM match14 (NOLOCK) WHERE eventdate = @fromdate)
			SELECT @IsBet14 = 1
		ELSE 
			SELECT @IsBet14 = 0

		IF @IsBet14 = 1
		BEGIN
			-- single bet
			INSERT INTO @Data 
			SELECT
				m.sporttype, 
				m.leagueid,
				m.homeID,
				m.awayID,
				b.bettype,
				m.matchcode,
				'' AS race,
				m.matchid, 
				b.transid, 
				b.transdate, 
				b.winlostdate,
				b.refno, 
				b.betid,
				b.oddsid, 
				b.hdp1, 
				b.hdp2,
				modds, 
				b.Oddstype,
				b.odds,
				b.betteam,
				b.status AS status,
				m.betstatus, 
				b.stake,
				b.actual_stake,
				(b.winlost-b.actual_stake) AS winlost, 
				CASE WHEN BA.transid IS NULL THEN - (b.winlost-b.actual_stake) ELSE 0 END AS LicenseeWL ,
				b.comm,
				b.playercomm ,
				b.discount,
				b.livehomescore, 
				b.liveawayscore, 
				b.liveindicator, 
				m.finalhomescore, 
				m.finalawayscore,
				m.hthomescore, 
				m.htawayscore,
				--b.username, 
				b.IP AS IP,
				b.Username,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.currency,
				CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime
			FROM 
				dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN dbo.match14 m WITH (NOLOCK) ON b.matchid = m.matchid		
				LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
			WHERE
				b.custid=@custid 		
				--AND b.winlostdate=@fromdate AND b.bettype<=19000: old condition 
				AND b.winlostdate=@fromdate AND b.bettype<=1299
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
			-------VHR
			INSERT INTO @Data 
			SELECT
				r.sporttype, 
				r.leagueid,
				o.RacerID homeID,
				0 awayID,
				b.bettype,
				CONVERT (VARCHAR(50),o.RacerNum) matchcode,
				'' AS race,
				o.EventID matchid, 
				b.transid, 
				b.transdate, 
				b.winlostdate,
				b.refno, 
				b.betid,
				b.oddsid, 
				b.hdp1, 
				b.hdp2,
				modds, 
				b.Oddstype,
				b.odds,
				b.betteam,
				b.status AS status,
				r.betstatus, 
				b.stake,
				b.actual_stake,
				(b.winlost-b.actual_stake) AS winlost, 
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				b.comm,
				b.playercomm ,
				b.discount,
				b.livehomescore, 
				b.liveawayscore, 
				b.liveindicator, 
				0 as finalhomescore, 
				0 as finalawayscore,
				0 as hthomescore, 
				0 as htawayscore,
				--b.username, 
				b.IP AS IP,
				b.Username,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				r.eventTime AS ShowTime
			FROM 
				dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN VSOutright14 o with (nolock) ON b.oddsid=o.Orid
				INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID	
			WHERE
				b.custid=@custid 		
				AND b.winlostdate=@fromdate AND b.bettype IN (1231, 1232, 1233, 1237, 1238)
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
			
			-- mix parlay
			INSERT INTO @Data 
			SELECT
				0,
				0, 
				0, 
				0, 
				b.bettype,		
				'', 
				'' AS race, 
				0, 
				b.transid, 
				b.transdate, 
				b.winlostdate, 
				b.refno,
				0,
				0, 
				0, 
				0, 
				b.modds,
				0 AS OddsType,
				b.odds, 
				b.betteam,
				b.status, 
				'' betstatus, 
				b.stake,
				b.actual_stake, 
				(b.winlost-b.actual_stake) AS winlost, 
				CASE WHEN BA.transid IS NULL THEN - (b.winlost-b.actual_stake) ELSE 0 END AS LicenseeWL ,
				b.comm,
				b.playercomm ,
				b.discount,
				0, 
				0, 
				0, 
				0, 
				0, 
				0, 
				0,
				--b.username creator, 
				b.IP AS IP,
				b.Username,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime
			FROM 
				dbo.bettrans14 b WITH (NOLOCK)
				LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid		
			WHERE
				b.custid=@custid
				AND b.winlostdate=@fromdate
				--AND b.matchid=0 
				AND b.matchid = 9
				AND b.bettype=9
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

			--Combination Mix Parlay
			INSERT INTO @Data 
			SELECT
				0,
				0, 
				0, 
				0, 
				b.bettype,		
				'', 
				'' AS race, 
				0, 
				CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END AS transid, 
				b.transdate, 
				b.winlostdate, 
				b.refno,
				0,
				0, 
				0, 
				0, 
				b.modds,
				0 AS OddsType,
				b.odds, 
				b.betteam,
				b.status, 
				'' betstatus, 
				b.stake,
				b.actual_stake, 
				(b.winlost-b.actual_stake) AS winlost, 
				CASE WHEN BA.transid IS NULL THEN - (b.winlost-b.actual_stake) ELSE 0 END AS LicenseeWL ,
				b.comm,
				b.playercomm ,
				b.discount,
				0, 
				0, 
				0, 
				0, 
				0, 
				0, 
				0,
				--b.username creator, 
				b.IP AS IP,
				b.Username,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime
			FROM 
				dbo.bettrans14 b WITH (NOLOCK)
				LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid		
			WHERE
				b.custid=@custid
				AND b.winlostdate=@fromdate
				AND b.bettype=29
				AND b.matchid = 29
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
			

			-- outright
			INSERT INTO @Data 
			SELECT
				l.sporttype,
				m.leagueID,
				m.teamID AS homeid,
				0 AS awayid,
				bettype, 
				m.matchcode,
				m.groupmatch AS race, 
				m.orid, 
				b.transid, 
				b.transdate, 
				b.winlostdate, 
				b.refno,
				0,
				10, 
				b.hdp1, 
				b.hdp2, 
				b.modds,
				0 AS OddsType,
				b.odds, 
				'',
				b.status, 
				'', 
				b.stake,
				b.actual_stake, 
				(b.winlost-b.actual_stake) AS winlost,
				CASE WHEN ISNULL(BA.transid,0)=0 AND b.bettype=10 THEN - (b.winlost-b.actual_stake) WHEN b.bettype IN (31,32,33) THEN awinlost ELSE 0 END AS LicenseeWL ,
				b.comm,
				b.playercomm ,
				b.discount,
				b.livehomescore, 
				b.liveawayscore, 
				0, 
				0, 
				0, 
				0, 
				0,
				--b.username creator,
				b.IP AS IP,
				b.Username,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime
			FROM 
				dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN dbo.outright14 m WITH (NOLOCK) on b.matchid = m.orid	
				INNER JOIN dbo.league l WITH (NOLOCK) on m.leagueid = l.leagueid
				LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
			WHERE
				b.custid=@custid AND b.bettype IN (10,31,32,33)
				AND b.winlostdate = @fromdate
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

		END
		ELSE
		BEGIN
			-- single bet
			INSERT INTO @Data 
			SELECT
				m.sporttype, 
				m.leagueid,
				m.homeID,
				m.awayID,
				b.bettype,
				m.matchcode, 
				'' AS race,
				m.matchid, 
				b.transid, 
				b.transdate, 
				b.winlostdate,
				b.refno, 
				b.betid,
				b.oddsid, 
				b.hdp1, 
				b.hdp2, 
				modds,
				b.OddsType,
				b.odds,
				b.betteam,
				CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
				ELSE b.status   
				END as status,
				m.betstatus, 
				b.stake,
				b.actual_stake,
				CASE WHEN b.statusID NOT IN (0,1) THEN (b.winlost-b.actual_stake) ELSE 0 END AS winlost,
				CASE WHEN b.statusID NOT IN (0,1) THEN 
					CASE WHEN BA.transid IS NULL THEN - (b.winlost-b.actual_stake) ELSE 0 END 
				ELSE 0 END	AS LicenseeWL ,
				
				CASE WHEN b.statusID NOT IN (0,1) THEN b.comm  ELSE 0 END as comm,
				b.playercomm , 
				b.discount,
				b.livehomescore, 
				b.liveawayscore, 
				b.liveindicator, 
				m.finalhomescore, 
				m.finalawayscore,
				m.hthomescore, 
				m.htawayscore,
				b.IP AS IP,
				b.Username,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.currency,
				CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime 
			FROM 
				dbo.bettrans b WITH (NOLOCK)
				INNER JOIN dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid		
				LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
			WHERE
				b.custid=@custid 		
				--AND b.winlostdate=@fromdate AND b.bettype<=19000 : old condition 
				AND b.winlostdate=@fromdate AND b.bettype<=1299
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

			-------VHR
			INSERT INTO @Data 
			SELECT
				r.sporttype, 
				r.leagueid,
				o.RacerID homeID,
				0 awayID,
				b.bettype,
				CONVERT (VARCHAR(50),o.RacerNum) matchcode,
				'' AS race,
				o.EventID matchid, 
				b.transid, 
				b.transdate, 
				b.winlostdate,
				b.refno, 
				b.betid,
				b.oddsid, 
				b.hdp1, 
				b.hdp2,
				modds, 
				b.Oddstype,
				b.odds,
				b.betteam,
				b.status AS status,
				r.betstatus, 
				b.stake,
				b.actual_stake,
				(b.winlost-b.actual_stake) AS winlost, 
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				b.comm,
				b.playercomm ,
				b.discount,
				b.livehomescore, 
				b.liveawayscore, 
				b.liveindicator, 
				0 as finalhomescore, 
				0 as finalawayscore,
				0 as hthomescore, 
				0 as htawayscore,
				--b.username, 
				b.IP AS IP,
				b.Username,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				r.eventTime AS ShowTime
			FROM 
				dbo.bettrans b WITH (NOLOCK)
				INNER JOIN VSOutright o with (nolock) ON b.oddsid=o.Orid
				INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID	
			WHERE
				b.custid=@custid 		
				AND b.winlostdate=@fromdate AND b.bettype IN (1231, 1232, 1233, 1237, 1238)
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
				
			-- mixed parlay
			INSERT INTO @Data 
			SELECT
				0, 
				0, 
				0, 
				0, 
				b.bettype,		
				'', 
				'', 
				0, 
				b.transid, 
				b.transdate, 
				b.winlostdate, 
				b.refno,
				0,
				0, 
				0, 
				0, 
				b.modds,
				0 AS OddsType,
				b.odds, 
				b.betteam,
				b.status, 
				'' betstatus, 
				b.stake,
				b.actual_stake,
				CASE WHEN b.statusID NOT IN (0,1) THEN (b.winlost-b.actual_stake) ELSE 0 END AS winlost,
				CASE WHEN b.statusID NOT IN (0,1) THEN 
					CASE WHEN BA.transid IS NULL THEN - (b.winlost-b.actual_stake) ELSE 0 END 
				ELSE 0 END	AS LicenseeWL ,
				CASE WHEN b.statusID NOT IN (0,1) THEN b.comm  ELSE 0 END as comm,
				b.playercomm  ,
				b.discount,
				0, 
				0, 
				0, 
				0, 
				0, 
				0, 
				0,
				--b.username creator, 
				b.IP AS IP,
				b.Username,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime
			FROM 
				dbo.bettrans b WITH (NOLOCK)		
				LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
			WHERE
				b.custid=@custid
				AND b.winlostdate=@fromdate
				--AND b.matchid=0 
				AND b.matchid = 9
				AND b.bettype=9
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
				
			--Combination Mixd Parlay
			INSERT INTO @Data 
			SELECT
				0, 
				0, 
				0, 
				0, 
				b.bettype,		
				'', 
				'', 
				0, 
				CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END AS transid,
				b.transdate, 
				b.winlostdate, 
				b.refno,
				0,
				0, 
				0, 
				0, 
				b.modds,
				0 AS OddsType,
				b.odds, 
				b.betteam,
				b.status, 
				'' betstatus, 
				b.stake,
				b.actual_stake,
				CASE WHEN b.statusID NOT IN (0,1) THEN (b.winlost-b.actual_stake) ELSE 0 END AS winlost,
				CASE WHEN b.statusID NOT IN (0,1) THEN 
					CASE WHEN BA.transid IS NULL THEN - (b.winlost-b.actual_stake) ELSE 0 END 
				ELSE 0 END	AS LicenseeWL ,
				CASE WHEN b.statusID NOT IN (0,1) THEN b.comm  ELSE 0 END as comm,
				b.playercomm  AS PlayerComm,
				b.discount,
				0, 
				0, 
				0, 
				0, 
				0, 
				0, 
				0,
				--b.username creator, 
				b.IP AS IP,
				b.Username,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime
			FROM 
				dbo.bettrans b WITH (NOLOCK)		
				LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
			WHERE
				b.custid=@custid
				AND b.winlostdate=@fromdate
				AND b.matchid=29 
				AND b.bettype=29
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)	


			-- outright
			INSERT INTO @Data 
			SELECT
				l.sporttype,
				m.leagueID,
				m.teamID AS homeid,
				0 AS awayid,
				b.bettype, 
				m.matchcode, 
				m.groupmatch AS race, 
				m.orid, 
				b.transid, 
				b.transdate, 
				b.winlostdate, 
				b.refno,
				0,
				10, 
				b.hdp1, 
				b.hdp2, 
				b.modds,
				0 AS OddsType,
				b.odds, 
				'',
				b.status, 
				'', 
				b.stake,
				b.actual_stake,
				CASE WHEN b.statusID NOT IN (0,1) THEN (b.winlost-b.actual_stake) ELSE 0 END AS winlost,
				CASE WHEN b.statusID NOT IN (0,1) THEN 
					CASE WHEN ISNULL(BA.transid,0)=0 AND b.bettype=10 THEN - (b.winlost-b.actual_stake) WHEN b.bettype IN (31,32,33) THEN awinlost ELSE 0 END 
				ELSE 0 END AS LicenseeWL ,
				CASE WHEN b.statusID NOT IN (0,1) THEN b.comm  ELSE 0 END as comm,
				b.playercomm  AS PlayerComm,
				b.discount,
				b.livehomescore, 
				b.liveawayscore, 
				0, 
				0, 
				0, 
				0, 
				0,
				--b.username creator, 
				b.IP AS IP,
				b.Username,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime 
			FROM 
				dbo.bettrans b WITH (NOLOCK)
				INNER JOIN dbo.outright m WITH (NOLOCK) on b.matchid = m.orid	
				INNER JOIN dbo.league l WITH (NOLOCK) on m.leagueid = l.leagueid
				LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
			WHERE
				b.custid=@custid AND b.bettype IN (10,31,32,33)
				AND b.winlostdate = @fromdate
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

		END

		DECLARE @RowStart INT, @RowEnd INT  
		SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

		DECLARE @Today SMALLDATETIME 
		SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 

		DECLARE @currency INT

		SELECT @currency = Currency FROM Custinfo c WITH (NOLOCK)
		WHERE Custid = @CustID

		SELECT * INTO #TempExchange 
		FROM Lrf_f_GetExchangeDaily(@FromDate,@Today)
		WHERE exchangeid = @currency


		SELECT 
			@TotalRows = COUNT(transid),
			@SumWinlost=SUM(ISNULL(winlost,0)),
			@SumLicenseeWL=SUM(ISNULL(LicenseeWL,0)),
			
			@SumComm=SUM(ISNULL(comm,0)) ,
			@SumPlayerComm=SUM(ISNULL(playercomm,0)) ,
			--USD
			@SumWinlostUSD=SUM(ISNULL(winlost*e.USD,0)),
			@SumLicenseeWLUSD=SUM(ISNULL(LicenseeWL*e.USD,0)),
			
			@SumCommUSD=SUM(ISNULL(comm*e.USD,0)) ,
			@SumPlayerCommUSD=SUM(ISNULL(playercomm*e.USD,0)) ,
			--EUR
			@SumWinlostEUR=SUM(ISNULL(winlost*e.EUR,0)),
			@SumLicenseeWLEUR=SUM(ISNULL(LicenseeWL*e.EUR,0)),
			
			@SumCommEUR=SUM(ISNULL(comm*e.EUR,0)) ,
			@SumPlayerCommEUR=SUM(ISNULL(playercomm*e.EUR,0))
			
		FROM @Data b
		INNER JOIN 
			#TempExchange e 
		ON e.ExchangeDate = (CASE WHEN b.winlostdate > @Today THEN @Today ELSE b.winlostdate END)   AND e.exchangeid = b.currency


		SELECT A.* 
		FROM
		(
			SELECT  
					ROW_NUMBER() over(order by transid, refno) AS RowNum,
					b.* ,
					--USD
					b.stake*e.USD AS stakeUSD ,
					b.Actual_Stake * e.USD AS Actual_StakeUSD,
					b.winlost*e.USD AS winlostUSD ,
					b.LicenseeWL * e.USD AS LicenseeWLUSD,
					
					b.comm*e.USD AS commUSD ,
					b.playercomm*e.USD AS PlayerCommUSD ,
					--EUR
					b.stake*e.EUR AS stakeEUR ,
					b.Actual_Stake * e.EUR AS Actual_StakeEUR,
					b.winlost*e.EUR AS winlostEUR ,
					b.LicenseeWL * e.EUR AS LicenseeWLEUR,
					
					b.comm*e.EUR AS commEUR,
					b.playercomm*e.EUR AS PlayerCommEUR 	
			FROM 
				@Data b
			INNER JOIN 
			#TempExchange e 
			ON e.ExchangeDate = (CASE WHEN b.winlostdate > @Today THEN @Today ELSE b.winlostdate END)   AND e.exchangeid = b.currency
		) A WHERE A.RowNum between @RowStart AND @RowEnd
		DECLARE @BettransDetail TABLE(  
			refno BIGINT,  
			odds SMALLMONEY,  
			stake MONEY,
			status NVARCHAR(10),  
			apositiontaking SMALLMONEY,  
			bettype SMALLINT,
			Betteam nvarchar (10),
			stakeEUR MONEY,
			stakeUSD MONEY
			 )   

		IF @IsBet14 = 1
		BEGIN
			--get data FROM bettransm14 for bettype 33,43
			INSERT INTO @BettransDetail 
			SELECT 
				BM.refno, 
				BM.odds, 
				BM.stake,
				BM.status, 
				BM.apositiontaking, 
				BM.bettype,
				BM.betteam,
				BM.stake*e.EUR,	
				BM.stake*e.USD
			FROM bettransm14 BM WITH (NOLOCK)
			INNER JOIN @Data B ON BM.refno = B.transid
			INNER JOIN #TempExchange e ON  e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
			WHERE B.Bettype IN (33,43)
			UNION ALL
			--get data from bettransm14 for bettype 1233
			SELECT 
				BM.refno,
				BM.odds,		
				BM.Stake,
				BM.status,
				BM.apositiontaking,
				BM.bettype,
				BM.Betteam,
				BM.stake*e.EUR,	
				BM.stake*e.USD		
			FROM bettransm14 BM with (NOLOCK, INDEX =IX_bettransm14 )
			INNER JOIN @Data B ON BM.refno = B.refno
			INNER JOIN #TempExchange e ON  e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
			WHERE B.Bettype = 1233
			UNION 
			SELECT 
				BG.refno, 
				BG.odds, 
				BG.stake,
				BG.status, 
				BG.apositiontaking, 
				BG.bettype  ,
				BG.Betteam ,
				BG.stake*e.EUR,
				BG.stake*e.USD	
			FROM bettransg14 BG WITH (NOLOCK)
			INNER JOIN @Data B ON BG.refno = B.refno and BG.custid = @CustID
			INNER JOIN #TempExchange e ON  e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
			WHERE B.Bettype BETWEEN 1101 AND 1199
		END
		ELSE
		BEGIN
			--get data FROM bettransm for bettype 33,43
			INSERT INTO @BettransDetail 
			SELECT 
				BM.refno, 
				BM.odds, 
				BM.stake,
				BM.status, 
				BM.apositiontaking, 
				BM.bettype,
				BM.betteam,
				BM.stake*e.EUR,
				BM.stake*e.USD
			FROM bettransm BM WITH (NOLOCK)
			INNER JOIN @Data B ON BM.refno = B.transid
			INNER JOIN #TempExchange e ON  e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
			WHERE B.Bettype IN (33,43)
			UNION ALL
			--get data from bettransm14 for bettype 1233
			SELECT 
				BM.refno,
				BM.odds,		
				BM.Stake,
				BM.status,
				BM.apositiontaking,
				BM.bettype,
				BM.Betteam,
				BM.stake*e.EUR,	
				BM.stake*e.USD		
			FROM bettransm BM with (NOLOCK, INDEX =IX_bettransm14 )
			INNER JOIN @Data B ON BM.refno = B.refno
			INNER JOIN #TempExchange e ON  e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
			WHERE B.Bettype = 1233
			
			UNION
			SELECT 
				BG.refno, 
				BG.odds, 
				BG.stake,
				BG.status, 
				BG.apositiontaking, 
				BG.bettype  ,
				BG.Betteam,
				BG.stake*e.EUR,
				BG.stake*e.USD
			FROM bettransg BG WITH (NOLOCK)
			INNER JOIN @Data B ON BG.refno = B.refno and BG.custid = @CustID
			INNER JOIN #TempExchange e ON  e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
			WHERE B.Bettype BETWEEN 1101 AND 1199
		END
		SELECT * FROM @BettransDetail ORDER BY refno,bettype 
		DROP TABLE #TempExchange
	END
GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelByDayAll_Mem] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelByDayAll_Mem] TO [vnteam]