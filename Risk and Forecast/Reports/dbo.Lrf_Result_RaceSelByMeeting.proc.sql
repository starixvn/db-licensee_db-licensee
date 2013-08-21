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
	
	SELECT @isShowAll = CASE @isShowAll WHEN 1 THEN NULL ELSE 0 END
	
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
		(	SELECT	leagueid, teamid, eventdate, kickofftime, groupmatch, matchcode, placing, oddsstatus, odds, placeodds, CONVERT(VARCHAR(20),IsFavor) IsFavor, IsSCR, FOddsStatus FROM outright o with (nolock)
			UNION ALL
			SELECT	leagueid, teamid, eventdate, kickofftime, groupmatch, matchcode, placing, oddsstatus, odds, placeodds, CONVERT(VARCHAR(20),IsFavor) IsFavor, IsSCR, 'completed' FOddsStatus FROM outright14 o with (nolock)
			UNION ALL
			SELECT	leagueid, teamid, eventdate, kickofftime, groupmatch, matchcode, placing, oddsstatus, odds, placeodds, CONVERT(VARCHAR(20),IsFavor) IsFavor, IsSCR, 'completed' FOddsStatus FROM DB06.bodb_Archive.dbo.outright_bk o with (nolock)
			
			UNION ALL 
				SELECT vsr.leagueid,
					   vso.racerID,
					   vso.EventDate,
					   vso.KickoffTime,
					   NULL groupmatch,
					  CONVERT(INT,vso.RacerNum)  matchcode,
					   vso.placing,
					   vsr.EventStatus oddsstatus,
						vso.Winodds odds,
					   vso.PlaceOdds,
					  CONVERT(VARCHAR(20),vso.IsFavor) IsFavor,
					   NULL IsSCR,
					   '' FOddsStatus
				FROM dbo.VSOutright vso (NOLOCK)
					INNER JOIN dbo.VSRaceInfo vsr with (nolock) ON vso.EventID=vsr.EventID
			UNION ALL 
				SELECT vsr.leagueid,
					   vso14.racerID,
					   vso14.EventDate,
					   vso14.KickoffTime,
					   NULL groupmatch,
					   CONVERT(INT,vso14.RacerNum) matchcode,
					   vso14.placing,
					   vsr.EventStatus  oddsstatus,
					   vso14.Winodds odds,
					   vso14.PlaceOdds,
					   CONVERT(VARCHAR(20),vso14.IsFavor) IsFavor,
					   NULL IsSCR,
					   '' FOddsStatus
				FROM dbo.VSOutright14 vso14 (NOLOCK)
				INNER JOIN dbo.VSRaceInfo vsr with (nolock) ON vso14.EventID=vsr.EventID	
				
		 ) o 
		INNER JOIN league l WITH (NOLOCK) ON o.leagueid = l.leagueid 
	WHERE	o.eventdate = @FromDate 
			AND l.sporttype =  @Sporttype
			AND o.leagueid = CASE WHEN @leagueid =0 THEN o.leagueid 
							 ELSE @leagueid END 
			AND (oddsstatus ='completed' OR FoddsStatus='completed')
			AND l.isTest = isnull(@isShowAll, l.isTest)

		
	ORDER BY o.leagueid, o.groupmatch , o.placing
END 
GO
GRANT EXECUTE ON [dbo].[Lrf_Result_RaceSelByMeeting] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Result_RaceSelByMeeting] TO [vnteam]