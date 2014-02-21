USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_Result_RaceSelByMeeting]    Script Date: 02/21/2014 00:20:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Lrf_Result_RaceSelByMeeting    Script Date: 12/12/2013 3:38:52 AM ******/
/****** Object:  Stored Procedure dbo.Lrf_Result_RaceSelByMeeting    Script Date: 12/10/2013 4:57:39 PM ******/


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
		- 20131129@Jim: support :
				182 – Virtual Greyhounds
				184 – Virtual Motor Racing

*/
BEGIN
	SET NOCOUNT ON 
	CREATE TABLE #Data (meetingid INT
							,eventdate DATETIME
							,kickofftime DATETIME
							,lcolor nvarchar(50)
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
	IF (@Sporttype IN (151,152,153))
	BEGIN
		INSERT INTO #Data
		SELECT   o.leagueid meetingid,
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
			(	SELECT	leagueid, teamid, eventdate, kickofftime, groupmatch, matchcode, placing, oddsstatus, odds, placeodds, IsFavor, IsSCR, FOddsStatus FROM outright o with (nolock) WHERE eventdate=@FromDate
				UNION 
				SELECT	leagueid, teamid, eventdate, kickofftime, groupmatch, matchcode, placing, oddsstatus, odds, placeodds, IsFavor, IsSCR, 'completed' FOddsStatus FROM outright14 o with (nolock) WHERE eventdate=@FromDate
				UNION 
				SELECT	leagueid, teamid, eventdate, kickofftime, groupmatch, matchcode, placing, oddsstatus, odds, placeodds, IsFavor, IsSCR, 'completed' FOddsStatus FROM DB06.bodb_Archive.dbo.outright_bk o with (nolock) WHERE eventdate=@FromDate
			 ) o 
			INNER JOIN league l WITH (NOLOCK) ON o.leagueid = l.leagueid 
		WHERE	 l.sporttype =  @Sporttype
				AND o.leagueid = CASE WHEN @leagueid =0 THEN o.leagueid 
								 ELSE @leagueid END 
				AND (oddsstatus ='completed'  OR FoddsStatus='completed')
				AND l.isTest = isnull(@isShowAll, l.isTest)
				--AND o.placing<5
				--AND ISNULL( o.placing,0)<>0
		ORDER BY o.leagueid, CAST(o.groupmatch AS INT), o.placing
		
		SELECT meetingid,racename,COUNT(place) rc INTO #DataSUM
		FROM #Data
		WHERE place<5
		GROUP BY   meetingid,racename
		
		SELECT 	d.meetingid
				,d.racename
				,temp.results as TF
				,temp2.results2 as SCR
			INTO #tmp	
		FROm #Data d
		INNER JOIN #DataSum d2 ON d.meetingid=d2.meetingid AND  d.racename=d2.racename
		CROSS APPLY  (
					  SELECT STUFF (
									(
									SELECT  CAST(horseNo AS VARCHAR(10))+ ',' 
												
									FROM #Data d
									WHERE d.meetingid=d2.meetingid AND  d.racename=d2.racename  AND d.IsFavor<>'0' 
									for xml path(''), type).value('.','varchar(max)')
									,1,2,''
									)
					  )temp(results)	
		
		CROSS APPLY  (
					  SELECT STUFF (
									(
									SELECT CAST(horseNo AS VARCHAR(10))+ ',' 
									FROM #Data d
									WHERE d.meetingid=d2.meetingid AND  d.racename=d2.racename  AND d.IsSCR<>0
									for xml path(''), type).value('.','varchar(max)')
									,1,2,''
									)
					  )temp2(results2)	
		ORDER BY d.meetingid,d.racename,d.place
		
		SELECT  DISTINCT
				d.*
				,d3.TF
				,d3.SCR		
				,d2.rc as [RowCount]  
		FROm #Data d
		INNER JOIN #DataSum d2 ON d.meetingid=d2.meetingid AND  d.racename=d2.racename
		INNER JOIN #tmp d3 ON d.meetingid=d3.meetingid AND  d.racename=d3.racename
		WHERE d.place<5 
		ORDER BY d.meetingid,d.racename,d.place
		
		DROP TABLE #DataSum 
		DROP TABLE #tmp
		
	END
	IF (@Sporttype IN (181,182,184))
	BEGIN 
		INSERT INTO #Data	
		SELECT  o.leagueid meetingid,
				o.eventdate,
				o.kickofftime, 
				o.lcolor,
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
				  vso.Colours lcolor,
				   vso.EventDate,
				   vsr.EventTime kickofftime,
				   NULL groupmatch,
				  CONVERT(VARCHAR(20),vso.RacerNum)  matchcode,
				   vso.placing,
				   vsr.EventStatus oddsstatus,
					vso.Winodds odds,
				   vso.PlaceOdds,
				  CONVERT(VARCHAR(20),vso.IsFavor) IsFavor,
				   NULL IsSCR,
				   '' FOddsStatus
			FROM dbo.VSOutright vso WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo vsr with (nolock) ON vso.EventID=vsr.EventID
				WHERE eventdate = @FromDate 
					AND leagueid = CASE WHEN @leagueid =0 THEN leagueid 
									 ELSE @leagueid END 
					AND placing<5
					AND ISNULL(placing,0)<>0
					AND vsr.SportType=@Sporttype
					AND vsr.EventStatus ='completed'
			UNION ALL 
			SELECT vsr.leagueid,
				   vso14.RacerID teamid,
				   vso14.Colours lcolor,
				   vso14.EventDate,
				   vsr.EventTime kickofftime,
				   NULL groupmatch,
				   CONVERT(VARCHAR(20),vso14.RacerNum) matchcode,
				   vso14.placing,
				   vsr.EventStatus  oddsstatus,
				   vso14.Winodds odds,
				   vso14.PlaceOdds,
				   CONVERT(VARCHAR(20),vso14.IsFavor) IsFavor,
				   NULL IsSCR,
				   '' FOddsStatus
			FROM dbo.VSOutright14 vso14 WITH (NOLOCK)
			INNER JOIN dbo.VSRaceInfo vsr with (nolock) ON vso14.EventID=vsr.EventID	
				WHERE eventdate = @FromDate 
					AND leagueid = CASE WHEN @leagueid =0 THEN leagueid 
									 ELSE @leagueid END 
					AND placing<5
					AND ISNULL( placing,0)<>0
					AND vsr.SportType=@Sporttype
					AND vsr.EventStatus ='completed'
			UNION ALL 
			SELECT vsr.leagueid,
				   bk.RacerID teamid,
				   '' as  lcolor,
				   bk.EventDate,
				   vsr.EventTime kickofftime,
				   NULL groupmatch,
				   CONVERT(VARCHAR(20),bk.RacerNum) matchcode,
				   bk.placing,
				   vsr.EventStatus  oddsstatus,
				   bk.Winodds odds,
				   bk.PlaceOdds,
				   CONVERT(VARCHAR(20),bk.IsFavor) IsFavor,
				   NULL IsSCR,
				   '' FOddsStatus
			FROM DBARC.bodb_Archive.dbo.VSOutright_bk bk WITH (NOLOCK)
			INNER JOIN dbo.VSRaceInfo vsr with (nolock) ON bk.EventID=vsr.EventID	
				WHERE eventdate = @FromDate 
					AND leagueid = CASE WHEN @leagueid =0 THEN leagueid 
									 ELSE @leagueid END 
					AND placing<5
					AND ISNULL( placing,0)<>0	
					AND vsr.SportType=@Sporttype
					AND vsr.EventStatus ='completed'	
			 ) o 
			INNER JOIN dbo.HRCode c WITH (NOLOCK) ON c.CodeID=o.teamid
			--WHERE	c.CodeType=11
			ORDER BY o.leagueid, o.kickofftime
				
	SELECT kickofftime,COUNT(place) rc INTO #DataSUMVHR
	FROM #Data
	GROUP BY  kickofftime

	SELECT d.*,'' TF,'' SCR , d2.rc as [RowCount]  
	FROm #Data d
	INNER JOIN #DataSumVHR d2 ON d.kickofftime=d2.kickofftime 
	ORDER BY meetingid, kickofftime,place
	DROP TABLE #DataSumVHR 
			
	END
	
	DROP TABLE #Data

 END