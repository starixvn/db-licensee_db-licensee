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
*/
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
		isPending	BIT
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
			isPending
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
						m.kickofftime,
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
						isnull(mr.IsPending,0) as IsPending	
		FROM(	SELECT b.matchId FROM BettransM b WITH (NOLOCK) WHERE b.refno = @refno ) bM
				INNER JOIN match m WITH(NOLOCK) ON bM.matchid = m.matchid
				LEFT OUTER JOIN match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
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
			isPending
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
				m.kickofftime,
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
				isnull(mr.IsPending,0) as IsPending
		FROM(	SELECT b.matchId FROM BettransM14 b WITH (NOLOCK) WHERE b.refno = @refno ) bM
				INNER JOIN match14 m WITH(NOLOCK) ON bM.matchid = m.matchid
				LEFT OUTER JOIN match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
	END
	IF EXISTS (SELECT 1 FROM DB06.bodb_archive.dbo.BettransM  WITH (NOLOCK) WHERE  refno = @refno)
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
			isPending
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
				m.kickofftime,
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
				isnull(mr.IsPending,0) as IsPending
		FROM(	SELECT b.matchId FROM DB06.bodb_archive.dbo.BettransM b (NOLOCK) WHERE b.refno = @refno ) bM
				INNER JOIN DB06.bodb_archive.dbo.match_BK m WITH(NOLOCK) ON bM.matchid = m.matchid
				LEFT OUTER JOIN match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
	END
	SELECT * FROM @tmpParlay
	ORDER BY LeagueID, eventdate, matchcode	
END
GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelMatchResultParlay] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelMatchResultParlay] TO [vnteam]
