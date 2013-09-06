ALTER PROCEDURE [dbo].[Lrf_Result_RaceSelByMeeting]
	@FromDate DATETIME,
	@LeagueID INT=0,
	@Sporttype SMALLINT = 151,
	@isShowAll BIT = 1 -- 1: Show All; 0: is NOT show Test
AS
/*	
	Created: 20101201@Jacob
	Date:[]
	DB: DB052.BODB02 
	Original: Age_Result_RaceSelByMeeting
	Revisions:
		- 20101201@Jacob: Copy source code from Age_Result_RaceSelByMeeting
		- 20110308@Henry: include Greyhound, Harness racing sports (152,153) - add param @sporttype 
		- 20110524@Henry: fix Show All/is not show test.
		- 20130722@Jim: support Virtual Horse Racing
*/
BEGIN
	SET NOCOUNT ON 
	CREATE TABLE #Data (meetingid INT
							,eventdate DATETIME
							,kickofftime DATETIME
							,lcolor nvarchar(20)
							,racename varchar(20)
							,place INT
							,horseNo VARCHAR(20)
							,Horseid INT
							,odds MONEY
							, placeodds MONEY
							,status VARCHAR(20)
							,IsFavor VARCHAR(20)
							,IsSCR BIT
							,FOddsStatus VARCHAR(20)
							)
	SELECT @isShowAll = CASE @isShowAll WHEN 1 THEN NULL ELSE 0 END
	IF (@Sporttype=151)
	BEGIN
		INSERT INTO #Data
		SELECT  o.leagueid meetingid,
				o.eventdate,
				o.kickofftime,
				l.lcolor,
				o.groupmatch AS racename, 
				CASE WHEN CONVERT(INT,o.placing) = 0 THEN 5 ELSE isnull(CONVERT(INT,placing),5) END place, 
				o.matchcode horseNo, 
				o.teamid Horseid , 
				o.odds,
				o.placeodds,
				o.oddsstatus status,
				CONVERT(VARCHAR(20),o.IsFavor),
				o.IsSCR,
				o.FOddsStatus
		FROM 
			(	SELECT	leagueid, teamid, eventdate, kickofftime, groupmatch, matchcode, placing, oddsstatus, odds, placeodds, IsFavor, IsSCR, FOddsStatus FROM outright o with (nolock)
				UNION ALL
				SELECT	leagueid, teamid, eventdate, kickofftime, groupmatch, matchcode, placing, oddsstatus, odds, placeodds, IsFavor, IsSCR, 'completed' FOddsStatus FROM outright14 o with (nolock)
				UNION ALL
				SELECT	leagueid, teamid, eventdate, kickofftime, groupmatch, matchcode, placing, oddsstatus, odds, placeodds, IsFavor, IsSCR, 'completed' FOddsStatus FROM DB06.bodb_Archive.dbo.outright_bk o with (nolock)
			 ) o 
			INNER JOIN league l WITH (NOLOCK) ON o.leagueid = l.leagueid 
		WHERE	o.eventdate = @FromDate 
				AND l.sporttype =  @Sporttype
				AND o.leagueid = CASE WHEN @leagueid =0 THEN o.leagueid 
								 ELSE @leagueid END 
				AND (oddsstatus ='completed' OR FoddsStatus='completed')
				AND l.isTest = isnull(@isShowAll, l.isTest)
				AND o.placing<5
				AND ISNULL( o.placing,0)<>0
		ORDER BY o.leagueid, CAST(o.groupmatch AS INT), o.placing
	END
	IF (@Sporttype=181)
	BEGIN 
		INSERT INTO #Data	
		SELECT  o.leagueid meetingid, o.eventdate, o.kickofftime, 
				l.lcolor,
				o.groupmatch AS racename, 
				CASE WHEN CONVERT(INT,o.placing) = 0 THEN 5 ELSE isnull(CONVERT(INT,placing),5) END place, 
				o.matchcode horseNo, 
				o.teamid Horseid , 
				o.odds,
				o.placeodds,
				o.oddsstatus status,
				o.IsFavor,
				o.IsSCR,
				o.FOddsStatus
			FROM 
			(
			SELECT vsr.leagueid,
				  vso.RacerID  teamid,
				   vso.EventDate,
				   vso.KickoffTime,
				   NULL groupmatch,
				  CONVERT(VARCHAR(20),vso.RacerNum)  matchcode,
				   vso.placing,
				   vsr.EventStatus oddsstatus,
					vso.Winodds odds,
				   vso.PlaceOdds,
				  CONVERT(VARCHAR(20),vso.IsFavor) IsFavor,
				   NULL IsSCR,
				   '' FOddsStatus
			FROM dbo.VSOutright vso (NOLOCK)
				INNER JOIN dbo.VSRaceInfo vsr with (nolock) ON vso.EventID=vsr.EventID
				WHERE eventdate = @FromDate 
					AND leagueid = CASE WHEN @leagueid =0 THEN leagueid 
									 ELSE @leagueid END 
					AND placing<5
					AND ISNULL(placing,0)<>0
			UNION ALL 
			SELECT vsr.leagueid,
				   vso14.RacerID teamid,
				   vso14.EventDate,
				   vso14.KickoffTime,
				   NULL groupmatch,
				   CONVERT(VARCHAR(20),vso14.RacerNum) matchcode,
				   vso14.placing,
				   vsr.EventStatus  oddsstatus,
				   vso14.Winodds odds,
				   vso14.PlaceOdds,
				   CONVERT(VARCHAR(20),vso14.IsFavor) IsFavor,
				   NULL IsSCR,
				   '' FOddsStatus
			FROM dbo.VSOutright14 vso14 (NOLOCK)
			INNER JOIN dbo.VSRaceInfo vsr with (nolock) ON vso14.EventID=vsr.EventID	
				WHERE eventdate = @FromDate 
					AND leagueid = CASE WHEN @leagueid =0 THEN leagueid 
									 ELSE @leagueid END 
					AND placing<5
					AND ISNULL( placing,0)<>0
			UNION ALL 
			SELECT vsr.leagueid,
				   bk.RacerID teamid,
				   bk.EventDate,
				   bk.KickoffTime,
				   NULL groupmatch,
				   CONVERT(VARCHAR(20),bk.RacerNum) matchcode,
				   bk.placing,
				   vsr.EventStatus  oddsstatus,
				   bk.Winodds odds,
				   bk.PlaceOdds,
				   CONVERT(VARCHAR(20),bk.IsFavor) IsFavor,
				   NULL IsSCR,
				   '' FOddsStatus
			FROM DBARC.bodb_Archive.dbo.VSOutright_bk bk (NOLOCK)
			INNER JOIN dbo.VSRaceInfo vsr with (nolock) ON bk.EventID=vsr.EventID	
				WHERE eventdate = @FromDate 
					AND leagueid = CASE WHEN @leagueid =0 THEN leagueid 
									 ELSE @leagueid END 
					AND placing<5
					AND ISNULL( placing,0)<>0		
			 ) o 
			INNER JOIN dbo.league l WITH (NOLOCK) ON o.leagueid = l.leagueid 
			INNER JOIN dbo.HRCode c WITH (NOLOCK) ON c.CodeID=o.teamid
			WHERE	c.CodeType=11
					AND l.sporttype =  @Sporttype
					AND (oddsstatus ='completed' OR FoddsStatus='completed')
					AND l.isTest = isnull(@isShowAll, l.isTest)
			ORDER BY o.leagueid, o.kickofftime
			
	END
SELECT DISTINCT * FROm #Data
DROP TABLE #Data
 END
GO
GRANT EXECUTE ON [dbo].[Lrf_Result_RaceSelByMeeting] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Result_RaceSelByMeeting] TO [vnteam]