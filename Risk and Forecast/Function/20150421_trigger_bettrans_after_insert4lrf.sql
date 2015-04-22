USE [bodb02]
GO


ALTER TRIGGER [dbo].[bettrans_after_insert4lrf]
   ON [dbo].[bettrans]
   AFTER INSERT
AS 
/*          
Created: 
Task: 
DB: DB052.bodb02          
Revisions:        
 + 20130809@Don: Add column "betfrom"
 + 20150130@Jim: support sporting solution
 + 20150421@Jim: add column betcheck
*/    
BEGIN
	 -- SET NOCOUNT ON added to prevent extra result sets from
	 -- interfering with SELECT statements.
	 SET NOCOUNT ON;

	 --### DECLARE VARIABLE
	 DECLARE @recommend int,@Custid int,@LicenseeID int,@UserName2  varchar(50),@SpecialLevel int,@desc varchar(100)
	 DECLARE @bettype INT,@transid bigint,@transid_ins bigint

	 SELECT 
		  @recommend=inserted.recommend,
		  @Custid=inserted.Custid,
		  @bettype=inserted.bettype,
		  @transid_ins=inserted.transid
	 FROM inserted
	 
	 IF (@bettype > 31 AND @bettype<121)
		OR (@bettype > 999 AND @bettype<1301)
		OR (@bettype>1399) --SPORTBOOK ONLY;
	  RETURN;  
	 --### checking this ticket belonging Licensee 
	 SELECT 
		  @LicenseeID=isnull(LicenseeID,0),
		  @desc=isnull([Description],'')
	 FROM bodb_Licensee.dbo.LicenseeCust ag WITH (nolock)
	 WHERE ag.custid = @Recommend  AND
		   ag.roleid = 2 
			--and sg.LicenseeID = 14 --SUPPORT BODOG 
	 IF  @Licenseeid > 0
	 BEGIN 
		  SELECT 
			   @UserName2=isnull(UserName2,''), 
			   @SpecialLevel=isnull(SpecialLevel,'')
		  FROM bodb_Licensee.dbo.LicenseeCustinfo ci with (nolock)
		  WHERE ci.custid = @Custid 
		  
		  INSERT INTO dbo.bettrans_lrf_betRunning (
		  LicenseeID, matchid, bettype, transid, refno, transdate, betid, livehomescore, liveawayscore, liveindicator,
		  hdp1, hdp2, odds, actual_stake, stake,  statusID, betteam,  OddsType, currency, 
		  UserName,  UserName2, SpecialLevel, [Description],Recommend, betfrom,betcheck)

		  SELECT
			   @LicenseeID LicenseeID, 
			   b.matchid, bettype, transid, refno, transdate, betid, b.livehomescore, b.liveawayscore, liveindicator,
			   hdp1, hdp2, b.odds, actual_stake, stake, b.statusID, betteam,  OddsType, b.currency, 
			   b.UserName,  @UserName2, @SpecialLevel,@desc [Description],@recommend, betfrom,betcheck
		  FROM INSERTED B 
		  
		  IF @@ROWCOUNT > 0
		  BEGIN  
		   
			   Declare @cntTB TABLE (name nvarchar(128), [rows] char(11), reserved varchar(18), data varchar(18), index_size varchar(18), unused varchar(18))
			   declare @cnt int
			   
			   INSERT INTO @cntTB
			   exec sp_spaceused bettrans_lrf_betRunning

			   SELECT @cnt = [rows] FROM @cntTB
			   
			   IF (@cnt % 250) = 0
			   BEGIN
					--### DELETE OLD TICKET( ONE LICENSEE - 3000 TICKET)
					SELECT @transid = transid
					FROM(
					 SELECT ROW_NUMBER() OVER (PARTITION BY LicenseeID ORDER BY TransID DESC) RN, br.transid
					 FROM dbo.bettrans_lrf_betRunning br with (nolock)
					 WHERE LicenseeID = @LicenseeID
					 ) a
					WHERE RN=3000       
					
					DELETE bettrans_lrf_betRunning WITH(ROWLOCK,UPDLOCK)
					WHERE LicenseeId = @Licenseeid and transid < @transid  
			   END    
			
		  END  
	END
END 