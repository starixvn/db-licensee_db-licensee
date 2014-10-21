USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].Lrf_Result_MatchSelByLeague_Detail 
(	
	@MatchId INT
)
AS
/*
Created: 20141021@Jim
Task: 	Retrieve detail a  matches 
DB:  DBEXT/bodb02
Original: [Age_Result_MatchSelResultDetail]
Revisions: 

*/
BEGIN 
	SET NOCOUNT ON 	 

	SELECT 
		m.sporttype, 
		m.betstatus, 
		m.leagueid,
		m.matchid,		 
		m.matchcode,
		m.eventdate, 
		m.globalshowtime as kickofftime,
		m.homeID,
		m.awayID,
		m.hthomescore,
		m.htawayscore, 
		m.finalhomescore,
		m.finalawayscore,
		m.eventstatus,
		m.showtime,
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
		m.goalrecord,
		CASE WHEN ISNULL(m.homeid2,0) = 0 AND m.sporttype = 162 THEN 1101 ELSE homeid2 END as homeid2, 
		ISNULL(mr.IsHTCal,0) as IsHTCal,
		ISNULL(mr.calculate,0) as calculate	,
		ISNULL(mr.IsPending,0) as IsPending	
	FROM  dbo.Match m WITH (NOLOCK)
		LEFT JOIn dbo.match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
	WHERE m.MatchId = @matchid
	UNION ALL 
		SELECT 
		m.sporttype, 
		m.betstatus, 
		m.leagueid,
		m.matchid,		 
		m.matchcode,
		m.eventdate, 
		m.globalshowtime as kickofftime,
		m.homeID,
		m.awayID,
		m.hthomescore,
		m.htawayscore, 
		m.finalhomescore,
		m.finalawayscore,
		m.eventstatus,
		m.showtime,
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
		m.goalrecord,
		CASE WHEN ISNULL(m.homeid2,0) = 0 AND m.sporttype = 162 THEN 1101 ELSE homeid2 END as homeid2,  -- contains bettype of Live Casino 
		ISNULL(mr.IsHTCal,0) as IsHTCal,
		ISNULL(mr.calculate,0) as calculate	,
		ISNULL(mr.IsPending,0) as IsPending	
	FROM  dbo.Match14 m WITH (NOLOCK)
		LEFT JOIn dbo.match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
	WHERE m.MatchId = @matchid	


	SELECT	MatchId
			,ResourceId
			,HomeValue
			,AwayValue
			,ResultStatusID
			,SettlementStatusID
	FROM	dbo.ResultDetail WITH (NOLOCK)
	WHERE	MatchId = @MatchId
	UNION ALL
	SELECT	MatchId
			,ResourceId
			,HomeValue
			,AwayValue
			,ResultStatusID
			,SettlementStatusID
	FROM	dbo.ResultDetail14 WITH (NOLOCK)
	WHERE	MatchId = @MatchId
	
END
GO
GRANT EXECUTE ON [dbo].Lrf_Result_MatchSelByLeague_Detail  TO bodbLicenseeNet 
GO
GRANT EXECUTE ON [dbo].Lrf_Result_MatchSelByLeague_Detail  TO vnteam  
