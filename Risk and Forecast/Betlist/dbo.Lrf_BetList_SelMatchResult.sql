set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER  PROCEDURE [dbo].[Lrf_BetList_SelMatchResult]
	@LicenseeID INT ,
	@UserID		INT,	
	@MatchID INT,
	@RaceNo VARCHAR(50)=NULL
AS
 
/*
Created: Henry@20101210
Task: Get Result of match
DB: DB052.bodb02

Revisions:    
	- 20110308@Henry: get more sporttype (152,153)
	- 20110907@Sophia: Add column IsHTCal, calculate for pending result
	- 20110926@Henry: Add column kickofftime,IsPending , add more columns for HR
	- 20120817@Henry: Add Showtime for Table - hand - Shoe of Live Casino
	- 20120911@Henry: Add homeid2 for Roulettle
	- 20130403@Jim: support base currency USD 
	- 20130514@Jim:Restrict permission of Licensee Users by currency
	- 20130722@Jim: support Virtual Horse Racing
	*******************
	sample test case:
		exec Lrf_BetList_SelMatchResult_xtest @licenseeid=1,@matchid=2715481,@raceno=N'3',@userid=68
*/

SET NOCOUNT ON

IF(@RaceNo is NULL )
BEGIN
	IF exists(SELECT 1 FROM match WITH(NOLOCK) WHERE matchid = @matchid)
	BEGIN	
		SELECT 
			m.sporttype, 
			m.betstatus, 
			hthomescore,
			htawayscore,
			datediff(minute,kickofftime,CURRENT_TIMESTAMP) playtime,
			m.LeagueID,
			m.matchid, 
			m.homeID,
			m.awayID,
			m.matchcode,
			m.kickofftime,
			m.eventdate,
			m.finalhomescore,
			m.finalawayscore,
			case when m.betstatus like 'Refund FT%' then 'Refund FT' 
						 when m.betstatus like 'Refund HT%' then 'Refund HT'
						 when m.betstatus like 'Refund%' then 'Refund' 
						else m.eventstatus end as eventstatus,
			isnull(mr.refund,0) IsRefund, 
			isnull(mr.calrefund,0) IsCalRefund,
			isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
			m.goalrecord,
			ISNULL(mr.IsHTCal,0) as IsHTCal,
			ISNULL(mr.calculate,0) as calculate	,
			ISNULL(mr.IsPending,0) as IsPending	 ,
			ISNULL(m.showtime,'') AS showtime,
			m.homeid2
		FROM match m WITH(NOLOCK)
			LEFT OUTER JOIN match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
		WHERE m.matchid = @matchid
		ORDER BY m.eventdate,m.matchcode
		RETURN
	END
	IF exists(SELECT 1 FROM match14 WITH(NOLOCK) WHERE matchid = @matchid)
			 	
	BEGIN
		SELECT 
			m.sporttype, 
			m.betstatus, 
			hthomescore,
			htawayscore,
			datediff(minute,kickofftime,CURRENT_TIMESTAMP) playtime,
			m.LeagueID,
			m.matchid, 
			m.homeID,
			m.awayID,
			m.matchcode,
			m.kickofftime,
			m.eventdate,
			m.finalhomescore,
			m.finalawayscore,
			case when m.betstatus like 'Refund FT%' then 'Refund FT' 
						 when m.betstatus like 'Refund HT%' then 'Refund HT'
						 when m.betstatus like 'Refund%' then 'Refund' 
						else m.eventstatus end as eventstatus,
			isnull(mr.refund,0) IsRefund, 
			isnull(mr.calrefund,0) IsCalRefund,
			isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
			m.goalrecord,
			ISNULL(mr.IsHTCal,0) as IsHTCal,
			ISNULL(mr.calculate,0) as calculate,
			ISNULL(mr.IsPending,0) as IsPending	 ,
			ISNULL(m.showtime,'') AS showtime,
			m.homeid2
		FROM match14 m WITH(NOLOCK)		
			LEFT OUTER JOIN match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
		WHERE m.matchid = @matchid
		ORDER BY m.eventdate,m.matchcode
		RETURN
	END
	ELSE
	BEGIN
		SELECT 
			m.sporttype, 
			m.betstatus, 
			hthomescore,
			htawayscore,
			datediff(minute,kickofftime,CURRENT_TIMESTAMP) playtime,
			m.LeagueID,
			m.matchid, 
			m.homeID,
			m.awayID,
			m.matchcode,
			m.eventdate,
			m.kickofftime,
			m.finalhomescore,
			m.finalawayscore,
			case when m.betstatus like 'Refund FT%' then 'Refund FT' 
						 when m.betstatus like 'Refund HT%' then 'Refund HT'
						 when m.betstatus like 'Refund%' then 'Refund' 
						else m.eventstatus end as eventstatus,
			isnull(mr.refund,0) IsRefund,  
			isnull(mr.calrefund,0) IsCalRefund,
			isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
			m.goalrecord,
			ISNULL(mr.IsHTCal,0) as IsHTCal,
			ISNULL(mr.calculate,0) as calculate,
			ISNULL(mr.IsPending,0) as IsPending,
			ISNULL(m.showtime,'') AS showtime,
			m.homeid2
		FROM DB06.bodb_archive.dbo.Match_BK m WITH(NOLOCK)		
			LEFT OUTER JOIN match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
		WHERE m.matchid = @matchid
		ORDER BY m.eventdate,m.matchcode
	END
END
ELSE
BEGIN
	CREATE TABLE  #tmpresult (horseNo varchar(50),KickoffTime datetime ,racename varchar(50),place tinyint,sporttype INT,horseid INT, odds smallmoney,PlaceOdds smallmoney,meetingid int,oddsstatus varchar(10),IsFavor varchar(10),IsSCR bit,FOddsStatus varchar(10))
	DECLARE	@leagueid INT, @eventdate DATETIME 
	IF exists(select 1 from outright WITH(NOLOCK) where orid = @matchid)
	BEGIN
		SELECT	@leagueid = leagueid , @eventdate = eventdate 
		FROM	Outright WITH (NOLOCK)
		WHERE	orid = @matchid 
		insert into #tmpresult 
		SELECT	matchcode AS horseNo, 
				NULL,
				CAST(o.groupmatch AS INT) 
				AS racename,
				CASE WHEN o.placing = 0 THEN 5 ELSE isnull(placing,5) END place, 
				l.sporttype, 
				teamid horseid,
				o.odds,
				o.placeodds,
				o.leagueid AS meetingid,
				o.oddsstatus status,
				convert(varchar(10),o.IsFavor),
				o.IsSCR,
				o.FOddsStatus
		FROM	Outright o WITH (NOLOCK)	
					INNER JOIN league l WITH(NOLOCK) ON o.leagueid = l.leagueid
		WHERE	o.leagueid = @leagueid 
				AND groupmatch = @RaceNo
				AND eventdate = @eventdate 
				AND ( ISNULL(placing,0) <> 0 OR isScr = 1)
		ORDER BY placing
		
	END 
	ELSE IF EXISTS( SELECT 1 FROM Outright14 WITH (NOLOCK) WHERE orid = @matchid)
	BEGIN
		SELECT	@leagueid = leagueid , @eventdate = eventdate 
		FROM	Outright14 WITH (NOLOCK)
		WHERE	orid = @matchid 
		insert into #tmpresult 
		SELECT	matchcode AS horseNo, 
				NULL,
				CAST(o.groupmatch AS INT) AS racename,
				CASE WHEN o.placing = 0 THEN 5 ELSE isnull(placing,5) END place, 
				l.sporttype, 
				teamid horseid,
				o.odds,
				o.placeodds,
				o.leagueid AS meetingid,
				o.oddsstatus status,
				convert(varchar(10),o.IsFavor),
				o.IsSCR,
				o.FOddsStatus
		FROM	Outright14 o WITH (NOLOCK)
					INNER JOIN league l WITH(NOLOCK) ON l.leagueid = o.leagueid
		WHERE	o.leagueid = @leagueid 
				AND groupmatch = @RaceNo
				AND eventdate = @eventdate 
				AND (ISNULL(placing,0) <> 0  OR isScr = 1)
		ORDER BY placing	
	END 
	ELSE  IF EXISTS( SELECT 1 FROM DB06.bodb_Archive.dbo.Outright_bk WITH (NOLOCK) WHERE orid = @matchid)
	BEGIN
		SELECT	@leagueid = leagueid , @eventdate = eventdate 
		FROM	DB06.bodb_Archive.dbo.Outright_bk WITH (NOLOCK)
		WHERE	orid = @matchid 
		insert into #tmpresult 
		SELECT	matchcode AS horseNo, 
				NULL,
				CAST(bk.groupmatch AS INT) AS racename,
				CASE WHEN placing = 0 THEN 5 ELSE isnull(placing,5) END place, 
				l.sporttype, 
				teamid horseid,
				bk.odds,
				bk.placeodds,
				bk.leagueid AS meetingid,
				bk.oddsstatus status,
				convert(varchar(10),IsFavor),
				bk.IsSCR,
				bk.FOddsStatus
		FROM	DB06.bodb_Archive.dbo.Outright_bk bk WITH (NOLOCK)
					INNER JOIN league l WITH(NOLOCK) ON l.leagueid = bk.leagueid
		WHERE	bk.leagueid = @leagueid 
				AND groupmatch = @RaceNo
				AND eventdate = @eventdate 
				AND (ISNULL(placing,0)<> 0  OR isScr = 1)
		ORDER BY placing	
	END 
	--------------------------------------------------Virtual Horse Racing

	IF exists( SELECT TOP 1 1 FROM VSOutright WITH(NOLOCK) WHERE EventID=@MatchID)
		BEGIN
			-- Virtual HR 
			insert into #tmpresult 
			SELECT	RacerNum AS horseNo, 
					r.EventTime,
					NULL AS racename,
					placing AS place, 
					r.SportType,
					o.RacerID horseid,
					o.WinOdds odds,
					o.placeodds,
					'' AS meetingid,
					o.EventStatus status,
					o.IsFavor,
					'' IsSCR,
					'' FOddsStatus
			FROM	VSOutright o WITH (NOLOCK)
					INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE	o.EventID = @MatchID
					AND (ISNULL(placing,0) <> 0)
			ORDER BY placing
			
		END
		ELSE IF exists(SELECT TOP 1 1 FROM VSOutright14 WITH(NOLOCK) WHERE EventID=@MatchID)
		BEGIN
			-- Virtual HR 
			insert into #tmpresult 
			SELECT	RacerNum AS horseNo, 
					r.EventTime,
					NULL AS racename,
					placing AS place, 
					r.SportType,
					o.RacerID horseid,
					o.WinOdds odds,
					o.placeodds,
					'' AS meetingid,
					o.EventStatus status,
					o.IsFavor,
					'' IsSCR,
					'' FOddsStatus
			FROM	VSOutright14 o WITH (NOLOCK)
					INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE	o.EventID = @MatchID
					AND (ISNULL(placing,0) <> 0)
			ORDER BY placing
			
		END
		ELSE 
		BEGIN
			-- Virtual HR 
			insert into #tmpresult 
			SELECT	RacerNum AS horseNo, 
					r.EventTime,
					NULL AS racename,
					placing AS place, 
					r.SportType,
					o.RacerID horseid,
					o.WinOdds odds,
					o.placeodds,
					'' AS meetingid,
					o.EventStatus status,
					o.IsFavor,
					'' IsSCR,
					'' FOddsStatus
			FROM	DBARC.bodb_Archive.dbo.VSOutright_bk o WITH (NOLOCK)
					INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE	o.EventID = @MatchID
					AND (ISNULL(placing,0) <> 0)
			ORDER BY placing
			
		END
	--------------------------------------------------End Virtual Horse Racing
	IF EXISTS (SELECT 1 FROM #tmpresult  WHERE sporttype in (151,152,153))
		BEGIN 
				SELECT meetingid,racename,COUNT(place) rc INTO #DataSUM
				FROM #tmpresult
				WHERE place<5
				GROUP BY   meetingid,racename
				
				SELECT 	d.meetingid
				,d.racename
				,temp.results as TF
				,temp2.results2 as SCR
				INTO #tmp	
				FROm #tmpresult d
				INNER JOIN #DataSum d2 ON d.meetingid=d2.meetingid AND  d.racename=d2.racename
				CROSS APPLY  (
							  SELECT STUFF (
											(
											SELECT  CAST(horseNo AS VARCHAR(10))+ ',' 
														
											FROM #tmpresult d
											WHERE d.meetingid=d2.meetingid AND  d.racename=d2.racename  AND d.IsFavor<>'0' 
											for xml path(''), type).value('.','varchar(max)')
											,1,2,''
											)
							  )temp(results)	
				
				CROSS APPLY  (
							  SELECT STUFF (
											(
											SELECT CAST(horseNo AS VARCHAR(10))+ ',' 
											FROM #tmpresult d
											WHERE d.meetingid=d2.meetingid AND  d.racename=d2.racename  AND d.IsSCR<>0
											for xml path(''), type).value('.','varchar(max)')
											,1,2,''
											)
							  )temp2(results2)	
				ORDER BY d.meetingid,d.racename,d.place
			
				SELECT DISTINCT
				 d.*
				,d3.TF
				,d3.SCR		
				,d2.rc as [RowCount]  
				FROm #tmpresult d
				INNER JOIN #DataSum d2 ON d.meetingid=d2.meetingid AND  d.racename=d2.racename
				INNER JOIN #tmp d3 ON d.meetingid=d3.meetingid AND  d.racename=d3.racename
				WHERE d.place<5 
				ORDER BY d.meetingid,d.racename,d.place
		
				DROP TABLE #DataSum 
				DROP TABLE #tmp
		END--
	ELSE IF EXISTS (SELECT 1 FROM  #tmpresult  WHERE sporttype=181)
		BEGIN 
			SELECT kickofftime,COUNT(place) rc INTO #DataSUMVHR
			FROM #tmpresult
			GROUP BY  kickofftime

			SELECT d.*,'' TF,'' SCR , d2.rc as [RowCount]  
			FROm #tmpresult d
			INNER JOIN #DataSumVHR d2 ON d.kickofftime=d2.kickofftime 
			WHERE d.place<5
			ORDER BY meetingid, kickofftime,place
			DROP TABLE #DataSumVHR 
		END --
	ELSE 
		BEGIN 
			SELECT * FROM #tmpresult 
		END 	
	DROP TABLE #tmpresult 
END
/*
DECLARE @Today SMALLDATETIME 
SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 
BEGIN
	SELECT  currencyID,LicenseeID into #currency
	FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
	--get data from bettransg for bettype 1101
	
	SELECT 
		bg.refno, 
		bg.odds, 
		bg.stake,
		bg.status ,
		bg.apositiontaking, 
		bg.betteam ,
		bg.stake*e.EUR AS stakeEUR,
		bg.stake*e.USD AS stakeUSD	
	FROM bettransg bg with (NOLOCK)
	INNER JOIN match m with (NOLOCK) ON bg.matchid=m.matchid 
	INNER JOIN bettrans B with (NOLOCK)ON bg.refno = B.refno
	INNER JOIN 
		(SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today))e 
	ON e.exchangeid = b.currency AND  e.ExchangeDate = B.winlostdate
	INNER JOIN #currency c ON c.CurrencyID=b.currency
	WHERE	b.bettype between 1101 and 1199 and
			b.statusID in (0,1)
			AND m.matchid=@matchID
	
			
	---------------------------------------		
	DROP TABLE #Currency
	---------------------------------------

END
*/
GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelMatchResult] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelMatchResult] TO [vnteam]

