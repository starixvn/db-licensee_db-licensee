IF EXISTS (SELECT * FROM sysobjects WHERE type = 'P' AND name = 'Lrf_Result_MatchSelNumberGameByLeague')
	BEGIN
		DROP  Procedure  Lrf_Result_MatchSelNumberGameByLeague
	END

GO

CREATE PROCEDURE [dbo].[Lrf_Result_MatchSelNumberGameByLeague]    
 @FromDate DATETIME,    
 @ToDate DATETIME = NULL,  
 @LeagueID INT,    
 @Language NVARCHAR(2) = 'E'  
AS    
/*  
Created: 20101201@Jacob  
Task: Get Number Game result by league  
DB: DB052.bodb02  
Original: Age_Result_MatchSelNumberGameByLeague  
  
Revisions:   
 20101201@Jacob: Copy source code from Age_Result_MatchSelNumberGameByLeague
  
*/  
  
SET NOCOUNT ON    
  
IF @ToDate IS NULL  
BEGIN  
 SELECT @ToDate = DATEADD(s,-1, DATEADD(d, 1, @FromDate))    
END    
SELECT     
 m.betstatus,     
 m.leagueid,    
 m.matchid,  
 m.matchcode,    
 m.eventdate,     
 m.kickofftime,  
 m.homeid,  
 CASE WHEN m.betstatus LIKE 'Refund FT%' THEN 'Refund FT'     
   WHEN m.betstatus LIKE 'Refund HT%' THEN 'Refund HT'    
   WHEN m.betstatus LIKE 'Refund%' THEN 'Refund'     
   ELSE m.eventstatus END AS eventstatus,  
 CASE WHEN m.betstatus LIKE 'Refund' THEN 1     
   ELSE 0 END AS IsRefund,  
 b.seq,  
 b.number  
 FROM    
   (SELECT sporttype, betstatus, matchid, matchcode, leagueid, eventdate, eventstatus, kickofftime, homeid    
 FROM MATCH (NOLOCK)    
    WHERE eventdate BETWEEN  @FromDate  AND  @ToDate   
   AND sporttype=161  
   AND (@LeagueID = 0 OR leagueid = @LeagueID)  
 UNION ALL    
 SELECT sporttype, betstatus, matchid, matchcode, leagueid, eventdate, eventstatus, kickofftime,homeid     
 FROM match14 (NOLOCK)    
 WHERE eventdate BETWEEN  @FromDate  AND  @ToDate   
   AND sporttype=161  
   AND (@LeagueID = 0 OR leagueid = @LeagueID)  
   )AS m   
 LEFT OUTER JOIN (SELECT matchid, seq, number FROM bingoball(NOLOCK)  
    UNION ALL  
    SELECT matchid, seq, number FROM bingoball14(NOLOCK)  
    ) AS B ON B.matchid = m.matchid  
 LEFT OUTER JOIN match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid    
WHERE m.eventstatus NOT IN ('internal','running')    
   OR (m.eventstatus = 'running' AND mr.ishtcal=1)  
ORDER BY m.leagueid, m.matchid, b.seq  
  
  
  


GO
GRANT EXECUTE ON [dbo].[Lrf_Result_MatchSelNumberGameByLeague] TO [bodbLicenseeNet]
GO
GRANT EXECUTE ON [dbo].[Lrf_Result_MatchSelNumberGameByLeague] TO [vnteam]

GO


