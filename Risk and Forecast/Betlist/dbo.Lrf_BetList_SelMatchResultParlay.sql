USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Lrf_BetList_SelMatchResultParlay]
	@refno			BIGINT
AS
/*
Created: henry@20101210
Task : SELECT MixParlay result
DB: DB052.bodb02
Original: Age_BetList_SelMatchResultParlay
Revisions:
    - 20110907@Sophia: Add column IsHTCal, calculate for Pending result.
    - 20110927@Henry: add more columns
	- 20131017@Jim: Turn to use GlobalShowTime for display the Kick-off-Time
	- 20141021@Jim : support to show Sportting Solution data detail 
*/
-- Lrf_BetList_SelMatchResultParlay_xtest @refno=100525448833
BEGIN
	SET NOCOUNT ON
	DECLARE	@tmpParlay TABLE(
		sporttype	INT,
		leagueid	INT,
		matchid		INT,
		homeID		INT,
		awayID		INT,
		hthomescore	INT,
		htawayscore	INT,
		finalhomescore INT,
		finalawayscore INT,
		kickofftime DATETIME,
		eventdate	DATETIME,
		isNeutral	BIT,
		betstatus	VARCHAR(50),
		eventstatus	VARCHAR(15),
		IsRefund	BIT,
		IsCalRefund	BIT,
		goalrecord	VARCHAR(50),
		matchcode	VARCHAR(50),
		isHTCal		BIT,
		calculate	BIT,
		isPending	BIT,
		Bettype		SMALLINT,
		Betcheck	VARCHAR(50)
	)
	DECLARE @tmpResultDetail AS TABLE (
		MatchId INT ,
		ResourceId VARCHAR(20),
		HomeValue VARCHAR(20),
		AwayValue VARCHAR(20),
		ResultStatusID TINYINT,
		SettlementStatusID TINYINT
	)
	
	IF EXISTS (SELECT 1 FROM bettransm WITH (NOLOCK) WHERE  refno = @refno)
	BEGIN
		INSERT INTO @tmpParlay (
			sporttype, 	
			LeagueID,
			matchid, 	
			homeID,
			awayID,
			hthomescore,
			htawayscore,		
			finalhomescore,
			finalawayscore,
			kickofftime,
			eventdate,
			isNeutral,
			betstatus, 	
			eventstatus,
			IsRefund ,
			IsCalRefund,
			goalrecord,
			matchcode,
			isHTCal,
			calculate,
			isPending,
			Bettype,
			Betcheck
			
		)
		SELECT	m.sporttype, 	
				m.LeagueID,
				m.matchid, 	
				m.homeID,
				m.awayID,
				hthomescore,
				htawayscore,		
				m.finalhomescore,
				m.finalawayscore,
				CASE WHEN m.sporttype NOT IN (162,161)
					THEN m.GlobalShowTime
					ELSE m.kickofftime
					END kickofftime,
				m.eventdate,
				m.isNeutral,
				m.betstatus, 	
				case when m.betstatus like 'Refund FT%' then 'Refund FT' 
					 when m.betstatus like 'Refund HT%' then 'Refund HT'
					 when m.betstatus like 'Refund%' then 'Refund' 
					else m.eventstatus end as eventstatus, 
				isnull(mr.refund,0) IsRefund ,
				isnull(mr.calrefund,0) IsCalRefund,
				m.goalrecord,
				m.matchcode,
				ISNULL(mr.isHTCal,0) as isHTCal,
				ISNULL(mr.calculate,0) as calculate,
				ISNULL(mr.IsPending,0) as IsPending,	
				bm.Bettype, 
				bm.Betcheck 
		FROM(	SELECT b.matchId, b.Bettype, b.Betcheck  FROM BettransM b WITH (NOLOCK) WHERE b.refno = @refno ) bM
				INNER JOIN match m WITH(NOLOCK) ON bM.matchid = m.matchid
				LEFT OUTER JOIN match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
				
		INSERT INTO @tmpResultDetail
		SELECT		D.MatchId,
					D.ResourceId,
					D.HomeValue,
					D.AwayValue,
					D.ResultStatusID,
					D.SettlementStatusID
		FROM	dbo.ResultDetail D WITH (NOLOCK)
			    INNER JOIN @tmpParlay P ON D.MatchId = P.MatchId		
		WHERE	CASE WHEN P.Bettype NOT IN (1324) THEN 2 ELSE 
					CASE WHEN P.Bettype IN (1324) AND LEFT(D.ResourceId,2) = LEFT(P.BetCheck,2) THEN 4 
						ELSE 0 END END = LEN(D.ResourceId)
		
	END
	IF EXISTS (SELECT 1 FROM bettransm14 WITH (NOLOCK) WHERE  refno = @refno)
	BEGIN
		INSERT INTO @tmpParlay (
			sporttype, 	
			LeagueID,
			matchid, 	
			homeID,
			awayID,
			hthomescore,
			htawayscore,		
			finalhomescore,
			finalawayscore,
			kickofftime,
			eventdate,
			isNeutral,
			betstatus, 	
			eventstatus,
			IsRefund ,
			IsCalRefund,
			goalrecord,
			matchcode,
			isHTCal,
			calculate,
			isPending,
			Bettype, 
			Betcheck
		)

		SELECT	m.sporttype, 	
				m.LeagueID,
				m.matchid, 	
				m.homeID,
				m.awayID,
				hthomescore,
				htawayscore,		
				m.finalhomescore,
				m.finalawayscore,
				CASE WHEN m.sporttype NOT IN (162,161)
				THEN m.GlobalShowTime
				ELSE m.kickofftime
				END kickofftime,
				m.eventdate,
				m.isNeutral,
				m.betstatus, 	
				case when m.betstatus like 'Refund FT%' then 'Refund FT' 
					 when m.betstatus like 'Refund HT%' then 'Refund HT'
					 when m.betstatus like 'Refund%' then 'Refund' 
					else m.eventstatus end as eventstatus, 
				isnull(mr.refund,0) IsRefund ,
				isnull(mr.calrefund,0) IsCalRefund,
				m.goalrecord,
				m.matchcode, 
				ISNULL(mr.isHTCal,0) as isHTCal,
				ISNULL(mr.calculate,0) as calculate,
				ISNULL(mr.IsPending,0) as IsPending,
				bm.Bettype, 
				bm.Betcheck 
		FROM(	SELECT b.matchId, b.Bettype,  Betcheck FROM BettransM14 b WITH (NOLOCK) WHERE b.refno = @refno ) bM
				INNER JOIN match14 m WITH(NOLOCK) ON bM.matchid = m.matchid
				LEFT OUTER JOIN match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
		INSERT INTO @tmpResultDetail
		SELECT		D.MatchId,
					D.ResourceId,
					D.HomeValue,
					D.AwayValue,
					D.ResultStatusID,
					D.SettlementStatusID
		FROM	dbo.ResultDetail14 D WITH (NOLOCK)
			   INNER JOIN @tmpParlay P 
				ON D.MatchId = P.MatchId		
		WHERE	CASE WHEN P.Bettype NOT IN (1324) THEN 2 ELSE 
					CASE WHEN P.Bettype IN (1324) AND LEFT(D.ResourceId,2) = LEFT(P.BetCheck,2) THEN 4 
						ELSE 0 END END = LEN(D.ResourceId)
							
	END
	IF EXISTS (SELECT 1 FROM DBARC.bodb_archive.dbo.BettransM  WITH (NOLOCK) WHERE  refno = @refno)
	BEGIN
		INSERT INTO @tmpParlay (
			sporttype, 	
			LeagueID,
			matchid, 	
			homeID,
			awayID,
			hthomescore,
			htawayscore,		
			finalhomescore,
			finalawayscore,
			kickofftime,
			eventdate,
			isNeutral,
			betstatus, 	
			eventstatus,
			IsRefund ,
			IsCalRefund,
			goalrecord,
			matchcode,
			isHTCal,
			calculate,
			isPending,
			Bettype, 
			Betcheck
		)
		SELECT	m.sporttype, 
				m.LeagueID,
				m.matchid, 			
				m.homeID,
				m.awayID,
				hthomescore,
				htawayscore,		
				m.finalhomescore,
				m.finalawayscore,
				CASE WHEN m.sporttype NOT IN (162,161)
					THEN m.GlobalShowTime
					ELSE m.kickofftime
					END kickofftime,
				m.eventdate,
				m.isNeutral,
				m.betstatus, 	
				case when m.betstatus like 'Refund FT%' then 'Refund FT' 
					 when m.betstatus like 'Refund HT%' then 'Refund HT'
					 when m.betstatus like 'Refund%' then 'Refund' 
					else m.eventstatus end as eventstatus, 
				isnull(mr.refund,0) IsRefund ,
				isnull(mr.calrefund,0) IsCalRefund,
				m.goalrecord,
				m.matchcode,
				ISNULL(mr.isHTCal,0) as isHTCal,
				ISNULL(mr.calculate,0) as calculate,
				ISNULL(mr.IsPending,0) as IsPending,
				bm.Bettype, 
				bm.Betcheck 
		FROM(	SELECT b.matchId, b.Bettype, Betcheck FROM DBARC.bodb_archive.dbo.BettransM b (NOLOCK) WHERE b.refno = @refno ) bM
				INNER JOIN DBARC.bodb_archive.dbo.match_BK m WITH(NOLOCK) ON bM.matchid = m.matchid
				LEFT OUTER JOIN match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
		
		INSERT INTO @tmpResultDetail
		SELECT		D.MatchId,
					D.ResourceId,
					D.HomeValue,
					D.AwayValue,
					D.ResultStatusID,
					D.SettlementStatusID
		FROM	DBARC.bodb_archive.dbo.ResultDetail_BK D WITH (NOLOCK)
			INNER JOIN @tmpParlay P 
				ON D.MatchId = P.MatchId		
		WHERE	CASE WHEN P.Bettype NOT IN (1324) THEN 2 ELSE 
					CASE WHEN P.Bettype IN (1324) AND LEFT(D.ResourceId,2) = LEFT(P.BetCheck,2) THEN 4 
						ELSE 0 END END = LEN(D.ResourceId)
							
	END
	SELECT * FROM @tmpParlay
	ORDER BY LeagueID, eventdate, matchcode	
	SELECT DISTINCT * FROM @tmpResultDetail
	ORDER BY MatchID, ResourceId
END
GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelMatchResultParlay] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelMatchResultParlay] TO [vnteam]