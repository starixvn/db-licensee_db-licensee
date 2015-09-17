USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Lrf_Result_MatchSelByLeague_Detail]
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
	- 20150407@Sophia: Support to get BetRadar
	- 20150810@Sophia: Hardcode to exclude ResultDetail of bettype 216, 217 for a temporary time [#40991]

-------
EXEC Lrf_Result_MatchSelByLeague_Detail_xtest
	@MatchId = 10860032
*/
BEGIN 
	SET NOCOUNT ON 	 

	DECLARE @Sporttype TINYINT
		
	IF EXISTS (SELECT 1 FROM dbo.match WITH (NOLOCK) WHERE matchid = @matchid)
	BEGIN 		
		SELECT 
			m.sporttype, 
			m.betstatus, 
			m.leagueid,
			m.matchid,		 
			m.matchcode,
			m.eventdate, 
			CASE WHEN m.sporttype NOT IN (162,161,180,186)
					THEN m.GlobalShowTime
					ELSE m.kickofftime
					END kickofftime,
			m.homeID,
			m.awayID,
			m.hthomescore,
			m.htawayscore, 
			m.finalhomescore,
			m.finalawayscore,
			CASE m.Sporttype WHEN 5 THEN CASE ISNULL(R.SettlementStatusID,0)	 
											WHEN 1 THEN 'Refund' 
											WHEN 2 THEN 'Refund HT'
											WHEN 3 THEN 'Refund FT'
										ELSE m.eventstatus END 
									ELSE 
										CASE  WHEN m.betstatus like 'Refund FT%' THEN 'Refund FT' 
												WHEN m.betstatus like 'Refund HT%' THEN 'Refund HT'
												WHEN m.betstatus like 'Refund%' THEN 'Refund' 
										ELSE m.eventstatus END 
							END AS eventstatus,
			m.showtime,
			isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
			m.goalrecord,
			ISNULL(m.homeid2,0) as homeid2, 
			ISNULL(mr.IsHTCal,0) as IsHTCal,
			ISNULL(mr.calculate,0) as calculate	,
			ISNULL(mr.IsPending,0) as IsPending	
		FROM  dbo.Match m WITH (NOLOCK)
			LEFT JOIN dbo.match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail R WITH (NOLOCK) ON R.matchID = M.MatchID AND R.ResourceId = '00'
		WHERE m.MatchId = @matchid

		------------------------------------- 
		SELECT @Sporttype = Sporttype FROM dbo.Match m WITH (NOLOCK) WHERE MatchId = @matchid 	
		
		SELECT	MatchId
				,R.ResourceId
				,HomeValue
				,AwayValue
				,ResultStatusID
				,SettlementStatusID
				,OtherInfo
		FROM	dbo.ResultDetail R WITH (NOLOCK)
		WHERE	MatchID = @MatchId
				AND SettlementStatusID > 0
				AND ((@Sporttype = 1 AND R.ResourceId NOT IN ( '00', '01', '08') AND ( R.ResourceID NOT LIKE '217%' AND R.ResourceID NOT LIKE '216%'))
						OR @Sporttype = 5
						)
		ORDER BY  MatchID, R.ResourceId 

	END 
	ELSE 
	BEGIN 				
		SELECT 
			m.sporttype, 
			m.betstatus, 
			m.leagueid,
			m.matchid,		 
			m.matchcode,
			m.eventdate, 
			CASE WHEN m.sporttype NOT IN (162,161,180,186)
					THEN m.GlobalShowTime
					ELSE m.kickofftime
					END kickofftime,
			m.homeID,
			m.awayID,
			m.hthomescore,
			m.htawayscore, 
			m.finalhomescore,
			m.finalawayscore,
			CASE m.Sporttype WHEN 5 THEN CASE ISNULL(R.SettlementStatusID,0)	 
											WHEN 1 THEN 'Refund' 
											WHEN 2 THEN 'Refund HT'
											WHEN 3 THEN 'Refund FT'
										ELSE m.eventstatus END 
									ELSE 
										CASE  WHEN m.betstatus like 'Refund FT%' THEN 'Refund FT' 
												WHEN m.betstatus like 'Refund HT%' THEN 'Refund HT'
												WHEN m.betstatus like 'Refund%' THEN 'Refund' 
										ELSE m.eventstatus END 
							END AS eventstatus,
			m.showtime,
			isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
			m.goalrecord,
			ISNULL(m.homeid2,0) as homeid2,  
			ISNULL(mr.IsHTCal,0) as IsHTCal,
			ISNULL(mr.calculate,0) as calculate	,
			ISNULL(mr.IsPending,0) as IsPending	
		FROM  dbo.Match14 m WITH (NOLOCK)
			LEFT JOIn dbo.match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail14 R WITH (NOLOCK) ON R.matchID = M.MatchID AND R.ResourceId = '00'
		WHERE m.MatchId = @matchid	

		-----------------------------------
		SELECT @Sporttype = Sporttype FROM dbo.Match14 m WITH (NOLOCK) WHERE MatchId = @matchid 

		SELECT	MatchId
				,R.ResourceId
				,HomeValue
				,AwayValue
				,ResultStatusID
				,SettlementStatusID
				,OtherInfo
		FROM	dbo.ResultDetail14 R WITH (NOLOCK)
		WHERE	MatchID = @MatchId
				AND SettlementStatusID > 0
				AND ((@Sporttype = 1 AND R.ResourceId NOT IN ( '00', '01', '08') AND ( R.ResourceID NOT LIKE '217%' AND R.ResourceID NOT LIKE '216%'))
						OR @Sporttype = 5
						)
		ORDER BY  MatchID, R.ResourceId 
	END 
END
GO
GRANT EXECUTE ON [dbo].[Lrf_Result_MatchSelByLeague_Detail] TO [bodbLicenseeNet] 
GO
GRANT EXECUTE ON [dbo].[Lrf_Result_MatchSelByLeague_Detail] TO [vnteam] 