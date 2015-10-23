ALTER PROCEDURE [dbo].[Lrf_CustomerUpdMember_MinMaxBet161]
	@custid INT,-- MemberID
	@minbetv161 MONEY,  
	@maxbetv161 MONEY,  
	@maxpermatchv161 MONEY,   
	@MaxPerBallv161 MONEY = 0,   
	@UserID INT = 0,	
	@Language VARCHAR(2) = 'E',
	@IP VARCHAR(40)='',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg nvarchar(4000) = '' OUTPUT
as

/*
Created: 20110519@Henry
Task : UPDATE member's minbet, maxbet, max per match for Number Game
DB: DBTRANS.bodb02

Revisions:
	- 20110613@Henry: Logging Enhancement
	- 20120326@Dom: Change CustSetting3rd to Dep_CustSetting3rd
	- 20151023@Victor: Support New Simplified Chinese
Param's Explanation:
• @ErrCode:
    = 0: Transaction recorded successfully.
    > 0: Specific Error.
  
• @ErrMsg: Error description.
*/

SET NOCOUNT ON

DECLARE @startRun DATETIME,
		@endRun DATETIME,
		@duration INT,
		@old_minbetv161 MONEY,
		@old_maxbetv161 MONEY,
		@old_maxpermatchv161 MONEY,
		@old_maxperballv161 MONEY

SET @startRun = GETDATE()

DECLARE @MinMinBetv161 MONEY, @MaxMaxBetv161 MONEY, @MaxMaxPerMatchv161 MONEY,  
 @MaxMaxPerBallv161 MONEY  
	
DECLARE @ErrAcc VARCHAR(4000), @ErrType VARCHAR(4000),
		@UserName VARCHAR(30), @recommend INT
		
SELECT @UserName = username, @recommend = recommend
FROM customer WITH (NOLOCK)
WHERE roleid = 1 AND CustID = @CustID

IF (@username = NULL) RETURN

---------------------------------------------------------------
IF 
		@MinBetv161 <0
		or @MaxBetv161 <0
		or @MaxPerMatchv161 <0		
	BEGIN
		SELECT @ErrCode = 3
		SELECT @ErrMsg = 	CASE @Language 
							WHEN 'en-us' THEN 'Wrong Min bet/ Max bet/ Max per match (for Number Game).'
							WHEN 'zh-cn' THEN N'最低投注/最高投注/单场最高投注不正确(供数字游戏).'
							WHEN 'zh-tw' THEN N'最低投注/最高投注/單場最高投注不正確(供數字游戲).'
							WHEN 'zh-Hans' THEN N'最低投注/最高投注/单场最高投注不正确(供数字游戏).'
							WHEN 'TH' THEN N'การกำหนดจำนวนเงินสำหรับการวางเดิมพันต่ำสุด/ สูงสุด/สูงสดต่อรายการไม่ถูกต้อง (สำหรับเกมหมายเลข).'
							WHEN 'Ja' THEN N'Wrong Min bet/ Max bet/ Max per match (for Number Game).'
							WHEN 'KO' THEN N'잘못된 최소 배팅/최대 배팅/경기당 최대 (for Number Game).'
							ELSE N'Wrong Min bet/ Max bet/ Max per match (for Number Game).'
					END
		RETURN
	END
	
	IF @MaxPerBallv161 < 0
	BEGIN		
		SELECT @ErrCode = 3
		SELECT @ErrMsg = 	CASE @Language 
					WHEN 'en-us' THEN 'Wrong Max Per Ball (Number Game).'
					WHEN 'zh-cn' THEN N'单粒球最高投注设置错误.'
					WHEN 'zh-tw' THEN N'單粒球最高投注設置錯誤.'
					WHEN 'zh-Hans' THEN N'单粒球最高投注设置错误.'
					WHEN 'TH' THEN N'ค่าการเดิมพันสูงสุดต่อบอลผิดพลาด .'
					WHEN 'Ja' THEN N'Wrong Max Per Ball (Number Game).'
					WHEN 'KO' THEN N'Wrong Max Per Ball (Number Game).'
					ELSE N'Wrong Max Per Ball (Number Game).'
			END
		RETURN		
	END
---------------------------------------------------------------

SELECT   
 @MinMinBetv161 = Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END),   
 @MaxMaxBetv161 = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)  
FROM   
 Dep_CustSetting3rd as cs WITH (NOLOCK)  
 INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)  
 AND cs.bettype = 81 AND cs.sporttype=161  
WHERE ci.custid = @recommend  

SELECT 
	@MaxMaxPerMatchv161 = Min(CASE WHEN cs.MaxPerMatch161 = 0 THEN NULL ELSE cs.MaxPerMatch161 END),  
	@MaxMaxPerBallv161 = Min(CASE WHEN cs.MaxPerBall161 = 0 THEN NULL ELSE cs.MaxPerBall161 END)  
FROM   
 custinfo as cs WITH (NOLOCK)   
 INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)  
WHERE ci.custid = @recommend  



IF (@MinBetv161 <> 0 AND @MaxBetv161 <> 0 AND @MinBetv161>@MaxBetv161) or (@MaxBetv161<> 0 AND @MaxPerMatchv161 <> 0 AND @MaxBetv161>@MaxPerMatchv161)  
 BEGIN  
  SELECT @ErrMsg = @UserName + ': '+  
      CASE @Language   
       WHEN 'en-us' THEN 'min bet must be less than max bet AND max bet must be less than max bet per match (for Number Game)'  
       WHEN 'zh-cn' THEN N'最低投注不能高于最高投注，最高投注不能高于单场最高投注设定(供数字游戏)'  
       WHEN 'zh-tw' THEN N'最低投注不能高於最高投注,最高投注不能高於單場最高投注設定(供數字游戲)'  
	   WHEN 'zh-Hans' THEN N'最低投注不能高于最高投注，最高投注不能高于单场最高投注设定(供数字游戏)'  
       WHEN 'TH' THEN N'จำนวนเงินต่ำสุดที่วางเดิมพันได้ต้องน้อยกว่าจำนวนเงินสูงสุดในการวางเดิมพันและจำนวนเงินสูงสุดในการวางเดิมพันต้องน้อยกว่าจำนวนเงินสูงสุดของเงินเดิมพันต่อเกม (สำหรับเกมหมายเลข)'  
       WHEN 'Ja' THEN N'min bet must be less than max bet AND max bet must be less than max bet per match (for Number Game)'  
       WHEN 'KO' THEN N'최소 배팅은 최대 배팅 이하이여야 하고 최대 배팅은 경기당 최대 배팅보다 작아야 합니다 (for Number Game)'  
       ELSE N'min bet must be less than max bet AND max bet must be less than max bet per match (for Number Game)'  
      END        
      , @ErrCode = 111  
      
  RETURN  
 END  
   
 IF (@MinMinBetv161>0 AND @MinBetv161>0 AND @MinBetv161<@MinMinBetv161)  
 BEGIN  
  SELECT @ErrMsg = @UserName + ': '+  
      CASE @Language   
       WHEN 'en-us' THEN 'min bet must be equal to or greater than Agent min bet (for Number Game)'  
       WHEN 'zh-cn' THEN N'最低投注需相等于或少于代理最低投注(供数字游戏)'  
       WHEN 'zh-tw' THEN N'最低投注需相等於或少於代理最低投注(供數字游戲)'  
	   WHEN 'zh-Hans' THEN N'最低投注需相等于或少于代理最低投注(供数字游戏)'  
       WHEN 'TH' THEN N'จำนวนเงินต่ำสุดในการเล่นต้องเท่ากับหรือมากกว่าจำนวนเงินขั้นต่ำในการเล่นที่กำหนดไว้ของตัวแทน (สำหรับเกมหมายเลข)'  
       WHEN 'Ja' THEN N'min bet must be equal to or greater than Agent min bet (for Number Game)'  
       WHEN 'KO' THEN N'최소 배팅은 에이전트의 최소 배팅 이상이여야 합니다 (for Number Game)'  
       ELSE N'min bet must be equal to or greater than Agent min bet (for Number Game)'  
      END        
     , @ErrCode = 112  
      
  RETURN  
 END   
 IF (@MaxMaxBetv161>0 AND @MaxBetv161>0 AND @MaxBetv161>@MaxMaxBetv161)  
 BEGIN  
  SELECT @ErrMsg = @UserName + ': '+  
      CASE @Language   
       WHEN 'en-us' THEN 'max bet must be equal to or less than Agent max bet (for Number Game)'  
       WHEN 'zh-cn' THEN N'最高投注需相等于或少于代理最高投注(供数字游戏)'  
       WHEN 'zh-tw' THEN N'最高投注需相等於或少於代理最高投注(供數字游戲)'  
	   WHEN 'zh-Hans' THEN N'最高投注需相等于或少于代理最高投注(供数字游戏)'  
       WHEN 'TH' THEN N'จำนวนการวางเดิมพันสูงสุดต้องเท่ากับ หรือ น้อยกว่าราคาเดิมพันสูงสุดของตัวแทน (สำหรับเกมหมายเลข)'  
       WHEN 'Ja' THEN N'max bet must be equal to or less than Agent max bet (for Number Game)'  
       WHEN 'KO' THEN N'최대 배팅은 에이전트의 최대 배팅 이하이여야 합니다 (for Number Game)'  
       ELSE N'max bet must be equal to or less than Agent max bet (for Number Game)'  
      END        
      , @ErrCode = 113  
      
  RETURN  
 END  
   
 IF (@MaxMaxPerMatchv161>0 AND @MaxPerMatchv161>0 AND @MaxPerMatchv161>@MaxMaxPerMatchv161)  
 BEGIN  
  SELECT @ErrMsg = @UserName + ': '+  
      CASE @Language   
       WHEN 'en-us' THEN 'Max Per Match must be equal to or less than Agent Max Per Match (for Number Game)'  
       WHEN 'zh-cn' THEN N'单场最高投注需相等于或少于代理单场最高投注(供数字游戏)'  
       WHEN 'zh-tw' THEN N'單場最高投注需相等於或少於代理單場最高投注(供數字游戲)'  
	   WHEN 'zh-Hans' THEN N'单场最高投注需相等于或少于代理单场最高投注(供数字游戏)'  
       WHEN 'TH' THEN N'จำนวนเงินสูงสุดในการเล่นต่อรายการต้องเท่ากับหรือน้อยกว่าจำนวนเงินสูงสุดต่อรายการที่กำหนดไว้ของตัวแทน (สำหรับเกมหมายเลข) '  
       WHEN 'Ja' THEN N'Max Per Match must be equal to or less than Agent Max Per Match (for Number Game)'  
       WHEN 'KO' THEN N'최대 경기는 에이전트의 최대 경기보다 작아야 합니다 (for Number Game)'  
       ELSE N'Max Per Match must be equal to or less than Agent Max Per Match (for Number Game)'  
      END        
      , @ErrCode = 113  
      
  RETURN  
 END  
  
 IF @MaxPerBallv161 > @MaxMaxPerBallv161 AND @MaxMaxPerBallv161 > 0  
 BEGIN  
  SELECT @ErrMsg = @UserName + ': ' +  
   CASE @Language   
    WHEN 'en-us' THEN 'Sorry, Max Per Ball must be less than or equal to Agent Max Per Ball (Number Game).'  
    WHEN 'zh-cn' THEN N'单粒球最高投注必須等於或低於代理单粒球最高的投注.'  
    WHEN 'zh-tw' THEN N'單粒球最高投注必須等於或低於代理單粒球最高的投注.'  
	WHEN 'zh-Hans' THEN N'单粒球最高投注必須等於或低於代理单粒球最高的投注.'  
    WHEN 'TH' THEN N'ขออภัย, ค่าสูงสุดต่อบอลต้องเท่ากับหรือน้อยกว่าการตั้งค่าสูงสุดต่อบอลของเอเย่น .'  
    WHEN 'Ja' THEN N'Sorry, Max Per Ball must be less than or equal to Agent Max Per Ball (Number Game).'  
    WHEN 'KO' THEN N'Sorry, Max Per Ball must be less than or equal to Agent Max Per Ball (Number Game).'  
    ELSE N'Sorry, Max Per Ball must be less than or equal to Agent Max Per Ball (Number Game).'  
   END  
  , @ErrCode = 201      
  RETURN  
 END  

SELECT @old_minbetv161 = MinBet, @old_maxbetv161 = MaxBet
FROM Dep_CustSetting3rd WITH(NOLOCK)
WHERE custid = @custid AND sporttype = 161 AND bettype = 81

SELECT 
	@old_maxpermatchv161 = MaxPerMatch161, 
	@old_maxperballv161 = MaxPerBall161
FROM custinfo WITH (NOLOCK)
WHERE custid = @custid



UPDATE Dep_CustSetting3rd WITH (ROWLOCK, UPDLOCK)  
 SET  
  MinBet = @MinBetv161,  
  MaxBet = @MaxBetv161  
  
 WHERE custid = @custid AND sporttype = 161  

UPDATE custinfo WITH (ROWLOCK, UPDLOCK)
	SET 	
		MaxPerMatch161= @maxpermatchv161,
		MaxPerBall161 = @maxperballv161
WHERE custid = @custid

IF (@@error <>0)
BEGIN  
   
 SELECT @ErrMsg = @UserName + ': '+  
     CASE @Language   
      WHEN 'en-us' THEN 'UPDATE process is unsuccessful !'  
      WHEN 'zh-cn' THEN N'更新程序不成功 !'  
      WHEN 'zh-tw' THEN N'更新程序不成功 !'  
	  WHEN 'zh-Hans' THEN N'更新程序不成功 !'  
      WHEN 'TH' THEN N'ขั้นตอนหรือกระบวนการในการปรับยอดไม่เสร็จสิ้น!'  
      WHEN 'Ja' THEN N'アップデート出来ません。'  
      WHEN 'KO' THEN N'업데이트에 실패했습니다.'  
      ELSE N'UPDATE process is unsuccessful !'  
     END, @ErrCode = 115  
 RETURN  
END  

DECLARE @TrackingValue VARCHAR(5000)
SELECT @TrackingValue ='<Lrf_CustomerUpdMember_MinMaxBet161 custid="'+ COALESCE(CAST(@custid as VARCHAR(50)),SPACE(1)) + '" ' +
'MinBv161="'+ COALESCE(CAST(@minbetv161 as VARCHAR(50)),SPACE(1)) + '" ' +  
'MaxBv161="'+ COALESCE(CAST(@maxbetv161 as VARCHAR(50)),SPACE(1)) + '" ' +  
'MPMv161="'+ COALESCE(CAST(@maxpermatchv161 as VARCHAR(50)),SPACE(1)) + '" ' +  
'MPBv161 ="' + COALESCE(CAST(@MaxPerBallv161 as VARCHAR(50)),SPACE(1)) + '" ' +  
'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
'Language="'+ COALESCE(CAST(@Language as VARCHAR(2)),SPACE(1)) + '" ' +
'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(5000)),SPACE(1)) + '" />'

DECLARE @TrackingValue2 VARCHAR(5000)
SELECT @TrackingValue2 ='<Lrf_CustomerUpdMember_MinMaxBet161 custid="'+ COALESCE(CAST(@custid as VARCHAR(50)),SPACE(1)) + '" ' +
'MinBv161="'+ COALESCE(CAST(@old_minbetv161 as VARCHAR(50)),SPACE(1)) + '" ' +  
'MaxBv161="'+ COALESCE(CAST(@old_maxbetv161 as VARCHAR(50)),SPACE(1)) + '" ' +  
'MPMv161="'+ COALESCE(CAST(@old_maxpermatchv161 as VARCHAR(50)),SPACE(1)) + '" ' +  
'MPBv161 ="' + COALESCE(CAST(@old_maxperballv161 as VARCHAR(50)),SPACE(1)) + '" ' +  
'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
'Language="'+ COALESCE(CAST(@Language as VARCHAR(2)),SPACE(1)) + '" ' +
'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(5000)),SPACE(1)) + '" />'



SET @endRun = GETDATE()
SET @duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)

EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
	@UserID = @UserID,
	@CustID = @CustID,
	@ActionID = 2007,
	@TrackingValue = @TrackingValue,
	@TrackingValue2 = @TrackingValue2,
	@duration = @duration

---------------------------------------------------------


GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerUpdMember_MinMaxBet161] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerUpdMember_MinMaxBet161] TO [vnteam] 