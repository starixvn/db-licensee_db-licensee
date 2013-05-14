ALTER PROC [dbo].[Lrf_CustomerUpdMember_All]  
 @LicenseeID INT,	
 @custid INT,--memberid  
 @UserID INT,      
 @IP varchar(15)='',   
 @Language VARCHAR(10)= 'en-us',  
 @Username varchar(30) = '' OUTPUT,
 @MinBet MONEY,  
 @MaxBet MONEY,  
 @MaxPerMatch MONEY,  
   
 @MinBetv2 MONEY,  
 @MaxBetv2 MONEY,  
 @MaxPerMatchv2 MONEY,  
  
 @MinBetv3 MONEY,  
 @MaxBetv3 MONEY,  
 @MaxPerMatchv3 MONEY,  
  
 @MinBetv5 MONEY,  
 @MaxBetv5 MONEY,  
 @MaxPerMatchv5 MONEY,  
  
 @MinBetv8 MONEY,  
 @MaxBetv8 MONEY,  
 @MaxPerMatchv8 MONEY,  
  
 @MinBetv10 MONEY,  
 @MaxBetv10 MONEY,  
 @MaxPerMatchv10 MONEY,  
  
 @MinBetv11 MONEY,  
 @MaxBetv11 MONEY,  
 @MaxPerMatchv11 MONEY,  
  
 @MinBetv99 MONEY,  
 @MaxBetv99 MONEY,  
 @MaxPerMatchv99 MONEY,  
   
 --Mix Parlay Mixed Sports  
 @MinBetv99MP MONEY,  
 @MaxBetv99MP MONEY,  
 @MaxPerMatchv99MP MONEY,  
   
 @UpdateMinMaxBet BIT = 1,   
 @UpdateMinMaxBetv2 BIT = 1,   
 @UpdateMinMaxBetv3 BIT = 1,   
 @UpdateMinMaxBetv5 BIT = 1,   
 @UpdateMinMaxBetv8 BIT = 1,   
 @UpdateMinMaxBetv10 BIT = 1,  
 @UpdateMinMaxBetv11 BIT = 1,  
 @UpdateMinMaxBetv99 BIT = 1,  
 @UpdateMinMaxBetv99MP BIT = 1,  
 
 @ErrCode varchar(300) = '' OUTPUT,  
 @ErrMsg nvarchar(4000) = '' OUTPUT  
as  
/*  
Created: 20101216@Henry
Task : Update member  
DB: DBTXN/bodb02  
Original: Acc_CustomerUpdMember_All  
  
Revisions:  
    - 20110520@Henry: remove @UpdateMultiple
    - 20130123@Daniel: Change link server alias & failover writelog to DBTXN

Param's Explanation:  
• @ErrCode:  
    = 0: Update successfully.  
    > 0: Specific Error.  
    
• @ErrMsg: Error description.  
*/  
  
SET NOCOUNT ON  
---------------------------  
-- ***Check Downline Belonging***  
declare @status int, @ErrCode_Cur int, @ErrMsg_Cur nvarchar(4000)  
Select @ErrCode_Cur = 0, @ErrMsg_Cur = '', @ErrCode = '', @ErrMsg = ''  
  
EXEC DBLIC.bodb02.dbo.Lrf_CustomerSelCheckBelonging   
 @LicenseeID = @LicenseeID,
 @custid = @custid,   
 @status = @status OUTPUT
 if (@status = 0) return  
  
--Check disable user  
EXEC DBLIC.bodb02.dbo.Lrf_CustomerSelCheckEnable @custid = @custid, @ErrCode=@ErrCode_Cur output,@ErrMsg=@ErrMsg_Cur output  
IF @ErrCode_Cur > 0  
BEGIN  
 select @ErrCode = @ErrCode + cast(@ErrCode_cur as varchar(300)) + char(7),   
   @ErrMsg = @ErrMsg + @ErrMsg_Cur + char(7)  
 return  
END  
--end  

----------------------------------------------  
--Update MinBet, MaxBet, MaxPerMatch  
if  @UpdateMinMaxBet  = 1 or  
 @UpdateMinMaxBetv2  = 1 or  
 @UpdateMinMaxBetv3  = 1 or  
 @UpdateMinMaxBetv5  = 1 or  
 @UpdateMinMaxBetv8  = 1 or  
 @UpdateMinMaxBetv10  = 1 or  
 @UpdateMinMaxBetv11  = 1 or  
 @UpdateMinMaxBetv99  = 1 or  
 @UpdateMinMaxBetv99MP = 1
BEGIN  
 Select @ErrCode_Cur = 0, @ErrMsg_Cur = ''  
  EXEC dbo.Lrf_CustomerUpdMember_MinMaxBet   
  @custid = @custid,  
  @minbet = @minbet,  
  @maxbet = @maxbet,  
  @maxpermatch = @maxpermatch,  
  @minbetv2 = @minbetv2,  
  @maxbetv2 = @maxbetv2,  
  @maxpermatchv2 = @maxpermatchv2,  
  @minbetv3 = @minbetv3,  
  @maxbetv3 = @maxbetv3,  
  @maxpermatchv3 = @maxpermatchv3,  
  @minbetv5 = @minbetv5,  
  @maxbetv5 = @maxbetv5,  
  @maxpermatchv5 = @maxpermatchv5,  
  @minbetv8 = @minbetv8,  
  @maxbetv8 = @maxbetv8,  
  @maxpermatchv8 = @maxpermatchv8,  
  @minbetv10 = @minbetv10,  
  @maxbetv10 = @maxbetv10,  
  @maxpermatchv10 = @maxpermatchv10,  
  @minbetv11 = @minbetv11,  
  @maxbetv11 = @maxbetv11,  
  @maxpermatchv11 = @maxpermatchv11,  
  @minbetv99 = @minbetv99,  
  @maxbetv99 = @maxbetv99,  
  @maxpermatchv99 = @maxpermatchv99,  
  @minbetv99MP = @minbetv99MP,  
  @maxbetv99MP = @maxbetv99MP,  
  @maxpermatchv99MP = @maxpermatchv99MP,   
  @UpdateMinMaxBet = @UpdateMinMaxBet,  
  @UpdateMinMaxBetv2 = @UpdateMinMaxBetv2,  
  @UpdateMinMaxBetv3 = @UpdateMinMaxBetv3,  
  @UpdateMinMaxBetv5 = @UpdateMinMaxBetv5,  
  @UpdateMinMaxBetv8 = @UpdateMinMaxBetv8,  
  @UpdateMinMaxBetv10 = @UpdateMinMaxBetv10,  
  @UpdateMinMaxBetv11 = @UpdateMinMaxBetv11,  
  @UpdateMinMaxBetv99 = @UpdateMinMaxBetv99,  
  @UpdateMinMaxBetv99MP = @UpdateMinMaxBetv99MP,  
  @UserID = @UserID,  
  @Language = @Language,  
  @IP = @IP,  
  @ErrCode = @ErrCode_Cur OUTPUT,  
  @ErrMsg = @ErrMsg_Cur OUTPUT  
 IF @ErrCode_Cur > 0  
 BEGIN  
  select @ErrCode = @ErrCode + cast(@ErrCode_cur as varchar(300)) + char(7),   
    @ErrMsg = @ErrMsg + @ErrMsg_Cur + char(7)  
  return  
 END  
 ELSE  
 BEGIN  
	Select @ErrCode = 0, @ErrMsg=''
 END  
END
GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerUpdMember_All] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerUpdMember_All] TO [vnteam] AS [dbo]