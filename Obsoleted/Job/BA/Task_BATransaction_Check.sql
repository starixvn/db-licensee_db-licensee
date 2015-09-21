use bodb02
go

ALTER PROCEDURE [dbo].[Task_BATransaction_Check]  
AS  
/*  
Created by:[Henry]  
Date: 2011-06-20  
Task: Check missing BA tickets  
DB: DB052.BODB02  
Revisions:   
    20110824@Henry: Insert the missing tickets if happen  
 20110905@Jamie: Modify remove comma ','  
 20111208@Jim: change bettype condition   
 20150204@Don: Expand bet type ranges for Sportbook when processing BA  
 20150904@Patrick: Exclude bettype 901 for bettrade
 */  
SET NOCOUNT ON   
   
 --Query data with DONE status  
DECLARE @BATransaction TABLE (custid INT, transid BIGINT, transdate DATETIME)  
  
DECLARE @BAHistory_Done TABLE (custid INT, ondate DATETIME, offdate DATETIME)  
INSERT INTO @BAHistory_Done  
SELECT custid, ondate, offdate  
FROM bodb_Licensee.dbo.LicenseeBAHistory WITH (nolock)  
WHERE   
 LicenseeID IN (SELECT LicenseeID FROM bodb_Licensee.dbo.LicenseeBAConfig (NOLOCK) WHERE EnableBA = 1)  
 AND status = 'Done'  
  
DECLARE @custid INT, @ondate DATETIME, @offdate DATETIME, @cnt INT  
StartLoop:  
    SELECT TOP 1 @custid = custid, @ondate = ondate, @offdate = offdate FROM @BAHistory_Done  
         
    SELECT @cnt = @@ROWCOUNT  
    IF @cnt = 0 GOTO EndLoop  
  
        INSERT INTO @BATransaction  
        SELECT custid, transid, transdate  
        FROM bettrans WITH (NOLOCK)  
        WHERE custid = @custid  
            AND transdate BETWEEN @ondate AND @offdate  
            AND tpositiontaking = 0  
            AND (bettype < 31 OR (bettype BETWEEN 121 AND 999) OR (bettype BETWEEN 1301 AND 1399))  
			AND bettype <> 901
                   
    DELETE FROM @BAHistory_Done WHERE custid = @custid AND ondate = @ondate AND offdate = @offdate  
  
    GOTO StartLoop  
EndLoop:  
  
--Query data with Running status  
DECLARE @BAHistory_Running TABLE (custid INT, ondate DATETIME)  
INSERT INTO @BAHistory_Running  
SELECT custid, ondate  
FROM bodb_Licensee.dbo.LicenseeBAHistory WITH (NOLOCK)  
WHERE   
LicenseeID IN (SELECT LicenseeID FROM bodb_Licensee.dbo.LicenseeBAConfig (NOLOCK) WHERE EnableBA = 1)  
AND STATUS = 'running'  
  
DECLARE @custid_r INT, @ondate_r DATETIME, @cnt_r INT  
StartLoop_r:  
    SELECT TOP 1 @custid_r = custid, @ondate_r = ondate FROM @BAHistory_Running  
         
    SELECT @cnt_r = @@ROWCOUNT  
    IF @cnt_r = 0 GOTO EndLoop_r  
  
        INSERT INTO @BATransaction  
        SELECT custid, transid, transdate  
        FROM bettrans WITH (NOLOCK)  
        WHERE custid = @custid_r  
            AND transdate >= @ondate_r  
            AND tpositiontaking =0  
            AND (bettype < 31 OR (bettype BETWEEN 121 AND 999) OR (bettype BETWEEN 1301 AND 1399))  
			AND bettype <> 901
         
    DELETE FROM @BAHistory_Running WHERE custid = @custid_r AND ondate = @ondate_r  
  
    GOTO StartLoop_r  
EndLoop_r:  
  
IF (SELECT count(a.transid)   
FROM @BATransaction a  
 LEFT JOIN bodb_licensee.dbo.licenseebatransaction b (nolock) ON a.transid = b.transid  
WHERE b.transid IS NULL) > 0  
BEGIN  
 DECLARE @BATicket TABLE (TransID BIGINT, Transdate DATETIME)  
   
 INSERT INTO @BATicket(TransID, Transdate)  
 SELECT a.transid,a.transdate FROM @BATransaction a  
 LEFT JOIN bodb_licensee.dbo.licenseebatransaction b (nolock) ON a.transid = b.transid  
 WHERE b.transid IS NULL  
   
 DECLARE @tickets VARCHAR(7500)  
 DECLARE @alert VARCHAR(8000),   
   @currentMaxTransID VARCHAR(50)  
   
 SELECT @tickets=''  
 SELECT @tickets =@tickets  + CAST(TransID AS varchar(20)) +','  
 FROM @BATicket    
  
 IF LEN(RTRIM(LTRIM(@tickets)))>1  
 BEGIN  
  INSERT INTO bodb_licensee.dbo.licenseebatransaction (TransID,Transdate)  
  SELECT transid,transdate FROM @BATicket  
    
    
  INSERT INTO bodb_licensee.dbo.licenseebatransaction_active (TransID,Transdate, custid, recommend, srecommend)  
  SELECT transid, transdate, custid, recommend, srecommend  
  FROM dbo.bettrans with(nolock)  
  where transid in (select transid from @BATicket)  
  
  SELECT @currentMaxTransID = VValue  
  FROM DBTRANS.BODB02.DBO.SystemSettings WITH (NOLOCK)  
  WHERE VName='MaxTransID'  
  
  SELECT @tickets = substring(@tickets,0,len(@tickets)) --remove last comma  
  SELECT @alert = 'Missing one or more BA tickets: ' + @tickets + ' .The job has just inserted the missing tickets.' + ' Current Max TransID:' + @currentMaxTransID  
  RAISERROR (@alert, 16, 1)    
  
 END  
END

GO
GRANT VIEW DEFINITION ON [dbo].[Task_BATransaction_Check] TO [vnteam]