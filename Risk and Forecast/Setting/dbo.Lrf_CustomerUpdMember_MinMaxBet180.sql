ALTER PROCEDURE dbo.Lrf_CustomerUpdMember_MinMaxBet180
	@custid INT,
	@minbet MONEY,
	@maxbet MONEY,
	@maxpermatch MONEY,
	@UserID INT = 0,	
	@Language VARCHAR(2) = 'E',
	@IP VARCHAR(40)='',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg nvarchar(4000) = '' OUTPUT
AS
/*
Created: 20121003@Dom.Cao
Task : Edit bet settings of super
DB: DBTRANS.bodb02


Revisions:
	
Param's Explanation:

*/
SET NOCOUNT ON

DECLARE @startRun DATETIME,
		@endRun DATETIME,
		@duration INT,
		@minbet_old MONEY,
		@maxbet_old MONEY,
		@maxpermatch_old MONEY

SET @startRun = GETDATE()


DECLARE @minminbet MONEY,
	@maxmaxbet MONEY,
	@maxmaxpermatch MONEY

DECLARE @ErrAcc VARCHAR(4000), @ErrType VARCHAR(4000),
		@UserName VARCHAR(30), @recommend INT

SELECT @UserName = username, @recommend = recommend
from customer with (NOLOCK)
WHERE roleid = 1 AND CustID = @CustID

IF (@username = NULL) RETURN

IF 
		@MinBet<0
		or @MaxBet < 0
		or @MaxPerMatch <0		
	BEGIN
		SELECT @ErrCode = 2
		SELECT @ErrMsg = 	CASE @Language 
							WHEN 'E' THEN 'Wrong Min bet/ Max bet/ Max per match.'
							WHEN 'CS' THEN N'最低投注/最高投注/单场最高投注不正确.'
							WHEN 'CT' THEN N'最低投注/最高投注/單場最高投注不正確.'
							WHEN 'TH' THEN N'การกำหนดจำนวนเงินสำหรับการวางเดิมพันต่ำสุด/ สูงสุด/สูงสดต่อรายการไม่ถูกต้อง.'
							WHEN 'J' THEN N'Wrong Min bet/ Max bet/ Max per match.'
							WHEN 'KO' THEN N'잘못된 최소 배팅/최대 배팅/경기당 최대.'
							ELSE N'Wrong Min bet/ Max bet/ Max per match.'
					END
		RETURN
	END

SELECT
	@MinMinBet = Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
	@MaxMaxBet = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
from 
	Dep_CustSetting3rd as cs WITH (NOLOCK)
	INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
	AND cs.bettype = 1201 AND cs.sporttype=180
WHERE ci.custid = @recommend

SELECT @MaxMaxperMatch = Min(CASE WHEN cs.maxpermatch180 = 0 THEN NULL ELSE cs.maxpermatch180 END)
from 
	custinfo as cs WITH (NOLOCK) 
	INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
WHERE ci.custid = @recommend

if (@MinBet<>0 AND  @MinBet>@MaxBet) or (@MaxBet<> 0 AND @MaxBet>@MaxPerMatch) 
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'E' THEN 'Min Bet must be less than max bet AND max bet must be less than max bet per match!!!'
							WHEN 'CS' THEN N'最低投注不能高于最高投注，最高投注不能高于单场最高投注设定!!!'
							WHEN 'CT' THEN N'最低投注不能高於最高投注,最高投注不能高於單場最高投注設定!!!'
							WHEN 'TH' THEN N'จำนวนเงินต่ำสุดที่วางเดิมพันได้ต้องน้อยกว่าจำนวนเงินสูงสุดในการวางเดิมพันและจำนวนเงินสูงสุดในการวางเดิมพันต้องน้อยกว่าจำนวนเงินสูงสุดของเงินเดิมพันต่อเกม.'
							WHEN 'J' THEN N'min bet must be less than max bet AND max bet must be less than max bet per match!!!'
							WHEN 'KO' THEN N'최소 배팅은 최대 배팅 이하이여야 하고 최대 배팅은 경기당 최대 배팅보다 작아야 합니다.'
							ELSE N'min bet must be less than max bet AND max bet must be less than max bet per match!!!'
						END						
						+ char(13) + char(10) + convert(VARCHAR(20), @MinBet) + '-' + convert(VARCHAR(20), @MaxBet) + '-' + convert(VARCHAR(20), @MaxPerMatch), @ErrCode = 108
			
		RETURN
		
	END
	
	IF (@MinMinBet>0 AND @MinBet>0 AND @MinBet<@MinMinBet)
	BEGIN
		SELECT @ErrMsg =	'Virtual Soccer' + ': ' +
						CASE @Language 
							WHEN 'E' THEN 'The Min Bet must be equal to or greater than the value '
							WHEN 'CS' THEN N'最低投注需相等于或少于代理最低投注'
							WHEN 'CT' THEN N'最低投注需相等於或少於代理最低投注'
							WHEN 'TH' THEN N'จำนวนเงินต่ำสุดในการเล่นต้องเท่ากับหรือมากกว่าจำนวนเงินขั้นต่ำในการเล่นที่กำหนดไว้ของตัวแทน'
							WHEN 'J' THEN N'min bet must be equal to or greater than Agent min bet'
							WHEN 'KO' THEN N'최소 배팅은 에이전트의 최소 배팅 이상이여야 합니다'
							ELSE N'min bet must be equal to or greater than Agent min bet'
						END						
						+' (' + CONVERT(VARCHAR(20), @MinMinBet) + ').', @ErrCode = 109
				
		RETURN
	END
	
	IF (@MaxMaxBet>0 AND @MaxBet>0 AND @MaxBet>@MaxMaxBet)
	BEGIN
		SELECT @ErrMsg =	'Virtual Soccer' + ': '+
						CASE @Language 
							WHEN 'E' THEN 'The Max Bet must be equal to or less than the value '
							WHEN 'CS' THEN N'最高投注需相等于或少于代理最高投注'
							WHEN 'CT' THEN N'最高投注需相等於或少於代理最高投注'
							WHEN 'TH' THEN N'จำนวนการวางเดิมพันสูงสุดต้องเท่ากับ หรือ น้อยกว่าราคาเดิมพันสูงสุดของตัวแทน '
							WHEN 'J' THEN N'max bet must be equal to or less than Agent max bet'
							WHEN 'KO' THEN N'최대 배팅은 에이전트의 최대 배팅 이하이여야 합니다'
							ELSE N'max bet must be equal to or less than Agent max bet'
						END						
						+'(' + CONVERT(VARCHAR(20), @MaxMaxBet) + ').', @ErrCode = 110
				
		RETURN
	END
	
	IF (@MaxMaxPerMatch>0 AND @MaxPerMatch>0 AND @MaxPerMatch>@MaxMaxPerMatch)
	BEGIN
		SELECT @ErrMsg =	'Virtual Soccer' + ': '+
						CASE @Language 
							WHEN 'E' THEN 'The Max Per Match must be equal to or less than the value '
							WHEN 'CS' THEN N'单场最高投注需相等于或少于代理单场最高投注'
							WHEN 'CT' THEN N'單場最高投注需相等於或少於代理單場最高投注'
							WHEN 'TH' THEN N'จำนวนเงินสูงสุดในการเล่นต่อรายการต้องเท่ากับหรือน้อยกว่าจำนวนเงินสูงสุดต่อรายการที่กำหนดไว้ของตัวแทน  '
							WHEN 'J' THEN N'Max Per Match must be equal to or less than Agent Max Per Match'
							WHEN 'KO' THEN N'최대 경기는 에이전트의 최대 경기보다 작아야 합니다'
							ELSE N'Max Per Match must be equal to or less than Agent Max Per Match'
						END						
						+'(' + CONVERT(VARCHAR(20), @MaxMaxPerMatch) + ').', @ErrCode = 110
				
		RETURN
	END

SELECT @minbet_old = MinBet, @maxbet_old = MaxBet
FROM Dep_CustSetting3rd WITH(NOLOCK)
WHERE custid = @custid AND sporttype = 180 AND bettype = 1201

SELECT @maxpermatch_old = maxpermatch180 FROM custinfo WITH(NOLOCK) WHERE custid = @custid

IF @MinBet <> @minbet_old OR @MaxBet <> @maxbet_old
BEGIN
	UPDATE Dep_CustSetting3rd WITH (ROWLOCK, UPDLOCK)
	SET
		MinBet= @MinBet,
		MaxBet= @MaxBet
	WHERE custid=@custid AND sporttype = 180 AND bettype = 1201
	if (@@error <> 0)
	begin

		SELECT @ErrMsg = @UserName + ': '+
						CASE @Language 
							WHEN 'E' THEN 'Update process is unsuccessful !'
							WHEN 'CS' THEN N'更新程序不成功 !'
							WHEN 'CT' THEN N'更新程序不成功 !'
							WHEN 'TH' THEN N'ขั้นตอนหรือกระบวนการในการปรับยอดไม่เสร็จสิ้น!'
							WHEN 'J' THEN N'アップデート出来ません。'
							WHEN 'KO' THEN N'업데이트에 실패했습니다.'
							ELSE N'Update process is unsuccessful !'
						END, @ErrCode = 115
		RETURN
	END
END

IF @MaxPerMatch <> @maxpermatch_old
BEGIN
	UPDATE custInfo
	SET	maxpermatch180 = @maxpermatch
	WHERE custid = @custid
	
	IF (@@error <> 0)
	BEGIN
		SELECT @ErrMsg = @UserName + ': '+
						CASE @Language 
							WHEN 'E' THEN 'Update process is unsuccessful !'
							WHEN 'CS' THEN N'更新程序不成功 !'
							WHEN 'CT' THEN N'更新程序不成功 !'
							WHEN 'TH' THEN N'ขั้นตอนหรือกระบวนการในการปรับยอดไม่เสร็จสิ้น!'
							WHEN 'J' THEN N'アップデート出来ません。'
							WHEN 'KO' THEN N'업데이트에 실패했습니다.'
							ELSE N'Update process is unsuccessful !'
						END, @ErrCode = 115
		RETURN
	END
END

DECLARE @TrackingValue VARCHAR(5000)
SELECT @TrackingValue ='<Lrf_CustomerUpdMember_MinMaxBet180 custid="'+ COALESCE(CAST(@custid as VARCHAR(50)),SPACE(1)) + '" ' +
'MinB="'+ COALESCE(CAST(@minbet as VARCHAR(50)),SPACE(1)) + '" ' +
'MaxB="'+ COALESCE(CAST(@maxbet as VARCHAR(50)),SPACE(1)) + '" ' +
'MPM="'+ COALESCE(CAST(@maxpermatch as VARCHAR(50)),SPACE(1)) + '" ' +
'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
'Language="'+ COALESCE(CAST(@Language as VARCHAR(2)),SPACE(1)) + '" ' +
'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(5000)),SPACE(1)) + '" />'

DECLARE @TrackingValue2 VARCHAR(5000)
SELECT @TrackingValue2 ='<Lrf_CustomerUpdMember_MinMaxBet180 custid="'+ COALESCE(CAST(@custid as VARCHAR(50)),SPACE(1)) + '" ' +
'MinB="'+ COALESCE(CAST(@minbet_old as VARCHAR(50)),SPACE(1)) + '" ' +
'MaxB="'+ COALESCE(CAST(@maxbet_old as VARCHAR(50)),SPACE(1)) + '" ' +
'MPM="'+ COALESCE(CAST(@maxpermatch_old as VARCHAR(50)),SPACE(1)) + '" ' +
'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
'Language="'+ COALESCE(CAST(@Language as VARCHAR(2)),SPACE(1)) + '" ' +
'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(5000)),SPACE(1)) + '" />'

SET @endRun = GETDATE()
SET @duration  = datediff (millisecond,@startRun,@endRun)

EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
	@UserID = @UserID,
	@CustID = @CustID,
	@ActionID = 2014,
	@TrackingValue = @TrackingValue,
	@TrackingValue2 = @TrackingValue2,
	@duration = @duration

---------------------------------------------------------


GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerUpdMember_MinMaxBet180] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerUpdMember_MinMaxBet180] TO [vnteam]

