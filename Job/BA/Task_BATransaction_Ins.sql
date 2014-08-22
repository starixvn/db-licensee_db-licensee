ALTER PROCEDURE [dbo].[Task_BATransaction_Ins]  
AS  
/*  
 Created by:[Henry]  
 Date: 2011-06-20  
 Task: Insert BA Bets to LicenseeBATransaction  
 DB: DB05.BODB02  
 Revisions:   
  20110824@Henry: Change the range of the bettype (not between 31 and 120)  
  20110909@Viet: revise SP  
  20111208@Jim: Change bettype condition  
  20100315@kIWI: Remove @TempBACustID table   
  20121030@Viet: change the way to get data, reduce load for server.  
 */  
SET NOCOUNT ON   
  
 DECLARE @temptrans AS TABLE (transid BIGINT, transdate DATETIME, custid int, recommend int, srecommend int)  
    
 declare @smallID BIGINT, @maxtransID bigint, @currentDate DATETIME    
 -- scan each transid twice to prevent missing by locking  
 SELECT @smallID = cast(isnull(vvalue,0) as bigint)  
 FROM bodb_licensee.dbo.LICSettings with(rowlock)   
 WHERE vname = 'BA_transid'   
  
 SELECT @maxtransID = max(transid) FROM dbo.bettrans with(nolock)   
       
 UPDATE bodb_licensee.dbo.LICSettings with(rowlock, updlock)  
 SET vvalue = vvalue2  
  ,vvalue2 = cast(@maxtransID as varchar(200))  
 WHERE vname = 'BA_transid'  
  
 INSERT INTO @temptrans (transid, transdate, custid, recommend, srecommend)  
 SELECT transid, transdate, custid, recommend, srecommend
 FROM dbo.bettrans WITH(NOLOCK)     
 WHERE TransID BETWEEN @smallID AND @maxtransID  
  AND (Bettype < 31 OR (bettype between 121 and 999))  
  AND StatusID <> 121 --DONE  
  AND tpositiontaking = 0    
  
 IF @@ROWCOUNT = 0 RETURN  
   
 DELETE @temptrans  
 WHERE custid not in (  
   SELECT CustID   
   FROM bodb_Licensee.dbo.LicenseeBAHistory WITH (NOLOCK)   
   WHERE Status = 'Running'  
    OR (Status = 'Done'  
     AND DATEDIFF(MINUTE,OffDate,CURRENT_TIMESTAMP)<=2)  
  )  
   
 DELETE t   
 FROM @temptrans t  
  INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction ba WITH(NOLOCK) ON t.TransID = ba.TransID  
   
 INSERT INTO Bodb_Licensee.dbo.LicenseeBATransaction (TransID, Transdate)  
 SELECT TransID, Transdate   
 FROM @temptrans  
  
 INSERT INTO Bodb_Licensee.dbo.LicenseeBATransaction_active (TransID, Transdate, custid, recommend, srecommend)  
 SELECT TransID, Transdate, custid, recommend, srecommend  
 FROM @temptrans  
 
GO
GRANT VIEW DEFINITION ON [dbo].[Task_BATransaction_Ins] TO [vnteam] AS [dbo]