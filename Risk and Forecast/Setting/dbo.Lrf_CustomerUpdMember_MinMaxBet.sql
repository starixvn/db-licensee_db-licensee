USE [CustDB]
GO
 
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
ALTER PROCEDURE [dbo].[Lrf_CustomerUpdMember_MinMaxBet]
	@custid INT,-- MemberID
	
	@minbet MONEY,
	@maxbet MONEY,
	@maxpermatch MONEY,
	
	@minbetv2 MONEY,
	@maxbetv2 MONEY,
	@maxpermatchv2 MONEY,
	
	@minbetv3 MONEY,
	@maxbetv3 MONEY,
	@maxpermatchv3 MONEY,
	
	@minbetv5 MONEY,
	@maxbetv5 MONEY,
	@maxpermatchv5 MONEY,
	
	@minbetv8 MONEY,
	@maxbetv8 MONEY,
	@maxpermatchv8 MONEY,
	
	@minbetv10 MONEY,
	@maxbetv10 MONEY,
	@maxpermatchv10 MONEY,
	
	@minbetv11 MONEY,
	@maxbetv11 MONEY,
	@maxpermatchv11 MONEY,
	
	@minbetv44 MONEY,
	@maxbetv44 MONEY,
	@maxpermatchv44 MONEY,
	
	@minbetv154 MONEY,
	@maxbetv154 MONEY,
	@maxpermatchv154 MONEY,
	
	@minbetv99 MONEY,
	@maxbetv99 MONEY,
	@maxpermatchv99 MONEY,	
	
	@minbetv99MP MONEY,
	@maxbetv99MP MONEY,
	@maxpermatchv99MP MONEY,	
		
	
	@UpdateMinMaxBet BIT = 1,
	@UpdateMinMaxBetv2 BIT = 1,
	@UpdateMinMaxBetv3 BIT = 1,
	@UpdateMinMaxBetv5 BIT = 1,
	@UpdateMinMaxBetv8 BIT = 1,
	@UpdateMinMaxBetv10 BIT = 1,
	@UpdateMinMaxBetv11 BIT = 1,
	@UpdateMinMaxBetv44 BIT = 1,
	@UpdateMinMaxBetv154 BIT = 1,
	
	@UpdateMinMaxBetv99 BIT = 1,
	@UpdateMinMaxBetv99MP BIT = 1,
	
	@UserID INT = 0,	
	@Language VARCHAR(10) = 'en-us',
	@IP VARCHAR(40)='',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg nvarchar(4000) = '' OUTPUT
as
--@Source Control
/*
Created: 20101216@Henry
Task : Update Member MinBet, MaxBet, MaxPerMatch
DB: DBCUST/CustDB
Original: [Acc_CustomerUpdMember_MinMaxBet]
Revisions:
   - 20110505@Henry: change the ActionID
   - 20110520@Henry: remove @UpdateMultiple
   - 20110613@Henry: Logging Enhancement
   - 20120326@Dom: Change CustSetting to Dep_CustSetting, CustSetting3rd to Dep_CustSetting3rd
   - 20140207@Jim: support to offer HorseRacingFixedOdds
   - 20151015@Jim: Integrate Sportbook2 (Feature #44759)
   - 20151023@Victor: Support New Simplified Chinese
   - 20160329@Jim: correct setting for MuayThai (RedmineID #55036)
Param's Explanation:
• @ErrCode:
    = 0: Update successfully.
    > 0: Specific Error.
  
• @ErrMsg: Error description.
*/
SET NOCOUNT ON

DECLARE @startRun DATETIME
DECLARE @endRun DATETIME
DECLARE @duration INT
SET @startRun = GETDATE()

DECLARE 
	@MinMinBet MONEY, @MaxMaxBet MONEY,	@MaxMaxPerMatch MONEY,
	@MinMinBetv2 MONEY, @MaxMaxBetv2 MONEY, @MaxMaxPerMatchv2 MONEY,
	@MinMinBetv3 MONEY, @MaxMaxBetv3 MONEY, @MaxMaxPerMatchv3 MONEY,
	@MinMinBetv5 MONEY, @MaxMaxBetv5 MONEY, @MaxMaxPerMatchv5 MONEY,
	@MinMinBetv8 MONEY, @MaxMaxBetv8 MONEY, @MaxMaxPerMatchv8 MONEY,
	@MinMinBetv10 MONEY, @MaxMaxBetv10 MONEY, @MaxMaxPerMatchv10 MONEY,
	@MinMinBetv11 MONEY, @MaxMaxBetv11 MONEY, @MaxMaxPerMatchv11 MONEY,
	@MinMinBetv44 MONEY, @MaxMaxBetv44 MONEY, @MaxMaxPerMatchv44 MONEY,
	@MinMinBetv154 MONEY, @MaxMaxBetv154 MONEY, @MaxMaxPerMatchv154 MONEY,
	@MinMinBetv99 MONEY, @MaxMaxBetv99 MONEY, @MaxMaxPerMatchv99 MONEY,
	@MinMinBetv99MP MONEY, @MaxMaxBetv99MP MONEY, @MaxMaxPerMatchv99MP MONEY
	
DECLARE 
	@Old_MinBet MONEY, @Old_MaxBet MONEY,	@Old_MaxPerMatch MONEY,
	@Old_MinBetv2 MONEY, @Old_MaxBetv2 MONEY, @Old_MaxPerMatchv2 MONEY,
	@Old_MinBetv3 MONEY, @Old_MaxBetv3 MONEY, @Old_MaxPerMatchv3 MONEY,
	@Old_MinBetv5 MONEY, @Old_MaxBetv5 MONEY, @Old_MaxPerMatchv5 MONEY,
	@Old_MinBetv8 MONEY, @Old_MaxBetv8 MONEY, @Old_MaxPerMatchv8 MONEY,
	@Old_MinBetv10 MONEY, @Old_MaxBetv10 MONEY, @Old_MaxPerMatchv10 MONEY,
	@Old_MinBetv11 MONEY, @Old_MaxBetv11 MONEY, @Old_MaxPerMatchv11 MONEY,
	@Old_MinBetv44 MONEY, @Old_MaxBetv44 MONEY, @Old_MaxPerMatchv44 MONEY,
	@Old_MinBetv154 MONEY, @Old_MaxBetv154 MONEY, @Old_MaxPerMatchv154 MONEY,
	@Old_MinBetv99 MONEY, @Old_MaxBetv99 MONEY, @Old_MaxPerMatchv99 MONEY,
	@Old_MinBetv99MP MONEY, @Old_MaxBetv99MP MONEY, @Old_MaxPerMatchv99MP MONEY
	
	
DECLARE @ErrAcc VARCHAR(4000), @ErrType VARCHAR(4000),
		@UserName VARCHAR(30), @recommend INT

		
SELECT @UserName = username, @recommend = recommend
from customer with (NOLOCK)
WHERE CustID = @CustID

SELECT 
	
	@MaxMaxperMatch = Min(CASE WHEN cs.MaxPerMatch = 0 THEN NULL ELSE cs.MaxPerMatch END), 
	
	@MaxMaxPerMatchv2 = Min(CASE WHEN cs.MaxPerMatch2 = 0 THEN NULL ELSE cs.MaxPerMatch2 END), 
	
	@MaxMaxPerMatchv3 = Min(CASE WHEN cs.MaxPerMatch3 = 0 THEN NULL ELSE cs.MaxPerMatch3 END), 
	
	@MaxMaxPerMatchv5 = Min(CASE WHEN cs.MaxPerMatch5 = 0 THEN NULL ELSE cs.MaxPerMatch5 END), 
	
	@MaxMaxPerMatchv8 = Min(CASE WHEN cs.MaxPerMatch8 = 0 THEN NULL ELSE cs.MaxPerMatch8 END), 
	
	@MaxMaxPerMatchv10 = Min(CASE WHEN cs.MaxPerMatch10 = 0 THEN NULL ELSE cs.MaxPerMatch10 END), 
	
	@MaxMaxPerMatchv11 = Min(CASE WHEN cs.MaxPerMatch11 = 0 THEN NULL ELSE cs.MaxPerMatch11 END), 
	
	@MaxMaxPerMatchv44 = Min(CASE WHEN cs.MaxPerMatch44 = 0 THEN NULL ELSE cs.MaxPerMatch44 END), 
	
	@MaxMaxPerMatchv154 = Min(CASE WHEN cs.MaxPerMatch154 = 0 THEN NULL ELSE cs.MaxPerMatch154 END), 
	
	@MaxMaxPerMatchv99 = Min(CASE WHEN cs.MaxPerMatch99 = 0 THEN NULL ELSE cs.MaxPerMatch99 END),
	@MaxMaxPerMatchv99MP = Min(CASE WHEN cs.MaxPerMatch99MP = 0 THEN NULL ELSE cs.MaxPerMatch99MP END)
	
from 
	custinfo as cs WITH (NOLOCK) 
	INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
WHERE ci.custid = @recommend

---------------------------------------------------------------
--Check Param
if @UpdateMinMaxBet = 1 
BEGIN
	if 
		@MinBet<0
		or @MaxBet < 0
		or @MaxPerMatch <0		
	BEGIN
		SELECT @ErrCode = 2
		SELECT @ErrMsg = 	CASE @Language 
							WHEN 'en-us' THEN 'Wrong Min bet/ Max bet/ Max per match (for Soccer).'
							WHEN 'zh-cn' THEN N'最低投注/最高投注/单场最高投注不正确(于足球).'
							WHEN 'zh-tw' THEN N'最低投注/最高投注/單場最高投注不正確(於足球).'
							WHEN 'zh-Hans' THEN N'最低投注/最高投注/单场最高投注不正确(于足球).'
							WHEN 'TH' THEN N'การกำหนดจำนวนเงินสำหรับการวางเดิมพันต่ำสุด/ สูงสุด/สูงสดต่อรายการไม่ถูกต้อง (สำหรับกีฬาเทนนิส).'
							WHEN 'Ja' THEN N'Wrong Min bet/ Max bet/ Max per match (for Soccer).'
							WHEN 'KO' THEN N'잘못된 최소 배팅/최대 배팅/경기당 최대 (축구).'
							ELSE N'Wrong Min bet/ Max bet/ Max per match (for Soccer).'
					END
		RETURN
	END
	
	
	SELECT
		@MinMinBet = Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
		@MaxMaxBet = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
	from 
		Dep_CustSetting as cs WITH (NOLOCK)
		INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
		AND cs.bettype = 1 AND cs.sporttype=1
	WHERE ci.custid = @recommend
	
	if (@MinBet<>0 AND @MaxBet <> 0 AND  @MinBet>@MaxBet) or (@MaxBet<> 0 AND @MaxPerMatch <> 0 AND @MaxBet>@MaxPerMatch) 
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'min bet must be less than max bet AND max bet must be less than max bet per match'
							WHEN 'zh-cn' THEN N'最低投注不能高于最高投注，最高投注不能高于单场最高投注设定'
							WHEN 'zh-tw' THEN N'最低投注不能高於最高投注,最高投注不能高於單場最高投注設定'
							WHEN 'zh-Hans' THEN N'最低投注不能高于最高投注，最高投注不能高于单场最高投注设定'
							WHEN 'TH' THEN N'จำนวนเงินต่ำสุดที่วางเดิมพันได้ต้องน้อยกว่าจำนวนเงินสูงสุดในการวางเดิมพันและจำนวนเงินสูงสุดในการวางเดิมพันต้องน้อยกว่าจำนวนเงินสูงสุดของเงินเดิมพันต่อเกม.'
							WHEN 'Ja' THEN N'min bet must be less than max bet AND max bet must be less than max bet per match'
							WHEN 'KO' THEN N'최소 배팅은 최대 배팅 이하이여야 하고 최대 배팅은 경기당 최대 배팅보다 작아야 합니다.'
							ELSE N'min bet must be less than max bet AND max bet must be less than max bet per match'
						END						
						+ char(13) + char(10) + convert(VARCHAR(20), @MinBet) + '-' + convert(VARCHAR(20), @MaxBet) + '-' + convert(VARCHAR(20), @MaxPerMatch), @ErrCode = 108
			
		RETURN
		
	END
	
	IF (@MinMinBet>0 AND @MinBet>0 AND @MinBet<@MinMinBet)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': ' +
						CASE @Language 
							WHEN 'en-us' THEN 'min bet must be equal to or greater than Agent min bet'
							WHEN 'zh-cn' THEN N'最低投注需相等于或少于代理最低投注'
							WHEN 'zh-tw' THEN N'最低投注需相等於或少於代理最低投注'
							WHEN 'zh-Hans' THEN N'最低投注需相等于或少于代理最低投注'
							WHEN 'TH' THEN N'จำนวนเงินต่ำสุดในการเล่นต้องเท่ากับหรือมากกว่าจำนวนเงินขั้นต่ำในการเล่นที่กำหนดไว้ของตัวแทน'
							WHEN 'Ja' THEN N'min bet must be equal to or greater than Agent min bet'
							WHEN 'KO' THEN N'최소 배팅은 에이전트의 최소 배팅 이상이여야 합니다.'
							ELSE N'min bet must be equal to or greater than Agent min bet'
						END						
						+' (' + CONVERT(VARCHAR(20), @MinMinBet) + ').', @ErrCode = 109
				
		RETURN
	END
	
	IF (@MaxMaxBet>0 AND @MaxBet>0 AND @MaxBet>@MaxMaxBet)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'max bet must be equal to or less than Agent max bet'
							WHEN 'zh-cn' THEN N'最高投注需相等于或少于代理最高投注'
							WHEN 'zh-tw' THEN N'最高投注需相等於或少於代理最高投注'
							WHEN 'zh-Hans' THEN N'最高投注需相等于或少于代理最高投注'
							WHEN 'TH' THEN N'จำนวนการวางเดิมพันสูงสุดต้องเท่ากับ หรือ น้อยกว่าราคาเดิมพันสูงสุดของตัวแทน '
							WHEN 'Ja' THEN N'max bet must be equal to or less than Agent max bet'
							WHEN 'KO' THEN N'최대 배팅은 에이전트의 최대 배팅 이하이여야 합니다.'
							ELSE N'max bet must be equal to or less than Agent max bet'
						END						
						+'(' + CONVERT(VARCHAR(20), @MaxMaxBet) + ').', @ErrCode = 110
				
		RETURN
	END
	
	IF (@MaxMaxPerMatch>0 AND @MaxPerMatch>0 AND @MaxPerMatch>@MaxMaxPerMatch)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'Max Per Match must be equal to or less than Agent Max Per Match'
							WHEN 'zh-cn' THEN N'单场最高投注需相等于或少于代理单场最高投注'
							WHEN 'zh-tw' THEN N'單場最高投注需相等於或少於代理單場最高投注'
							WHEN 'zh-Hans' THEN N'单场最高投注需相等于或少于代理单场最高投注'
							WHEN 'TH' THEN N'จำนวนเงินสูงสุดในการเล่นต่อรายการต้องเท่ากับหรือน้อยกว่าจำนวนเงินสูงสุดต่อรายการที่กำหนดไว้ของตัวแทน  '
							WHEN 'Ja' THEN N'Max Per Match must be equal to or less than Agent Max Per Match'
							WHEN 'KO' THEN N'최대 경기는 에이전트의 최대 경기보다 작아야 합니다.'
							ELSE N'Max Per Match must be equal to or less than Agent Max Per Match'
						END						
						+'(' + CONVERT(VARCHAR(20), @MaxMaxPerMatch) + ').', @ErrCode = 110
				
		RETURN
	END
	
	
	
	
END

if @UpdateMinMaxBetv2 = 1 
BEGIN
	if 
		@MinBetv2 <0
		or @MaxBetv2 <0
		or @MaxPerMatchv2 <0		
	BEGIN
		SELECT @ErrCode = 3
		SELECT @ErrMsg = 	CASE @Language 
							WHEN 'en-us' THEN 'Wrong Min bet/ Max bet/ Max per match (for Basketball).'
							WHEN 'zh-cn' THEN N'最低投注/最高投注/单场最高投注不正确(于篮球).'
							WHEN 'zh-tw' THEN N'最低投注/最高投注/單場最高投注不正確(於籃球).'
							WHEN 'zh-Hans' THEN N'最低投注/最高投注/单场最高投注不正确(于篮球).'
							WHEN 'TH' THEN N'การกำหนดจำนวนเงินสำหรับการวางเดิมพันต่ำสุด/ สูงสุด/สูงสดต่อรายการไม่ถูกต้อง (สำหรับกีฬาบาสเก็ตบอล).'
							WHEN 'Ja' THEN N'Wrong Min bet/ Max bet/ Max per match (for Basketball).'
							WHEN 'KO' THEN N'잘못된 최소 배팅/최대 배팅/경기당 최대 (농구).'
							ELSE N'Wrong Min bet/ Max bet/ Max per match (for Basketball).'
					END
		RETURN
	END
	
	SELECT 
		@MinMinBetv2 = Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
		@MaxMaxBetv2 = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
	from 
		Dep_CustSetting as cs WITH (NOLOCK)
		INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
		AND cs.bettype = 1 AND cs.sporttype=2
	WHERE ci.custid = @recommend
	
	if (@MinBetv2 <> 0 AND @MaxBetv2 <> 0 AND @MinBetv2>@MaxBetv2) or (@MaxBetv2 <> 0 AND @MaxPerMatchv2 <> 0 AND @MaxBetv2>@MaxPerMatchv2)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'min bet must be less than max bet AND max bet must be less than max bet per match (for Basketball)'
							WHEN 'zh-cn' THEN N'最低投注不能高于最高投注，最高投注不能高于单场最高投注设定(于篮球)'
							WHEN 'zh-tw' THEN N'最低投注不能高於最高投注,最高投注不能高於單場最高投注設定(於籃球)'
							WHEN 'zh-Hans' THEN N'最低投注不能高于最高投注，最高投注不能高于单场最高投注设定(于篮球)'
							WHEN 'TH' THEN N'จำนวนเงินต่ำสุดที่วางเดิมพันได้ต้องน้อยกว่าจำนวนเงินสูงสุดในการวางเดิมพันและจำนวนเงินสูงสุดในการวางเดิมพันต้องน้อยกว่าจำนวนเงินสูงสุดของเงินเดิมพันต่อเกม (สำหรับกีฬาบาสเก็ตบอล)'
							WHEN 'Ja' THEN N'min bet must be less than max bet AND max bet must be less than max bet per match (for Basketball)'
							WHEN 'KO' THEN N'최소 배팅은 최대 배팅 이하이여야 하고 최대 배팅은 경기당 최대 배팅보다 작아야 합니다 (농구)'
							ELSE N'min bet must be less than max bet AND max bet must be less than max bet per match (for Basketball)'
						END						
						+ char(13) + char(10) + convert(VARCHAR(20), @MinBetv2) + '-' + convert(VARCHAR(20), @MaxBetv2) + '-' + convert(VARCHAR(20), @MaxPerMatchv2), @ErrCode = 111
				
		RETURN
	END
	
	IF (@MinMinBetv2>0 AND @MinBetv2>0 AND @MinBetv2<@MinMinBetv2)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'min bet must be equal to or greater than Agent min bet (for Basketball)'
							WHEN 'zh-cn' THEN N'最低投注需相等于或少于代理最低投注(于篮球)'
							WHEN 'zh-tw' THEN N'最低投注需相等於或少於代理最低投注(於籃球)'
							WHEN 'zh-Hans' THEN N'最低投注需相等于或少于代理最低投注(于篮球)'
							WHEN 'TH' THEN N'จำนวนเงินต่ำสุดในการเล่นต้องเท่ากับหรือมากกว่าจำนวนเงินขั้นต่ำในการเล่นที่กำหนดไว้ของตัวแทน (สำหรับกีฬาบาสเก็ตบอล)'
							WHEN 'Ja' THEN N'min bet must be equal to or greater than Agent min bet (for Basketball)'
							WHEN 'KO' THEN N'최소 배팅은 에이전트의 최소 배팅 이상이여야 합니다 (농구)'
							ELSE N'min bet must be equal to or greater than Agent min bet (for Basketball)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MinMinBetv2) + ').', @ErrCode = 112
				
		RETURN
	END	
	IF (@MaxMaxBetv2>0 AND @MaxBetv2>0 AND @MaxBetv2>@MaxMaxBetv2)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'max bet must be equal to or less than Agent max bet (for Basketball)'
							WHEN 'zh-cn' THEN N'最高投注需相等于或少于代理最高投注(于篮球)'
							WHEN 'zh-tw' THEN N'最高投注需相等於或少於代理最高投注(於籃球)'
							WHEN 'zh-Hans' THEN N'最高投注需相等于或少于代理最高投注(于篮球)'
							WHEN 'TH' THEN N'จำนวนการวางเดิมพันสูงสุดต้องเท่ากับ หรือ น้อยกว่าราคาเดิมพันสูงสุดของตัวแทน (สำหรับกีฬาบาสเก็ตบอล)'
							WHEN 'Ja' THEN N'max bet must be equal to or less than Agent max bet (for Basketball)'
							WHEN 'KO' THEN N'최대 배팅은 에이전트의 최대 배팅 이하이여야 합니다 (농구)'
							ELSE N'max bet must be equal to or less than Agent max bet (for Basketball)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MaxMaxBetv2) + ').', @ErrCode = 113
				
		RETURN
	END
	
	IF (@MaxMaxPerMatchv2>0 AND @MaxPerMatchv2>0 AND @MaxPerMatchv2>@MaxMaxPerMatchv2)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'Max Per Match must be equal to or less than Agent Max Per Match (for Basketball)'
							WHEN 'zh-cn' THEN N'单场最高投注需相等于或少于代理单场最高投注(于篮球)'
							WHEN 'zh-tw' THEN N'單場最高投注需相等於或少於代理單場最高投注(於籃球)'
							WHEN 'zh-Hans' THEN N'单场最高投注需相等于或少于代理单场最高投注(于篮球)'
							WHEN 'TH' THEN N'จำนวนเงินสูงสุดในการเล่นต่อรายการต้องเท่ากับหรือน้อยกว่าจำนวนเงินสูงสุดต่อรายการที่กำหนดไว้ของตัวแทน (สำหรับกีฬาบาสเก็ตบอล)  '
							WHEN 'Ja' THEN N'Max Per Match must be equal to or less than Agent Max Per Match (for Basketball)'
							WHEN 'KO' THEN N'최대 경기는 에이전트의 최대 경기보다 작아야 합니다 (농구)'
							ELSE N'Max Per Match must be equal to or less than Agent Max Per Match (for Basketball)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MaxMaxPerMatchv2) + ').', @ErrCode = 113
				
		RETURN
	END
END

if @UpdateMinMaxBetv3 = 1 
BEGIN
	if 
		@MinBetv3 <0
		or @MaxBetv3 <0
		or @MaxPerMatchv3 <0		
	BEGIN
		SELECT @ErrCode = 3
		SELECT @ErrMsg = 	CASE @Language 
							WHEN 'en-us' THEN 'Wrong Min bet/ Max bet/ Max per match (for Football).'
							WHEN 'zh-cn' THEN N'最低投注/最高投注/单场最高投注不正确(于美式足球).'
							WHEN 'zh-tw' THEN N'最低投注/最高投注/單場最高投注不正確(於美式足球).'
							WHEN 'zh-Hans' THEN N'最低投注/最高投注/单场最高投注不正确(于美式足球).'
							WHEN 'TH' THEN N'การกำหนดจำนวนเงินสำหรับการวางเดิมพันต่ำสุด/ สูงสุด/สูงสดต่อรายการไม่ถูกต้อง (สำหรับกีฬาอเมริกันฟุตบอล).'
							WHEN 'Ja' THEN N'Wrong Min bet/ Max bet/ Max per match (for Football).'

							WHEN 'KO' THEN N'잘못된 최소 배팅/최대 배팅/경기당 최대 (풋볼).'
							ELSE N'Wrong Min bet/ Max bet/ Max per match (for Football).'
					END
		RETURN
	END
	
	SELECT 
		@MinMinBetv3 = Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
		@MaxMaxBetv3 = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
	from 
		Dep_CustSetting as cs WITH (NOLOCK)
		INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
		AND cs.bettype = 1 AND cs.sporttype=3
	WHERE ci.custid = @recommend
	
	if (@MinBetv3 <> 0 AND @MaxBetv3 <> 0 AND @MinBetv3>@MaxBetv3) or (@MaxBetv3 <> 0 AND @MaxPerMatchv3 <> 0 AND @MaxBetv3>@MaxPerMatchv3)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'min bet must be less than max bet AND max bet must be less than max bet per match (for Football)'
							WHEN 'zh-cn' THEN N'最低投注不能高于最高投注，最高投注不能高于单场最高投注设定(于美式足球)'
							WHEN 'zh-tw' THEN N'最低投注不能高於最高投注,最高投注不能高於單場最高投注設定(於美式足球)'
							WHEN 'zh-Hans' THEN N'最低投注不能高于最高投注，最高投注不能高于单场最高投注设定(于美式足球)'
							WHEN 'TH' THEN N'จำนวนเงินต่ำสุดที่วางเดิมพันได้ต้องน้อยกว่าจำนวนเงินสูงสุดในการวางเดิมพันและจำนวนเงินสูงสุดในการวางเดิมพันต้องน้อยกว่าจำนวนเงินสูงสุดของเงินเดิมพันต่อเกม (สำหรับกีฬาอเมริกันฟุตบอล)'
							WHEN 'Ja' THEN N'min bet must be less than max bet AND max bet must be less than max bet per match (for Football)'
							WHEN 'KO' THEN N'최소 배팅은 최대 배팅 이하이여야 하고 최대 배팅은 경기당 최대 배팅보다 작아야 합니다 (풋볼)'
							ELSE N'min bet must be less than max bet AND max bet must be less than max bet per match (for Football)'
						END						
						+ char(13) + char(10) + convert(VARCHAR(20), @MinBetv3) + '-' + convert(VARCHAR(20), @MaxBetv3) + '-' + convert(VARCHAR(20), @MaxPerMatchv3), @ErrCode = 111
				
		RETURN
	END
	
	IF (@MinMinBetv3>0 AND @MinBetv3>0 AND @MinBetv3<@MinMinBetv3)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'min bet must be equal to or greater than Agent min bet (for Football)'
							WHEN 'zh-cn' THEN N'最低投注需相等于或少于代理最低投注(于美式足球)'
							WHEN 'zh-tw' THEN N'最低投注需相等於或少於代理最低投注(於美式足球)'
							WHEN 'zh-Hans' THEN N'最低投注需相等于或少于代理最低投注(于美式足球)'
							WHEN 'TH' THEN N'จำนวนเงินต่ำสุดในการเล่นต้องเท่ากับหรือมากกว่าจำนวนเงินขั้นต่ำในการเล่นที่กำหนดไว้ของตัวแทน (สำหรับกีฬาอเมริกันฟุตบอล)'
							WHEN 'Ja' THEN N'min bet must be equal to or greater than Agent min bet (for Football)'
							WHEN 'KO' THEN N'최소 배팅은 에이전트의 최소 배팅 이상이여야 합니다 (풋볼)'
							ELSE N'min bet must be equal to or greater than Agent min bet (for Football)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MinMinBetv3) + ').', @ErrCode = 112
				
		RETURN
	END	
	IF (@MaxMaxBetv3>0 AND @MaxBetv3>0 AND @MaxBetv3>@MaxMaxBetv3)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'max bet must be equal to or less than Agent max bet (for Football)'
							WHEN 'zh-cn' THEN N'最高投注需相等于或少于代理最高投注(于美式足球)'
							WHEN 'zh-tw' THEN N'最高投注需相等於或少於代理最高投注(於美式足球)'
							WHEN 'zh-Hans' THEN N'最高投注需相等于或少于代理最高投注(于美式足球)'
							WHEN 'TH' THEN N'จำนวนการวางเดิมพันสูงสุดต้องเท่ากับ หรือ น้อยกว่าราคาเดิมพันสูงสุดของตัวแทน (สำหรับกีฬาอเมริกันฟุตบอล)'
							WHEN 'Ja' THEN N'max bet must be equal to or less than Agent max bet (for Football)'
							WHEN 'KO' THEN N'최대 배팅은 에이전트의 최대 배팅 이하이여야 합니다 (풋볼)'
							ELSE N'max bet must be equal to or less than Agent max bet (for Football)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MaxMaxBetv3) + ').', @ErrCode = 113
				
		RETURN
	END
	
	IF (@MaxMaxPerMatchv3>0 AND @MaxPerMatchv3>0 AND @MaxPerMatchv3>@MaxMaxPerMatchv3)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'Max Per Match must be equal to or less than Agent Max Per Match (for Football)'
							WHEN 'zh-cn' THEN N'单场最高投注需相等于或少于代理单场最高投注(于美式足球)'
							WHEN 'zh-tw' THEN N'單場最高投注需相等於或少於代理單場最高投注(於美式足球)'
							WHEN 'zh-Hans' THEN N'单场最高投注需相等于或少于代理单场最高投注(于美式足球)'
							WHEN 'TH' THEN N'จำนวนเงินสูงสุดในการเล่นต่อรายการต้องเท่ากับหรือน้อยกว่าจำนวนเงินสูงสุดต่อรายการที่กำหนดไว้ของตัวแทน (สำหรับกีฬาอเมริกันฟุตบอล) '
							WHEN 'Ja' THEN N'Max Per Match must be equal to or less than Agent Max Per Match (for Football)'
							WHEN 'KO' THEN N'최대 경기는 에이전트의 최대 경기보다 작아야 합니다 (풋볼)'
							ELSE N'Max Per Match must be equal to or less than Agent Max Per Match (for Football)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MaxMaxPerMatchv3) + ').', @ErrCode = 113
				
		RETURN
	END
END

if @UpdateMinMaxBetv5 = 1 
BEGIN
	if 
		@MinBetv5 <0
		or @MaxBetv5 <0
		or @MaxPerMatchv5 <0		
	BEGIN
		SELECT @ErrCode = 3
		SELECT @ErrMsg = 	CASE @Language 
							WHEN 'en-us' THEN 'Wrong Min bet/ Max bet/ Max per match (for Tennis).'
							WHEN 'zh-cn' THEN N'最低投注/最高投注/单场最高投注不正确(于网球).'
							WHEN 'zh-tw' THEN N'最低投注/最高投注/單場最高投注不正確(於網球).'
							WHEN 'zh-Hans' THEN N'最低投注/最高投注/单场最高投注不正确(于网球).'
							WHEN 'TH' THEN N'การกำหนดจำนวนเงินสำหรับการวางเดิมพันต่ำสุด/ สูงสุด/สูงสดต่อรายการไม่ถูกต้อง (สำหรับกีฬาเทนนิส).'
							WHEN 'Ja' THEN N'Wrong Min bet/ Max bet/ Max per match (for Tennis).'
							WHEN 'KO' THEN N'잘못된 최소 배팅/최대 배팅/경기당 최대 (테니스).'
							ELSE N'Wrong Min bet/ Max bet/ Max per match (for Tennis).'
					END
		RETURN
	END
	
	SELECT 
		@MinMinBetv5 = Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
		@MaxMaxBetv5 = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
	from 
		Dep_CustSetting as cs WITH (NOLOCK)
		INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
		AND cs.bettype = 1 AND cs.sporttype=5
	WHERE ci.custid = @recommend
	
	if (@MinBetv5 <> 0 AND @MaxBetv5 <> 0 AND @MinBetv5>@MaxBetv5) or (@MaxBetv5 <> 0 AND @MaxPerMatchv5 <> 0 AND @MaxBetv5>@MaxPerMatchv5)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'min bet must be less than max bet AND max bet must be less than max bet per match (for Tennis)'
							WHEN 'zh-cn' THEN N'最低投注不能高于最高投注，最高投注不能高于单场最高投注设定(于网球)'
							WHEN 'zh-tw' THEN N'最低投注不能高於最高投注,最高投注不能高於單場最高投注設定(於網球)'
							WHEN 'zh-Hans' THEN N'最低投注不能高于最高投注，最高投注不能高于单场最高投注设定(于网球)'
							WHEN 'TH' THEN N'จำนวนเงินต่ำสุดที่วางเดิมพันได้ต้องน้อยกว่าจำนวนเงินสูงสุดในการวางเดิมพันและจำนวนเงินสูงสุดในการวางเดิมพันต้องน้อยกว่าจำนวนเงินสูงสุดของเงินเดิมพันต่อเกม (สำหรับกีฬาเทนนิส)'
							WHEN 'Ja' THEN N'min bet must be less than max bet AND max bet must be less than max bet per match (for Tennis)'
							WHEN 'KO' THEN N'최소 배팅은 최대 배팅 이하이여야 하고 최대 배팅은 경기당 최대 배팅보다 작아야 합니다 (테니스)'
							ELSE N'min bet must be less than max bet AND max bet must be less than max bet per match (for Tennis)'
						END						
						+ char(13) + char(10) + convert(VARCHAR(20), @MinBetv5) + '-' + convert(VARCHAR(20), @MaxBetv5) + '-' + convert(VARCHAR(20), @MaxPerMatchv5), @ErrCode = 111
				
		RETURN
	END
	
	IF (@MinMinBetv5>0 AND @MinBetv5>0 AND @MinBetv5<@MinMinBetv5)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'min bet must be equal to or greater than Agent min bet (for Tennis)'
							WHEN 'zh-cn' THEN N'最低投注需相等于或少于代理最低投注(于网球)'
							WHEN 'zh-tw' THEN N'最低投注需相等於或少於代理最低投注(於網球)'
							WHEN 'zh-Hans' THEN N'最低投注需相等于或少于代理最低投注(于网球)'
							WHEN 'TH' THEN N'จำนวนเงินต่ำสุดในการเล่นต้องเท่ากับหรือมากกว่าจำนวนเงินขั้นต่ำในการเล่นที่กำหนดไว้ของตัวแทน (สำหรับกีฬาเทนนิส)'
							WHEN 'Ja' THEN N'min bet must be equal to or greater than Agent min bet (for Tennis)'
							WHEN 'KO' THEN N'최소 배팅은 에이전트의 최소 배팅 이상이여야 합니다 (테니스)'
							ELSE N'min bet must be equal to or greater than Agent min bet (for Tennis)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MinMinBetv5) + ').', @ErrCode = 112
				
		RETURN
	END	
	IF (@MaxMaxBetv5>0 AND @MaxBetv5>0 AND @MaxBetv5>@MaxMaxBetv5)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'max bet must be equal to or less than Agent max bet (for Tennis)'
							WHEN 'zh-cn' THEN N'最高投注需相等于或少于代理最高投注(于网球)'
							WHEN 'zh-tw' THEN N'最高投注需相等於或少於代理最高投注(於網球)'
							WHEN 'zh-Hans' THEN N'最高投注需相等于或少于代理最高投注(于网球)'
							WHEN 'TH' THEN N'จำนวนการวางเดิมพันสูงสุดต้องเท่ากับ หรือ น้อยกว่าราคาเดิมพันสูงสุดของตัวแทน (สำหรับกีฬาเทนนิส)'
							WHEN 'Ja' THEN N'max bet must be equal to or less than Agent max bet (for Tennis)'
							WHEN 'KO' THEN N'최대 배팅은 에이전트의 최대 배팅 이하이여야 합니다 (테니스)'
							ELSE N'max bet must be equal to or less than Agent max bet (for Tennis)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MaxMaxBetv5) + ').', @ErrCode = 113
				
		RETURN
	END
	
	IF (@MaxMaxPerMatchv5>0 AND @MaxPerMatchv5>0 AND @MaxPerMatchv5>@MaxMaxPerMatchv5)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'Max Per Match must be equal to or less than Agent Max Per Match  (for Tennis)'
							WHEN 'zh-cn' THEN N'单场最高投注需相等于或少于代理单场最高投注(于网球)'
							WHEN 'zh-tw' THEN N'單場最高投注需相等於或少於代理單場最高投注(於網球)'
							WHEN 'zh-Hans' THEN N'单场最高投注需相等于或少于代理单场最高投注(于网球)'
							WHEN 'TH' THEN N'จำนวนเงินสูงสุดในการเล่นต่อรายการต้องเท่ากับหรือน้อยกว่าจำนวนเงินสูงสุดต่อรายการที่กำหนดไว้ของตัวแทน (สำหรับกีฬาเทนนิส)  '
							WHEN 'Ja' THEN N'Max Per Match must be equal to or less than Agent Max Per Match  (for Tennis)'
							WHEN 'KO' THEN N'최대 경기는 에이전트의 최대 경기보다 작아야 합니다 (테니스)'
							ELSE N'Max Per Match must be equal to or less than Agent Max Per Match  (for Tennis)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MaxMaxPerMatchv5) + ').', @ErrCode = 113
				
		RETURN
	END
END

if @UpdateMinMaxBetv8 = 1 
BEGIN
	if 
		@MinBetv8 <0
		or @MaxBetv8 <0
		or @MaxPerMatchv8 <0		
	BEGIN
		SELECT @ErrCode = 3
		SELECT @ErrMsg = 	CASE @Language 
							WHEN 'en-us' THEN 'Wrong Min bet/ Max bet/ Max per match (for Baseball).'
							WHEN 'zh-cn' THEN N'最低投注/最高投注/单场最高投注不正确(于棒球).'
							WHEN 'zh-tw' THEN N'最低投注/最高投注/單場最高投注不正確(於棒球).'
							WHEN 'zh-Hans' THEN N'最低投注/最高投注/单场最高投注不正确(于棒球).'
							WHEN 'TH' THEN N'การกำหนดจำนวนเงินสำหรับการวางเดิมพันต่ำสุด/ สูงสุด/สูงสดต่อรายการไม่ถูกต้อง (สำหรับกีฬาเบสบอล).'
							WHEN 'Ja' THEN N'Wrong Min bet/ Max bet/ Max per match (for Baseball).'
							WHEN 'KO' THEN N'잘못된 최소 배팅/최대 배팅/경기당 최대 (야구).'
							ELSE N'Wrong Min bet/ Max bet/ Max per match (for Baseball).'
					END
		RETURN
	END
	
	SELECT 
		@MinMinBetv8 = Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
		@MaxMaxBetv8 = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
	from 
		Dep_CustSetting as cs WITH (NOLOCK)
		INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
		AND cs.bettype = 1 AND cs.sporttype=8
	WHERE ci.custid = @recommend
	
	if (@MinBetv8 <> 0 AND @MaxBetv8 <> 0 AND @MinBetv8>@MaxBetv8) or (@MaxBetv8 <> 0 AND @MaxPerMatchv8 <> 0 AND @MaxBetv8>@MaxPerMatchv8)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'min bet must be less than max bet AND max bet must be less than max bet per match (for Baseball)'
							WHEN 'zh-cn' THEN N'最低投注不能高于最高投注，最高投注不能高于单场最高投注设定(于棒球)'
							WHEN 'zh-tw' THEN N'最低投注不能高於最高投注,最高投注不能高於單場最高投注設定(於棒球)'
							WHEN 'zh-Hans' THEN N'最低投注不能高于最高投注，最高投注不能高于单场最高投注设定(于棒球)'
							WHEN 'TH' THEN N'จำนวนเงินต่ำสุดที่วางเดิมพันได้ต้องน้อยกว่าจำนวนเงินสูงสุดในการวางเดิมพันและจำนวนเงินสูงสุดในการวางเดิมพันต้องน้อยกว่าจำนวนเงินสูงสุดของเงินเดิมพันต่อเกม (สำหรับกีฬาเบสบอล)'
							WHEN 'Ja' THEN N'min bet must be less than max bet AND max bet must be less than max bet per match (for Baseball)'
							WHEN 'KO' THEN N'최소 배팅은 최대 배팅 이하이여야 하고 최대 배팅은 경기당 최대 배팅보다 작아야 합니다 (야구)'
							ELSE N'min bet must be less than max bet AND max bet must be less than max bet per match (for Baseball)'
						END						
						+ char(13) + char(10) + convert(VARCHAR(20), @MinBetv8) + '-' + convert(VARCHAR(20), @MaxBetv8) + '-' + convert(VARCHAR(20), @MaxPerMatchv8), @ErrCode = 111
				
		RETURN
	END
	
	IF (@MinMinBetv8>0 AND @MinBetv8>0 AND @MinBetv8<@MinMinBetv8)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'min bet must be equal to or greater than Agent min bet (for Baseball)'
							WHEN 'zh-cn' THEN N'最低投注需相等于或少于代理最低投注(于棒球)'
							WHEN 'zh-tw' THEN N'最低投注需相等於或少於代理最低投注(於棒球)'
							WHEN 'zh-Hans' THEN N'最低投注需相等于或少于代理最低投注(于棒球)'
							WHEN 'TH' THEN N'จำนวนเงินต่ำสุดในการเล่นต้องเท่ากับหรือมากกว่าจำนวนเงินขั้นต่ำในการเล่นที่กำหนดไว้ของตัวแทน (สำหรับกีฬาเบสบอล)'
							WHEN 'Ja' THEN N'min bet must be equal to or greater than Agent min bet (for Baseball)'
							WHEN 'KO' THEN N'최소 배팅은 에이전트의 최소 배팅 이상이여야 합니다 (야구)'
							ELSE N'min bet must be equal to or greater than Agent min bet (for Baseball)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MinMinBetv8) + ').', @ErrCode = 112
				
		RETURN
	END	
	IF (@MaxMaxBetv8>0 AND @MaxBetv8>0 AND @MaxBetv8>@MaxMaxBetv8)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'max bet must be equal to or less than Agent max bet (for Baseball)'
							WHEN 'zh-cn' THEN N'最高投注需相等于或少于代理最高投注(于棒球)'
							WHEN 'zh-tw' THEN N'最高投注需相等於或少於代理最高投注(於棒球)'
							WHEN 'zh-Hans' THEN N'最高投注需相等于或少于代理最高投注(于棒球)'
							WHEN 'TH' THEN N'จำนวนการวางเดิมพันสูงสุดต้องเท่ากับ หรือ น้อยกว่าราคาเดิมพันสูงสุดของตัวแทน (สำหรับกีฬาเบสบอล)'
							WHEN 'Ja' THEN N'max bet must be equal to or less than Agent max bet (for Baseball)'
							WHEN 'KO' THEN N'최대 배팅은 에이전트의 최대 배팅 이하이여야 합니다 (야구)'
							ELSE N'max bet must be equal to or less than Agent max bet (for Baseball)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MaxMaxBetv8) + ').', @ErrCode = 113
				
		RETURN
	END
	
	IF (@MaxMaxPerMatchv8>0 AND @MaxPerMatchv8>0 AND @MaxPerMatchv8>@MaxMaxPerMatchv8)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'Max Per Match must be equal to or less than Agent Max Per Match (for Baseball)'
							WHEN 'zh-cn' THEN N'单场最高投注需相等于或少于代理单场最高投注(于棒球)'
							WHEN 'zh-tw' THEN N'單場最高投注需相等於或少於代理單場最高投注(於棒球)'
							WHEN 'zh-Hans' THEN N'单场最高投注需相等于或少于代理单场最高投注(于棒球)'
							WHEN 'TH' THEN N'จำนวนเงินสูงสุดในการเล่นต่อรายการต้องเท่ากับหรือน้อยกว่าจำนวนเงินสูงสุดต่อรายการที่กำหนดไว้ของตัวแทน (สำหรับกีฬาเบสบอล)  '
							WHEN 'Ja' THEN N'Max Per Match must be equal to or less than Agent Max Per Match (for Baseball)'
							WHEN 'KO' THEN N'최대 경기는 에이전트의 최대 경기보다 작아야 합니다 (야구)'
							ELSE N'Max Per Match must be equal to or less than Agent Max Per Match (for Baseball)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MaxMaxPerMatchv8) + ').', @ErrCode = 113
				
		RETURN
	END
END

if @UpdateMinMaxBetv10 = 1 
BEGIN
	if 
		@MinBetv10 <0
		or @MaxBetv10 <0
		or @MaxPerMatchv10 <0		
	BEGIN
		SELECT @ErrCode = 3
		SELECT @ErrMsg = 	CASE @Language 
							WHEN 'en-us' THEN 'Wrong Min bet/ Max bet/ Max per match (for Golf).'
							WHEN 'zh-cn' THEN N'最低投注/最高投注/单场最高投注不正确(于高尔夫球).'
							WHEN 'zh-tw' THEN N'最低投注/最高投注/單場最高投注不正確(於高爾夫球).'
							WHEN 'zh-Hans' THEN N'最低投注/最高投注/单场最高投注不正确(于高尔夫球).'
							WHEN 'TH' THEN N'การกำหนดจำนวนเงินสำหรับการวางเดิมพันต่ำสุด/ สูงสุด/สูงสดต่อรายการไม่ถูกต้อง (สำหรับกีฬากอฟล์).'
							WHEN 'Ja' THEN N'Wrong Min bet/ Max bet/ Max per match (for Golf).'
							WHEN 'KO' THEN N'잘못된 최소 배팅/최대 배팅/경기당 최대 (골프).'
							ELSE N'Wrong Min bet/ Max bet/ Max per match (for Golf).'
					END
		RETURN
	END
	
	SELECT 
		@MinMinBetv10 = Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
		@MaxMaxBetv10 = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
	from 
		Dep_CustSetting as cs WITH (NOLOCK)
		INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
		AND cs.bettype = 1 AND cs.sporttype=10
	WHERE ci.custid = @recommend
	
	if (@MinBetv10 <> 0 AND @MaxBetv10 <> 0 AND @MinBetv10>@MaxBetv10) or (@MaxBetv10 <> 0 AND @MaxPerMatchv10 <> 0 AND @MaxBetv10>@MaxPerMatchv10)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'min bet must be less than max bet AND max bet must be less than max bet per match (for Golf)'
							WHEN 'zh-cn' THEN N'最低投注不能高于最高投注，最高投注不能高于单场最高投注设定(于高尔夫球)'
							WHEN 'zh-tw' THEN N'最低投注不能高於最高投注,最高投注不能高於單場最高投注設定(於高爾夫球)'
							WHEN 'zh-Hans' THEN N'最低投注不能高于最高投注，最高投注不能高于单场最高投注设定(于高尔夫球)'
							WHEN 'TH' THEN N'จำนวนเงินต่ำสุดที่วางเดิมพันได้ต้องน้อยกว่าจำนวนเงินสูงสุดในการวางเดิมพันและจำนวนเงินสูงสุดในการวางเดิมพันต้องน้อยกว่าจำนวนเงินสูงสุดของเงินเดิมพันต่อเกม (สำหรับกีฬากอฟล์)'
							WHEN 'Ja' THEN N'min bet must be less than max bet AND max bet must be less than max bet per match (for Golf)'
							WHEN 'KO' THEN N'최소 배팅은 최대 배팅 이하이여야 하고 최대 배팅은 경기당 최대 배팅보다 작아야 합니다 (골프)'
							ELSE N'min bet must be less than max bet AND max bet must be less than max bet per match (for Golf)'
						END						
						+ char(13) + char(10) + convert(VARCHAR(20), @MinBetv10) + '-' + convert(VARCHAR(20), @MaxBetv10) + '-' + convert(VARCHAR(20), @MaxPerMatchv10), @ErrCode = 111
				
		RETURN
	END
	
	IF (@MinMinBetv10>0 AND @MinBetv10>0 AND @MinBetv10<@MinMinBetv10)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'min bet must be equal to or greater than Agent min bet (for Golf)'
							WHEN 'zh-cn' THEN N'最低投注需相等于或少于代理最低投注(于高尔夫球)'
							WHEN 'zh-tw' THEN N'最低投注需相等於或少於代理最低投注(於高爾夫球)'
							WHEN 'zh-Hans' THEN N'最低投注需相等于或少于代理最低投注(于高尔夫球)'
							WHEN 'TH' THEN N'จำนวนเงินต่ำสุดในการเล่นต้องเท่ากับหรือมากกว่าจำนวนเงินขั้นต่ำในการเล่นที่กำหนดไว้ของตัวแทน (สำหรับกีฬากอฟล์)'
							WHEN 'Ja' THEN N'min bet must be equal to or greater than Agent min bet (for Golf)'
							WHEN 'KO' THEN N'최소 배팅은 에이전트의 최소 배팅 이상이여야 합니다 (골프)'
							ELSE N'min bet must be equal to or greater than Agent min bet (for Golf)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MinMinBetv10) + ').', @ErrCode = 112
				
		RETURN
	END	
	IF (@MaxMaxBetv10>0 AND @MaxBetv10>0 AND @MaxBetv10>@MaxMaxBetv10)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'max bet must be equal to or less than Agent max bet (for Golf)'
							WHEN 'zh-cn' THEN N'最高投注需相等于或少于代理最高投注(于高尔夫球)'
							WHEN 'zh-tw' THEN N'最高投注需相等於或少於代理最高投注(於高爾夫球)'
							WHEN 'zh-Hans' THEN N'最高投注需相等于或少于代理最高投注(于高尔夫球)'
							WHEN 'TH' THEN N'จำนวนการวางเดิมพันสูงสุดต้องเท่ากับ หรือ น้อยกว่าราคาเดิมพันสูงสุดของตัวแทน (สำหรับกีฬากอฟล์)'
							WHEN 'Ja' THEN N'max bet must be equal to or less than Agent max bet (for Golf)'
							WHEN 'KO' THEN N'최대 배팅은 에이전트의 최대 배팅 이하이여야 합니다 (골프)'
							ELSE N'max bet must be equal to or less than Agent max bet (for Golf)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MaxMaxBetv10) + ').', @ErrCode = 113
				
		RETURN
	END
	
	IF (@MaxMaxPerMatchv10>0 AND @MaxPerMatchv10>0 AND @MaxPerMatchv10>@MaxMaxPerMatchv10)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'Max Per Match must be equal to or less than Agent Max Per Match (for Golf)'
							WHEN 'zh-cn' THEN N'单场最高投注需相等于或少于代理单场最高投注(于高尔夫球)'
							WHEN 'zh-tw' THEN N'單場最高投注需相等於或少於代理單場最高投注(於高爾夫球)'
							WHEN 'zh-Hans' THEN N'单场最高投注需相等于或少于代理单场最高投注(于高尔夫球)'
							WHEN 'TH' THEN N'จำนวนเงินสูงสุดในการเล่นต่อรายการต้องเท่ากับหรือน้อยกว่าจำนวนเงินสูงสุดต่อรายการที่กำหนดไว้ของตัวแทน (สำหรับกีฬากอฟล์) '
							WHEN 'Ja' THEN N'Max Per Match must be equal to or less than Agent Max Per Match (for Golf)'
							WHEN 'KO' THEN N'최대 경기는 에이전트의 최대 경기보다 작아야 합니다 (골프)'
							ELSE N'Max Per Match must be equal to or less than Agent Max Per Match (for Golf)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MaxMaxPerMatchv10) + ').', @ErrCode = 113
				
		RETURN
	END
END
---
if @UpdateMinMaxBetv11 = 1
BEGIN
	if 
		@MinBetv11 <0
		or @MaxBetv11 <0
		or @MaxPerMatchv11 <0		
	BEGIN
		SELECT @ErrCode = 3
		SELECT @ErrMsg = 	CASE @Language 
							WHEN 'en-us' THEN 'Wrong Min bet/ Max bet/ Max per match (for Motorsports).'
							WHEN 'zh-cn' THEN N'最低投注/最高投注/单场最高投注不正确(于赛车).'
							WHEN 'zh-tw' THEN N'最低投注/最高投注/單場最高投注不正確(於賽車).'
							WHEN 'zh-Hans' THEN N'最低投注/最高投注/单场最高投注不正确(于赛车).'
							WHEN 'TH' THEN N'การกำหนดจำนวนเงินสำหรับการวางเดิมพันต่ำสุด/ สูงสุด/สูงสดต่อรายการไม่ถูกต้อง (สำหรับกีฬารถแข่ง).'
							WHEN 'Ja' THEN N'Wrong Min bet/ Max bet/ Max per match (for Motorsports).'
							WHEN 'KO' THEN N'잘못된 최소 배팅/최대 배팅/경기당 최대 (모토스포츠).'
							ELSE N'Wrong Min bet/ Max bet/ Max per match (for Motorsports).'
					END
		RETURN
	END
	
	SELECT 
		@MinMinBetv11 = Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
		@MaxMaxBetv11 = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
	from 
		Dep_CustSetting as cs WITH (NOLOCK)
		INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
		AND cs.bettype = 1 AND cs.sporttype=11
	WHERE ci.custid = @recommend
	
	if (@MinBetv11 <> 0 AND @MaxBetv11 <> 0 AND @MinBetv11>@MaxBetv11) or (@MaxBetv11 <> 0 AND @MaxPerMatchv11 <> 0 AND @MaxBetv11>@MaxPerMatchv11)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'min bet must be less than max bet AND max bet must be less than max bet per match (for Motorsports)'
							WHEN 'zh-cn' THEN N'最低投注不能高于最高投注，最高投注不能高于单场最高投注设定(于赛车)'
							WHEN 'zh-tw' THEN N'最低投注不能高於最高投注,最高投注不能高於單場最高投注設定(於賽車)'
							WHEN 'zh-Hans' THEN N'最低投注不能高于最高投注，最高投注不能高于单场最高投注设定(于赛车)'
							WHEN 'TH' THEN N'จำนวนเงินต่ำสุดที่วางเดิมพันได้ต้องน้อยกว่าจำนวนเงินสูงสุดในการวางเดิมพันและจำนวนเงินสูงสุดในการวางเดิมพันต้องน้อยกว่าจำนวนเงินสูงสุดของเงินเดิมพันต่อเกม (สำหรับกีฬารถแข่ง)'
							WHEN 'Ja' THEN N'min bet must be less than max bet AND max bet must be less than max bet per match (for Motorsports)'
							WHEN 'KO' THEN N'최소 배팅은 최대 배팅 이하이여야 하고 최대 배팅은 경기당 최대 배팅보다 작아야 합니다 (모토스포츠)'
							ELSE N'min bet must be less than max bet AND max bet must be less than max bet per match (for Motorsports)'
						END						
						+ char(13) + char(10) + convert(VARCHAR(20), @MinBetv11) + '-' + convert(VARCHAR(20), @MaxBetv11) + '-' + convert(VARCHAR(20), @MaxPerMatchv11), @ErrCode = 111
				
		RETURN
	END
	
	IF (@MinMinBetv11>0 AND @MinBetv11>0 AND @MinBetv11<@MinMinBetv11)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'min bet must be equal to or greater than Agent min bet (for Motorsports)'
							WHEN 'zh-cn' THEN N'最低投注需相等于或少于代理最低投注(于赛车)'
							WHEN 'zh-tw' THEN N'最低投注需相等於或少於代理最低投注(於賽車)'
							WHEN 'zh-Hans' THEN N'最低投注需相等于或少于代理最低投注(于赛车)'
							WHEN 'TH' THEN N'จำนวนเงินต่ำสุดในการเล่นต้องเท่ากับหรือมากกว่าจำนวนเงินขั้นต่ำในการเล่นที่กำหนดไว้ของตัวแทน (สำหรับกีฬารถแข่ง)'
							WHEN 'Ja' THEN N'min bet must be equal to or greater than Agent min bet (for Motorsports)'
							WHEN 'KO' THEN N'최소 배팅은 에이전트의 최소 배팅 이상이여야 합니다 (모토스포츠)'
							ELSE N'min bet must be equal to or greater than Agent min bet (for Motorsports)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MinMinBetv11) + ').', @ErrCode = 112
				
		RETURN
	END	
	IF (@MaxMaxBetv11>0 AND @MaxBetv11>0 AND @MaxBetv11>@MaxMaxBetv11)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'max bet must be equal to or less than Agent max bet (for Motorsports)'
							WHEN 'zh-cn' THEN N'最高投注需相等于或少于代理最高投注(于赛车)'
							WHEN 'zh-tw' THEN N'最高投注需相等於或少於代理最高投注(於賽車)'
							WHEN 'zh-Hans' THEN N'最高投注需相等于或少于代理最高投注(于赛车)'
							WHEN 'TH' THEN N'จำนวนการวางเดิมพันสูงสุดต้องเท่ากับ หรือ น้อยกว่าราคาเดิมพันสูงสุดของตัวแทน (สำหรับกีฬารถแข่ง)'
							WHEN 'Ja' THEN N'max bet must be equal to or less than Agent max bet (for Motorsports)'
							WHEN 'KO' THEN N'최대 배팅은 에이전트의 최대 배팅 이하이여야 합니다 (모토스포츠)'
							ELSE N'max bet must be equal to or less than Agent max bet (for Motorsports)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MaxMaxBetv11) + ').', @ErrCode = 113
				
		RETURN
	END
	
	IF (@MaxMaxPerMatchv11>0 AND @MaxPerMatchv11>0 AND @MaxPerMatchv11>@MaxMaxPerMatchv11)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'Max Per Match must be equal to or less than Agent Max Per Match (for Motorsports)'
							WHEN 'zh-cn' THEN N'单场最高投注需相等于或少于代理单场最高投注(于赛车)'
							WHEN 'zh-tw' THEN N'單場最高投注需相等於或少於代理單場最高投注(於賽車)'
							WHEN 'zh-Hans' THEN N'单场最高投注需相等于或少于代理单场最高投注(于赛车)'
							WHEN 'TH' THEN N'จำนวนเงินสูงสุดในการเล่นต่อรายการต้องเท่ากับหรือน้อยกว่าจำนวนเงินสูงสุดต่อรายการที่กำหนดไว้ของตัวแทน (สำหรับกีฬารถแข่ง) '
							WHEN 'Ja' THEN N'Max Per Match must be equal to or less than Agent Max Per Match (for Motorsports)'
							WHEN 'KO' THEN N'최대 경기는 에이전트의 최대 경기보다 작아야 합니다 (모토스포츠)'
							ELSE N'Max Per Match must be equal to or less than Agent Max Per Match (for Motorsports)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MaxMaxPerMatchv11) + ').', @ErrCode = 113
				
		RETURN
	END
END
--- SB2
	if @UpdateMinMaxBetv44 = 1
BEGIN
	if 
		@MinBetv44 <0
		or @MaxBetv44 <0
		or @MaxPerMatchv44 <0		
	BEGIN
		SELECT @ErrCode = 3
		SELECT @ErrMsg = 	CASE @Language 
							WHEN 'en-us' THEN 'Wrong Min bet/ Max bet/ Max per match (for Muay Thai).'
							WHEN 'zh-cn' THEN N'最低投注/最高投注/单场最高投注不正确(于赛车).'
							WHEN 'zh-tw' THEN N'最低投注/最高投注/單場最高投注不正確(於賽車).'
							WHEN 'TH' THEN N'การกำหนดจำนวนเงินสำหรับการวางเดิมพันต่ำสุด/ สูงสุด/สูงสดต่อรายการไม่ถูกต้อง (สำหรับกีฬารถแข่ง).'
							WHEN 'Ja' THEN N'Wrong Min bet/ Max bet/ Max per match (for Muay Thai).'
							WHEN 'KO' THEN N'잘못된 최소 배팅/최대 배팅/경기당 최대 (모토스포츠).'
							ELSE N'Wrong Min bet/ Max bet/ Max per match (for Muay Thai).'
					END
		RETURN
	END
	
	SELECT 
		@MinMinBetv44 = Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
		@MaxMaxBetv44 = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
	from 
		Dep_CustSetting as cs WITH (NOLOCK)
		INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
		AND cs.bettype = 3 AND cs.sporttype=44
	WHERE ci.custid = @recommend
	
	if (@MinBetv44 <> 0 AND @MaxBetv44 <> 0 AND @MinBetv44>@MaxBetv44) or (@MaxBetv44 <> 0 AND @MaxPerMatchv44 <> 0 AND @MaxBetv44>@MaxPerMatchv44)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'min bet must be less than max bet AND max bet must be less than max bet per match (for Muay Thai)'
							WHEN 'zh-cn' THEN N'最低投注不能高于最高投注，最高投注不能高于单场最高投注设定(于赛车)'
							WHEN 'zh-tw' THEN N'最低投注不能高於最高投注,最高投注不能高於單場最高投注設定(於賽車)'
							WHEN 'TH' THEN N'จำนวนเงินต่ำสุดที่วางเดิมพันได้ต้องน้อยกว่าจำนวนเงินสูงสุดในการวางเดิมพันและจำนวนเงินสูงสุดในการวางเดิมพันต้องน้อยกว่าจำนวนเงินสูงสุดของเงินเดิมพันต่อเกม (สำหรับกีฬารถแข่ง)'
							WHEN 'Ja' THEN N'min bet must be less than max bet AND max bet must be less than max bet per match (for Muay Thai)'
							WHEN 'KO' THEN N'최소 배팅은 최대 배팅 이하이여야 하고 최대 배팅은 경기당 최대 배팅보다 작아야 합니다 (모토스포츠)'
							ELSE N'min bet must be less than max bet AND max bet must be less than max bet per match (for Muay Thai)'
						END						
						+ char(13) + char(10) + convert(VARCHAR(20), @MinBetv44) + '-' + convert(VARCHAR(20), @MaxBetv44) + '-' + convert(VARCHAR(20), @MaxPerMatchv44), @ErrCode = 111
				
		RETURN
	END
	
	IF (@MinMinBetv44>0 AND @MinBetv44>0 AND @MinBetv44<@MinMinBetv44)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'min bet must be equal to or greater than Agent min bet (for Muay Thai)'
							WHEN 'zh-cn' THEN N'最低投注需相等于或少于代理最低投注(于赛车)'
							WHEN 'zh-tw' THEN N'最低投注需相等於或少於代理最低投注(於賽車)'
							WHEN 'TH' THEN N'จำนวนเงินต่ำสุดในการเล่นต้องเท่ากับหรือมากกว่าจำนวนเงินขั้นต่ำในการเล่นที่กำหนดไว้ของตัวแทน (สำหรับกีฬารถแข่ง)'
							WHEN 'Ja' THEN N'min bet must be equal to or greater than Agent min bet (for Muay Thai)'
							WHEN 'KO' THEN N'최소 배팅은 에이전트의 최소 배팅 이상이여야 합니다 (모토스포츠)'
							ELSE N'min bet must be equal to or greater than Agent min bet (for Muay Thai)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MinMinBetv44) + ').', @ErrCode = 112
				
		RETURN
	END	
	IF (@MaxMaxBetv44>0 AND @MaxBetv44>0 AND @MaxBetv44>@MaxMaxBetv44)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'max bet must be equal to or less than Agent max bet (for Muay Thai)'
							WHEN 'zh-cn' THEN N'最高投注需相等于或少于代理最高投注(于赛车)'
							WHEN 'zh-tw' THEN N'最高投注需相等於或少於代理最高投注(於賽車)'
							WHEN 'TH' THEN N'จำนวนการวางเดิมพันสูงสุดต้องเท่ากับ หรือ น้อยกว่าราคาเดิมพันสูงสุดของตัวแทน (สำหรับกีฬารถแข่ง)'
							WHEN 'Ja' THEN N'max bet must be equal to or less than Agent max bet (for Muay Thai)'
							WHEN 'KO' THEN N'최대 배팅은 에이전트의 최대 배팅 이하이여야 합니다 (모토스포츠)'
							ELSE N'max bet must be equal to or less than Agent max bet (for Muay Thai)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MaxMaxBetv44) + ').', @ErrCode = 113
				
		RETURN
	END
	
	IF (@MaxMaxPerMatchv44>0 AND @MaxPerMatchv44>0 AND @MaxPerMatchv44>@MaxMaxPerMatchv44)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'Max Per Match must be equal to or less than Agent Max Per Match (for Muay Thai)'
							WHEN 'zh-cn' THEN N'单场最高投注需相等于或少于代理单场最高投注(于赛车)'
							WHEN 'zh-tw' THEN N'單場最高投注需相等於或少於代理單場最高投注(於賽車)'
							WHEN 'TH' THEN N'จำนวนเงินสูงสุดในการเล่นต่อรายการต้องเท่ากับหรือน้อยกว่าจำนวนเงินสูงสุดต่อรายการที่กำหนดไว้ของตัวแทน (สำหรับกีฬารถแข่ง) '
							WHEN 'Ja' THEN N'Max Per Match must be equal to or less than Agent Max Per Match (for Muay Thai)'
							WHEN 'KO' THEN N'최대 경기는 에이전트의 최대 경기보다 작아야 합니다 (모토스포츠)'
							ELSE N'Max Per Match must be equal to or less than Agent Max Per Match (for Muay Thai)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MaxMaxPerMatchv44) + ').', @ErrCode = 113
				
		RETURN
	END
END
	
-- END SB2


IF @UpdateMinMaxBetv154 = 1
BEGIN
	if 
		@MinBetv154 <0
		or @MaxBetv154 <0
		or @MaxPerMatchv154 <0		
	BEGIN
		SELECT @ErrCode = 3
		SELECT @ErrMsg = 	CASE @Language 
							WHEN 'en-us' THEN 'Wrong Min bet/ Max bet/ Max per match (for Horse Racing Fixed Odds).'
							WHEN 'zh-cn' THEN N'最低投注/最高投注/单场最高投注不正确(賽馬固定賠率).'
							WHEN 'zh-tw' THEN N'最低投注/最高投注/單場最高投注不正確(赛马固定赔率).'
							WHEN 'zh-Hans' THEN N'最低投注/最高投注/单场最高投注不正确(賽馬固定賠率).'
							WHEN 'TH' THEN N'การกำหนดจำนวนเงินสำหรับการวางเดิมพันต่ำสุด/ สูงสุด/สูงสดต่อรายการไม่ถูกต้อง (Horse Racing Fixed Odds).'
							WHEN 'Ja' THEN N'Wrong Min bet/ Max bet/ Max per match (for Horse Racing Fixed Odds).'
							WHEN 'KO' THEN N'잘못된 최소 배팅/최대 배팅/경기당 최대 (for Horse Racing Fixed Odds).'
							ELSE N'Wrong Min bet/ Max bet/ Max per match (for Horse Racing Fixed Odds).'
					END
		RETURN
	END
	
	SELECT 
		@MinMinBetv154 = Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
		@MaxMaxBetv154 = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
	from 
		Dep_CustSetting as cs WITH (NOLOCK)
		INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
		AND cs.bettype = 20 AND cs.sporttype=154
	WHERE ci.custid = @recommend
	
	if (@MinBetv154 <> 0 AND @MaxBetv154 <> 0 AND @MinBetv154>@MaxBetv154) or (@MaxBetv154 <> 0 AND @MaxPerMatchv154 <> 0 AND @MaxBetv154>@MaxPerMatchv154)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'min bet must be less than max bet AND max bet must be less than max bet per match (for Horse Racing Fixed Odds)'
							WHEN 'zh-cn' THEN N'最低投注不能高于最高投注，最高投注不能高于单场最高投注设定(賽馬固定賠率)'
							WHEN 'zh-tw' THEN N'最低投注不能高於最高投注,最高投注不能高於單場最高投注設定(賽馬固定賠率)'
							WHEN 'zh-Hans' THEN N'最低投注不能高于最高投注，最高投注不能高于单场最高投注设定(賽馬固定賠率)'
							WHEN 'TH' THEN N'จำนวนเงินต่ำสุดที่วางเดิมพันได้ต้องน้อยกว่าจำนวนเงินสูงสุดในการวางเดิมพันและจำนวนเงินสูงสุดในการวางเดิมพันต้องน้อยกว่าจำนวนเงินสูงสุดของเงินเดิมพันต่อเกม (Horse Racing Fixed Odds)'
							WHEN 'Ja' THEN N'min bet must be less than max bet AND max bet must be less than max bet per match (for Horse Racing Fixed Odds)'
							WHEN 'KO' THEN N'최소 배팅은 최대 배팅 이하이여야 하고 최대 배팅은 경기당 최대 배팅보다 작아야 합니다 (Horse Racing Fixed Odds)'
							ELSE N'min bet must be less than max bet AND max bet must be less than max bet per match (for Horse Racing Fixed Odds)'
						END						
						+ char(13) + char(10) + convert(VARCHAR(20), @MinBetv154) + '-' + convert(VARCHAR(20), @MaxBetv154) + '-' + convert(VARCHAR(20), @MaxPerMatchv154), @ErrCode = 111
				
		RETURN
	END
	
	IF (@MinMinBetv154>0 AND @MinBetv154>0 AND @MinBetv154<@MinMinBetv154)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'min bet must be equal to or greater than Agent min bet (for Horse Racing Fixed Odds)'
							WHEN 'zh-cn' THEN N'最低投注需相等于或少于代理最低投注(賽馬固定賠率)'
							WHEN 'zh-tw' THEN N'最低投注需相等於或少於代理最低投注(赛马固定赔率)'
							WHEN 'zh-Hans' THEN N'最低投注需相等于或少于代理最低投注(賽馬固定賠率)'
							WHEN 'TH' THEN N'จำนวนเงินต่ำสุดในการเล่นต้องเท่ากับหรือมากกว่าจำนวนเงินขั้นต่ำในการเล่นที่กำหนดไว้ของตัวแทน (Horse Racing Fixed Odds)'
							WHEN 'Ja' THEN N'min bet must be equal to or greater than Agent min bet (for Horse Racing Fixed Odds)'
							WHEN 'KO' THEN N'최소 배팅은 에이전트의 최소 배팅 이상이여야 합니다 (Horse Racing Fixed Odds)'
							ELSE N'min bet must be equal to or greater than Agent min bet (for Horse Racing Fixed Odds)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MinMinBetv154) + ').', @ErrCode = 112
				
		RETURN
	END	
	IF (@MaxMaxBetv154>0 AND @MaxBetv154>0 AND @MaxBetv154>@MaxMaxBetv154)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'max bet must be equal to or less than Agent max bet (for Horse Racing Fixed Odds)'
							WHEN 'zh-cn' THEN N'最高投注需相等于或少于代理最高投注(賽馬固定賠率)'
							WHEN 'zh-tw' THEN N'最高投注需相等於或少於代理最高投注(赛马固定赔率)'
							WHEN 'zh-Hans' THEN N'最高投注需相等于或少于代理最高投注(賽馬固定賠率)'
							WHEN 'TH' THEN N'จำนวนการวางเดิมพันสูงสุดต้องเท่ากับ หรือ น้อยกว่าราคาเดิมพันสูงสุดของตัวแทน (Horse Racing Fixed Odds)'
							WHEN 'Ja' THEN N'max bet must be equal to or less than Agent max bet (for Horse Racing Fixed Odds)'
							WHEN 'KO' THEN N'최대 배팅은 에이전트의 최대 배팅 이하이여야 합니다 (Horse Racing Fixed Odds)'
							ELSE N'max bet must be equal to or less than Agent max bet (for Horse Racing Fixed Odds)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MaxMaxBetv154) + ').', @ErrCode = 113
				
		RETURN
	END
	
	IF (@MaxMaxPerMatchv154>0 AND @MaxPerMatchv154>0 AND @MaxPerMatchv154>@MaxMaxPerMatchv154)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'Max Per Match must be equal to or less than Agent Max Per Match (for Horse Racing Fixed Odds)'
							WHEN 'zh-cn' THEN N'单场最高投注需相等于或少于代理单场最高投注(賽馬固定賠率)'
							WHEN 'zh-tw' THEN N'單場最高投注需相等於或少於代理單場最高投注(赛马固定赔率)'
							WHEN 'zh-Hans' THEN N'单场最高投注需相等于或少于代理单场最高投注(賽馬固定賠率)'
							WHEN 'TH' THEN N'จำนวนเงินสูงสุดในการเล่นต่อรายการต้องเท่ากับหรือน้อยกว่าจำนวนเงินสูงสุดต่อรายการที่กำหนดไว้ของตัวแทน (Horse Racing Fixed Odds) '
							WHEN 'Ja' THEN N'Max Per Match must be equal to or less than Agent Max Per Match (for Horse Racing Fixed Odds)'
							WHEN 'KO' THEN N'최대 경기는 에이전트의 최대 경기보다 작아야 합니다 (Horse Racing Fixed Odds)'
							ELSE N'Max Per Match must be equal to or less than Agent Max Per Match (for Horse Racing Fixed Odds)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MaxMaxPerMatchv154) + ').', @ErrCode = 113
				
		RETURN
	END
END

if @UpdateMinMaxBetv99 = 1
BEGIN
	if 
		@MinBetv99 <0
		or @MaxBetv99 <0
		or @MaxPerMatchv99 <0		
	BEGIN
		SELECT @ErrCode = 3
		SELECT @ErrMsg = 	CASE @Language 
							WHEN 'en-us' THEN 'Wrong Min bet/ Max bet/ Max per match (for Other sports).'
							WHEN 'zh-cn' THEN N'最低投注/最高投注/单场最高投注不正确(于其他).'
							WHEN 'zh-tw' THEN N'最低投注/最高投注/單場最高投注不正確(於其他).'
							WHEN 'zh-Hans' THEN N'最低投注/最高投注/单场最高投注不正确(于其他).'
							WHEN 'TH' THEN N'การกำหนดจำนวนเงินสำหรับการวางเดิมพันต่ำสุด/ สูงสุด/สูงสดต่อรายการไม่ถูกต้อง (สำหรับกีฬาอื่นๆ).'
							WHEN 'Ja' THEN N'Wrong Min bet/ Max bet/ Max per match (for Other sports).'
							WHEN 'KO' THEN N'잘못된 최소 배팅/최대 배팅/경기당 최대 (기타 스포츠).'
							ELSE N'Wrong Min bet/ Max bet/ Max per match (for Other sports).'
					END
		RETURN
	END
	
	SELECT 
		@MinMinBetv99 = Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
		@MaxMaxBetv99 = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
	from 
		Dep_CustSetting as cs WITH (NOLOCK)
		INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
		AND cs.bettype = 1 AND cs.sporttype=99
	WHERE ci.custid = @recommend
	
	if (@MinBetv99 <> 0 AND @MaxBetv99 <> 0 AND @MinBetv99>@MaxBetv99) or (@MaxBetv99 <> 0 AND @MaxPerMatchv99 <> 0 AND @MaxBetv99>@MaxPerMatchv99)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'min bet must be less than max bet AND max bet must be less than max bet per match (for Other sports)'
							WHEN 'zh-cn' THEN N'最低投注不能高于最高投注，最高投注不能高于单场最高投注设定(于其他)'
							WHEN 'zh-tw' THEN N'最低投注不能高於最高投注,最高投注不能高於單場最高投注設定(於其他)'
							WHEN 'zh-Hans' THEN N'最低投注不能高于最高投注，最高投注不能高于单场最高投注设定(于其他)'
							WHEN 'TH' THEN N'จำนวนเงินต่ำสุดที่วางเดิมพันได้ต้องน้อยกว่าจำนวนเงินสูงสุดในการวางเดิมพันและจำนวนเงินสูงสุดในการวางเดิมพันต้องน้อยกว่าจำนวนเงินสูงสุดของเงินเดิมพันต่อเกม (สำหรับกีฬาอื่นๆ)'
							WHEN 'Ja' THEN N'min bet must be less than max bet AND max bet must be less than max bet per match (for Other sports)'
							WHEN 'KO' THEN N'최소 배팅은 최대 배팅 이하이여야 하고 최대 배팅은 경기당 최대 배팅보다 작아야 합니다 (기타 스포츠)'
							ELSE N'min bet must be less than max bet AND max bet must be less than max bet per match (for Other sports)'
						END						
						+ char(13) + char(10) + convert(VARCHAR(20), @MinBetv99) + '-' + convert(VARCHAR(20), @MaxBetv99) + '-' + convert(VARCHAR(20), @MaxPerMatchv99), @ErrCode = 111
				
		RETURN
	END
	
	IF (@MinMinBetv99>0 AND @MinBetv99>0 AND @MinBetv99<@MinMinBetv99)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'min bet must be equal to or greater than Agent min bet (for Other sports)'
							WHEN 'zh-cn' THEN N'最低投注需相等于或少于代理最低投注(于其他)'
							WHEN 'zh-tw' THEN N'最低投注需相等於或少於代理最低投注(於其他)'
							WHEN 'zh-Hans' THEN N'最低投注需相等于或少于代理最低投注(于其他)'
							WHEN 'TH' THEN N'จำนวนเงินต่ำสุดในการเล่นต้องเท่ากับหรือมากกว่าจำนวนเงินขั้นต่ำในการเล่นที่กำหนดไว้ของตัวแทน (สำหรับกีฬาอื่นๆ)'
							WHEN 'Ja' THEN N'min bet must be equal to or greater than Agent min bet (for Other sports)'
							WHEN 'KO' THEN N'최소 배팅은 에이전트의 최소 배팅 이상이여야 합니다 (기타 스포츠)'
							ELSE N'min bet must be equal to or greater than Agent min bet (for Other sports)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MinMinBetv99) + ').', @ErrCode = 112
				
		RETURN
	END	
	IF (@MaxMaxBetv99>0 AND @MaxBetv99>0 AND @MaxBetv99>@MaxMaxBetv99)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'max bet must be equal to or less than Agent max bet (for Other sports)'
							WHEN 'zh-cn' THEN N'最高投注需相等于或少于代理最高投注(于其他)'
							WHEN 'zh-tw' THEN N'最高投注需相等於或少於代理最高投注(於其他)'
							WHEN 'zh-Hans' THEN N'最高投注需相等于或少于代理最高投注(于其他)'
							WHEN 'TH' THEN N'จำนวนการวางเดิมพันสูงสุดต้องเท่ากับ หรือ น้อยกว่าราคาเดิมพันสูงสุดของตัวแทน (สำหรับกีฬาอื่นๆ)'
							WHEN 'Ja' THEN N'max bet must be equal to or less than Agent max bet (for Other sports)'
							WHEN 'KO' THEN N'최대 배팅은 에이전트의 최대 배팅 이하이여야 합니다 (기타 스포츠)'
							ELSE N'max bet must be equal to or less than Agent max bet (for Other sports)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MaxMaxBetv99) + ').', @ErrCode = 113
				
		RETURN
	END
	
	IF (@MaxMaxPerMatchv99>0 AND @MaxPerMatchv99>0 AND @MaxPerMatchv99>@MaxMaxPerMatchv99)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'Max Per Match must be equal to or less than Agent Max Per Match (for Other sports)'
							WHEN 'zh-cn' THEN N'单场最高投注需相等于或少于代理单场最高投注(于其他)'
							WHEN 'zh-tw' THEN N'單場最高投注需相等於或少於代理單場最高投注(於其他)'
							WHEN 'zh-Hans' THEN N'单场最高投注需相等于或少于代理单场最高投注(于其他)'
							WHEN 'TH' THEN N'จำนวนเงินสูงสุดในการเล่นต่อรายการต้องเท่ากับหรือน้อยกว่าจำนวนเงินสูงสุดต่อรายการที่กำหนดไว้ของตัวแทน (สำหรับกีฬาอื่นๆ) '
							WHEN 'Ja' THEN N'Max Per Match must be equal to or less than Agent Max Per Match (for Other sports)'
							WHEN 'KO' THEN N'최대 경기는 에이전트의 최대 경기보다 작아야 합니다 (기타 스포츠)'
							ELSE N'Max Per Match must be equal to or less than Agent Max Per Match (for Other sports)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MaxMaxPerMatchv99) + ').', @ErrCode = 113
				
		RETURN
	END
END

if @UpdateMinMaxBetv99MP = 1
BEGIN
	if 
		@MinBetv99MP <0
		or @MaxBetv99MP <0
		or @MaxPerMatchv99MP <0		
	BEGIN
		SELECT @ErrCode = 3
		SELECT @ErrMsg = 	CASE @Language 
							WHEN 'en-us' THEN 'Wrong Min bet/ Max bet/ Max per match (for Mix Sports Parlay).'
							WHEN 'zh-cn' THEN N'最低投注/最高投注/单场最高投注不正确(供混合体育过关).'
							WHEN 'zh-tw' THEN N'最低投注/最高投注/單場最高投注不正確(供混合體育過關).'
							WHEN 'zh-Hans' THEN N'最低投注/最高投注/单场最高投注不正确(供混合体育过关).'
							WHEN 'TH' THEN N'การกำหนดจำนวนเงินสำหรับการวางเดิมพันต่ำสุด/ สูงสุด/สูงสดต่อรายการไม่ถูกต้อง (สำหรับกีฬาบอลชุด).'
							WHEN 'Ja' THEN N'Wrong Min bet/ Max bet/ Max per match (for Mix Sports Parlay).'
							WHEN 'KO' THEN N'잘못된 최소 배팅/최대 배팅/경기당 최대 (for Mix Sports Parlay).'
							ELSE N'Wrong Min bet/ Max bet/ Max per match (for Mix Sports Parlay).'
					END
		RETURN
	END
	
	SELECT 
		@MinMinBetv99MP = Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
		@MaxMaxBetv99MP = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
	from 
		Dep_CustSetting as cs WITH (NOLOCK)
		INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
		AND cs.bettype = 9 AND cs.sporttype=99
	WHERE ci.custid = @recommend
	
	if (@MinBetv99MP <> 0 AND @MaxBetv99MP <> 0 AND @MinBetv99MP>@MaxBetv99MP) or (@MaxBetv99MP <> 0 AND @MaxPerMatchv99MP <> 0 AND @MaxBetv99MP>@MaxPerMatchv99MP)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'min bet must be less than max bet AND max bet must be less than max bet per match (for Mix Sports Parlay)'
							WHEN 'zh-cn' THEN N'最低投注不能高于最高投注，最高投注不能高于单场最高投注设定(供混合体育过关)'
							WHEN 'zh-tw' THEN N'最低投注不能高於最高投注,最高投注不能高於單場最高投注設定(供混合體育過關)'
							WHEN 'zh-Hans' THEN N'最低投注不能高于最高投注，最高投注不能高于单场最高投注设定(供混合体育过关)'
							WHEN 'TH' THEN N'จำนวนเงินต่ำสุดที่วางเดิมพันได้ต้องน้อยกว่าจำนวนเงินสูงสุดในการวางเดิมพันและจำนวนเงินสูงสุดในการวางเดิมพันต้องน้อยกว่าจำนวนเงินสูงสุดของเงินเดิมพันต่อเกม (สำหรับกีฬาบอลชุด)'
							WHEN 'Ja' THEN N'min bet must be less than max bet AND max bet must be less than max bet per match (for Mix Sports Parlay)'
							WHEN 'KO' THEN N'최소 배팅은 최대 배팅 이하이여야 하고 최대 배팅은 경기당 최대 배팅보다 작아야 합니다 (for Mix Sports Parlay)'
							ELSE N'min bet must be less than max bet AND max bet must be less than max bet per match (for Mix Sports Parlay)'
						END						
						+ char(13) + char(10) + convert(VARCHAR(20), @MinBetv99MP) + '-' + convert(VARCHAR(20), @MaxBetv99MP) + '-' + convert(VARCHAR(20), @MaxPerMatchv99MP), @ErrCode = 111
				
		RETURN
	END
	
	IF (@MinMinBetv99MP>0 AND @MinBetv99MP>0 AND @MinBetv99MP<@MinMinBetv99MP)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'min bet must be equal to or greater than Agent min bet (for Mix Sports Parlay)'
							WHEN 'zh-cn' THEN N'最低投注需相等于或少于代理最低投注(供混合体育过关)'
							WHEN 'zh-tw' THEN N'最低投注需相等於或少於代理最低投注(供混合體育過關)'
							WHEN 'zh-Hans' THEN N'最低投注需相等于或少于代理最低投注(供混合体育过关)'
							WHEN 'TH' THEN N'จำนวนเงินต่ำสุดในการเล่นต้องเท่ากับหรือมากกว่าจำนวนเงินขั้นต่ำในการเล่นที่กำหนดไว้ของตัวแทน (สำหรับกีฬาบอลชุด)'
							WHEN 'Ja' THEN N'min bet must be equal to or greater than Agent min bet (for Mix Sports Parlay)'
							WHEN 'KO' THEN N'최소 배팅은 에이전트의 최소 배팅 이상이여야 합니다 (for Mix Sports Parlay)'
							ELSE N'min bet must be equal to or greater than Agent min bet (for Mix Sports Parlay)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MinMinBetv99MP) + ').', @ErrCode = 112
				
		RETURN
	END	
	IF (@MaxMaxBetv99MP>0 AND @MaxBetv99MP>0 AND @MaxBetv99MP>@MaxMaxBetv99MP)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'max bet must be equal to or less than Agent max bet (for Mix Sports Parlay)'
							WHEN 'zh-cn' THEN N'最高投注需相等于或少于代理最高投注(供混合体育过关)'
							WHEN 'zh-tw' THEN N'最高投注需相等於或少於代理最高投注(供混合體育過關)'
							WHEN 'zh-Hans' THEN N'最高投注需相等于或少于代理最高投注(供混合体育过关)'
							WHEN 'TH' THEN N'จำนวนการวางเดิมพันสูงสุดต้องเท่ากับ หรือ น้อยกว่าราคาเดิมพันสูงสุดของตัวแทน (สำหรับกีฬาบอลชุด)'
							WHEN 'Ja' THEN N'max bet must be equal to or less than Agent max bet (for Mix Sports Parlay)'
							WHEN 'KO' THEN N'최대 배팅은 에이전트의 최대 배팅 이하이여야 합니다 (for Mix Sports Parlay)'
							ELSE N'max bet must be equal to or less than Agent max bet (for Mix Sports Parlay)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MaxMaxBetv99MP) + ').', @ErrCode = 113
				
		RETURN
	END
	
	IF (@MaxMaxPerMatchv99MP>0 AND @MaxPerMatchv99MP>0 AND @MaxPerMatchv99MP>@MaxMaxPerMatchv99MP)
	BEGIN
		SELECT @ErrMsg =	@UserName + ': '+
						CASE @Language 
							WHEN 'en-us' THEN 'Max Per Match must be equal to or less than Agent Max Per Match (for Mix Sports Parlay)'
							WHEN 'zh-cn' THEN N'单场最高投注需相等于或少于代理单场最高投注(供混合体育过关)'
							WHEN 'zh-tw' THEN N'單場最高投注需相等於或少於代理單場最高投注(供混合體育過關)'
							WHEN 'zh-Hans' THEN N'单场最高投注需相等于或少于代理单场最高投注(供混合体育过关)'
							WHEN 'TH' THEN N'จำนวนเงินสูงสุดในการเล่นต่อรายการต้องเท่ากับหรือน้อยกว่าจำนวนเงินสูงสุดต่อรายการที่กำหนดไว้ของตัวแทน (สำหรับกีฬาบอลชุด) '
							WHEN 'Ja' THEN N'Max Per Match must be equal to or less than Agent Max Per Match (for Mix Sports Parlay)'
							WHEN 'KO' THEN N'최대 경기는 에이전트의 최대 경기보다 작아야 합니다 (for Mix Sports Parlay)'
							ELSE N'Max Per Match must be equal to or less than Agent Max Per Match (for Mix Sports Parlay)'
						END						
						+' (' + CONVERT(VARCHAR(20), @MaxMaxPerMatchv99MP) + ').', @ErrCode = 113
				
		RETURN
	END
END

--
SELECT @Old_MinBet = MinBet, @Old_MaxBet = MaxBet
FROM Dep_CustSetting WITH(NOLOCK)
WHERE custid = @custid AND bettype = 1 AND sporttype=1

--
SELECT @Old_MinBetv2 = MinBet, @Old_MaxBetv2 = MaxBet
FROM Dep_CustSetting WITH(NOLOCK)
WHERE custid = @custid AND bettype = 1 AND sporttype=2

--
SELECT @Old_MinBetv3 = MinBet, @Old_MaxBetv3 = MaxBet
FROM Dep_CustSetting WITH(NOLOCK)
WHERE custid = @custid AND bettype = 1 AND sporttype=3

--
SELECT @Old_MinBetv5 = MinBet, @Old_MaxBetv5 = MaxBet
FROM Dep_CustSetting WITH(NOLOCK)
WHERE custid = @custid AND bettype = 1 AND sporttype=5

--
SELECT @Old_MinBetv8 = MinBet, @Old_MaxBetv8 = MaxBet
FROM Dep_CustSetting WITH(NOLOCK)
WHERE custid = @custid AND bettype = 1 AND sporttype=8

--
SELECT @Old_MinBetv10 = MinBet, @Old_MaxBetv10 = MaxBet
FROM Dep_CustSetting WITH(NOLOCK)
WHERE custid = @custid AND bettype = 1 AND sporttype=10

--
SELECT @Old_MinBetv11 = MinBet, @Old_MaxBetv11 = MaxBet
FROM Dep_CustSetting WITH(NOLOCK)
WHERE custid = @custid AND bettype = 1 AND sporttype=11
--
SELECT @Old_MinBetv44 = MinBet, @Old_MaxBetv44 = MaxBet
FROM Dep_CustSetting WITH(NOLOCK)
WHERE custid = @custid AND bettype = 3 AND sporttype=44
--
SELECT @Old_MinBetv154 = MinBet, @Old_MaxBetv154 = MaxBet
FROM Dep_CustSetting WITH(NOLOCK)
WHERE custid = @custid AND bettype = 20 AND sporttype=154

--
SELECT @Old_MinBetv99 = MinBet, @Old_MaxBetv99 = MaxBet
FROM Dep_CustSetting WITH(NOLOCK)
WHERE custid = @custid AND bettype = 1 AND sporttype=99

--
SELECT @Old_MinBetv99MP = MinBet, @Old_MaxBetv99MP = MaxBet
FROM Dep_CustSetting WITH(NOLOCK)
WHERE custid = @custid AND bettype = 9 AND sporttype=99


SELECT 
	@Old_MaxPerMatch = maxpermatch,
	@Old_MaxPerMatchv2 = maxpermatch2,
	@Old_MaxPerMatchv3 = maxpermatch3,
	@Old_MaxPerMatchv5 = maxpermatch5,
	@Old_MaxPerMatchv8 = maxpermatch8,
	@Old_MaxPerMatchv10 = maxpermatch10,
	@Old_MaxPerMatchv11 = maxpermatch11,
	@Old_MaxPerMatchv44 = maxpermatch44,
	@Old_MaxPerMatchv154 = maxpermatch154,
	@Old_MaxPerMatchv99 = maxpermatch99,
	@Old_MaxPerMatchv99MP = maxpermatch99MP
FROM custinfo WITH (NOLOCK)
WHERE custid = @custid




----------
UPDATE Dep_CustSetting WITH (ROWLOCK, UPDLOCK)
SET
	MinBet=CASE WHEN ((@UpdateMinMaxBet = 0 AND sporttype=1)
												OR (@UpdateMinMaxBetv2 = 0 AND sporttype=2)
												OR (@UpdateMinMaxBetv3 = 0 AND sporttype=3)
												OR (@UpdateMinMaxBetv5 = 0 AND sporttype=5)
												OR (@UpdateMinMaxBetv8 = 0 AND sporttype=8)
												OR (@UpdateMinMaxBetv10 = 0 AND sporttype=10)
												OR (@UpdateMinMaxBetv11 = 0 AND sporttype=11)
												OR (@UpdateMinMaxBetv44 = 0 AND sporttype=44 AND bettype=3)
												OR (@UpdateMinMaxBetv154 = 0 AND sporttype=154)
												OR (@UpdateMinMaxBetv99 = 0 AND sporttype=99 AND bettype<>9)
												OR (@UpdateMinMaxBetv99MP = 0 AND sporttype=99 AND bettype=9)
												) THEN MinBet ELSE CASE sporttype WHEN 1 THEN @MinBet WHEN 2 THEN @MinBetv2 WHEN 3 THEN @MinBetv3 WHEN 5 THEN @MinBetv5 WHEN 8 THEN @MinBetv8 WHEN 10 THEN @MinBetv10 WHEN 11 THEN @MinBetv11 WHEN 44 THEN @minbetv44 WHEN 154 THEN @MinBetv154 WHEN 99 THEN (CASE bettype WHEN 9 THEN @MinBetv99MP ELSE @MinBetv99 END) ELSE minbet END END,
	MaxBet=CASE WHEN  ((@UpdateMinMaxBet = 0 AND sporttype=1)
												OR (@UpdateMinMaxBetv2 = 0 AND sporttype=2)
												OR (@UpdateMinMaxBetv3 = 0 AND sporttype=3)
												OR (@UpdateMinMaxBetv5 = 0 AND sporttype=5)
												OR (@UpdateMinMaxBetv8 = 0 AND sporttype=8)
												OR (@UpdateMinMaxBetv10 = 0 AND sporttype=10)
												OR (@UpdateMinMaxBetv11 = 0 AND sporttype=11)
												OR (@UpdateMinMaxBetv44 = 0 AND sporttype=44 AND bettype=3)
												OR (@UpdateMinMaxBetv154 = 0 AND sporttype=154)
												OR (@UpdateMinMaxBetv99 = 0 AND sporttype=99 AND bettype<>9)
												OR (@UpdateMinMaxBetv99MP = 0 AND sporttype=99 AND bettype=9)
												) THEN MaxBet ELSE CASE sporttype WHEN 1 THEN @MaxBet WHEN 2 THEN @MaxBetv2 WHEN 3 THEN @MaxBetv3 WHEN 5 THEN @MaxBetv5 WHEN 8 THEN @MaxBetv8 WHEN 10 THEN @MaxBetv10 WHEN 11 THEN @MaxBetv11 WHEN 44 THEN @MaxBetv44 WHEN 154 THEN @MaxBetv154 WHEN 99 THEN (CASE bettype WHEN 9 THEN @MaxBetv99MP ELSE @MaxBetv99 END) ELSE maxbet END END
WHERE custid=@custid


if ( @@error <> 0 )
begin
	
	SELECT @ErrMsg = @UserName + ': '+
					CASE @Language 
						WHEN 'en-us' THEN 'Update process is unsuccessful !'
						WHEN 'zh-cn' THEN N'更新程序不成功 !'
						WHEN 'zh-tw' THEN N'更新程序不成功 !'
						WHEN 'zh-Hans' THEN N'更新程序不成功 !'
						WHEN 'TH' THEN N'ขั้นตอนหรือกระบวนการในการปรับยอดไม่เสร็จสิ้น!'
						WHEN 'Ja' THEN N'アップデート出来ません。'
						WHEN 'KO' THEN N'업데이트에 실패했습니다.'
						ELSE N'Update process is unsuccessful !'
					END, @ErrCode = 115
	RETURN
END


EXEC dbo.Lrf_CustomerUpdMaxPerMatch 
	@custid = @custid,
	@maxpermatch = @maxpermatch,
	@maxpermatchv2 = @maxpermatchv2,
	@maxpermatchv3 = @maxpermatchv3,
	@maxpermatchv5 = @maxpermatchv5,
	@maxpermatchv8 = @maxpermatchv8,
	@maxpermatchv10 = @maxpermatchv10,
	@maxpermatchv11 = @maxpermatchv11,
	@maxpermatchv44 = @maxpermatchv44,
	@maxpermatchv154 = @maxpermatchv154,
	@maxpermatchv99 = @maxpermatchv99,
	@maxpermatchv99MP = @maxpermatchv99MP,
	@UpdateMinMaxBet = @UpdateMinMaxBet,
	@UpdateMinMaxBetv2 = @UpdateMinMaxBetv2,
	@UpdateMinMaxBetv3 = @UpdateMinMaxBetv3,
	@UpdateMinMaxBetv5 = @UpdateMinMaxBetv5,
	@UpdateMinMaxBetv8 = @UpdateMinMaxBetv8,
	@UpdateMinMaxBetv10 = @UpdateMinMaxBetv10,
	@UpdateMinMaxBetv11 = @UpdateMinMaxBetv11,
	@UpdateMinMaxBetv44 = @UpdateMinMaxBetv44,
	@UpdateMinMaxBetv154 = @UpdateMinMaxBetv154,
	@UpdateMinMaxBetv99 = @UpdateMinMaxBetv99,
	@UpdateMinMaxBetv99MP = @UpdateMinMaxBetv99MP,
	@Language = @Language,
	@ErrCode = @ErrCode OUTPUT,
	@ErrMsg = @ErrMsg OUTPUT
	if @ErrCode > 0
	BEGIN
		RETURN
	END

IF @UpdateMinMaxBet = 0
BEGIN
	SET @minbet = @Old_minbet
	SET @maxbet = @Old_maxbet
	SET @maxpermatch = @Old_MaxPerMatch
END


IF @UpdateMinMaxBetv2 = 0
BEGIN
	SET @minbetv2 = @Old_minbetv2
	SET @maxbetv2 = @Old_maxbetv2
	SET @maxpermatchv2 = @Old_maxpermatchv2
END

IF @UpdateMinMaxBetv3 = 0
BEGIN
	SET @minbetv3 = @Old_minbetv3
	SET @maxbetv3 = @Old_maxbetv3
	SET @maxpermatchv3 = @Old_maxpermatchv3
END

IF @UpdateMinMaxBetv5 = 0
BEGIN
	SET @minbetv5 = @Old_minbetv5
	SET @maxbetv5 = @Old_maxbetv5
	SET @maxpermatchv5 = @Old_maxpermatchv5
END

IF @UpdateMinMaxBetv8 = 0
BEGIN
	SET @minbetv8 = @Old_minbetv8
	SET @maxbetv8 = @Old_maxbetv8
	SET @maxpermatchv8 = @Old_maxpermatchv8
END

IF @UpdateMinMaxBetv10 = 0
BEGIN
	SET @minbetv10 = @Old_minbetv10
	SET @maxbetv10 = @Old_maxbetv10
	SET @maxpermatchv10 = @Old_maxpermatchv10
END

IF @UpdateMinMaxBetv11 = 0
BEGIN
	SET @minbetv11 = @Old_minbetv11
	SET @maxbetv11 = @Old_maxbetv11
	SET @maxpermatchv11 = @Old_maxpermatchv11
END
---
IF @UpdateMinMaxBetv44 = 0
BEGIN
	SET @minbetv44 = @Old_minbetv44
	SET @maxbetv44 = @Old_maxbetv44
	SET @maxpermatchv44 = @Old_maxpermatchv44
END

IF @UpdateMinMaxBetv154 = 0
BEGIN
	SET @minbetv154 = @Old_minbetv154
	SET @maxbetv154 = @Old_maxbetv154
	SET @maxpermatchv154 = @Old_maxpermatchv154
END

IF @UpdateMinMaxBetv99 = 0
BEGIN
	SET @minbetv99 = @Old_minbetv99
	SET @maxbetv99 = @Old_maxbetv99
	SET @maxpermatchv99 = @Old_maxpermatchv99
END

IF @UpdateMinMaxBetv99MP = 0
BEGIN
	SET @minbetv99MP = @Old_minbetv99MP
	SET @maxbetv99MP = @Old_maxbetv99MP
	SET @maxpermatchv99MP = @Old_maxpermatchv99MP
END


	
DECLARE @TrackingValue VARCHAR(5000)

SELECT @TrackingValue ='<Lrf_CustomerUpdMember_MinMaxBet custid="'+ COALESCE(CAST(@custid as VARCHAR(50)),SPACE(1)) + '" ' +
'MinB="'+ COALESCE(CAST(@minbet as VARCHAR(50)),SPACE(1)) + '" ' +
'MaxB="'+ COALESCE(CAST(@maxbet as VARCHAR(50)),SPACE(1)) + '" ' +
'MPM="'+ COALESCE(CAST(@maxpermatch as VARCHAR(50)),SPACE(1)) + '" ' +
'MinBv2="'+ COALESCE(CAST(@minbetv2 as VARCHAR(50)),SPACE(1)) + '" ' +
'MaxBv2="'+ COALESCE(CAST(@maxbetv2 as VARCHAR(50)),SPACE(1)) + '" ' +
'MPMv2="'+ COALESCE(CAST(@maxpermatchv2 as VARCHAR(50)),SPACE(1)) + '" ' +
'MinBv3="'+ COALESCE(CAST(@minbetv3 as VARCHAR(50)),SPACE(1)) + '" ' +
'MaxBv3="'+ COALESCE(CAST(@maxbetv3 as VARCHAR(50)),SPACE(1)) + '" ' +
'MPMv3="'+ COALESCE(CAST(@maxpermatchv3 as VARCHAR(50)),SPACE(1)) + '" ' +
'MinBv5="'+ COALESCE(CAST(@minbetv5 as VARCHAR(50)),SPACE(1))  + '" ' +
'MaxBv5="'+ COALESCE(CAST(@maxbetv5 as VARCHAR(50)),SPACE(1)) + '" ' +
'MPMv5="'+ COALESCE(CAST(@maxpermatchv5 as VARCHAR(50)),SPACE(1)) + '" ' +
'MinBv8="'+ COALESCE(CAST(@minbetv8 as VARCHAR(50)),SPACE(1)) + '" ' +
'MaxBv8="'+ COALESCE(CAST(@maxbetv8 as VARCHAR(50)),SPACE(1)) + '" ' +
'MPMv8="'+ COALESCE(CAST(@maxpermatchv8 as VARCHAR(50)),SPACE(1)) + '" ' +
'MinBv10="'+ COALESCE(CAST(@minbetv10 as VARCHAR(50)),SPACE(1)) + '" ' +
'MaxBv10="'+ COALESCE(CAST(@maxbetv10 as VARCHAR(50)),SPACE(1)) + '" ' +
'MPMv10="'+ COALESCE(CAST(@maxpermatchv10 as VARCHAR(50)),SPACE(1)) + '" ' +
'MinBv11="'+ COALESCE(CAST(@minbetv11 as VARCHAR(50)),SPACE(1)) + '" ' +
'MaxBv11="'+ COALESCE(CAST(@maxbetv11 as VARCHAR(50)),SPACE(1)) + '" ' +
'MPMv11="'+ COALESCE(CAST(@maxpermatchv11 as VARCHAR(50)),SPACE(1))  + '" ' +
'MinBv44="'+ COALESCE(CAST(@minbetv44 as VARCHAR(50)),SPACE(1)) + '" ' +
'MaxBv44="'+ COALESCE(CAST(@maxbetv44 as VARCHAR(50)),SPACE(1)) + '" ' +
'MPMv44="'+ COALESCE(CAST(@maxpermatchv44 as VARCHAR(50)),SPACE(1))  + '" ' +
'MinBv154="'+ COALESCE(CAST(@minbetv154 as VARCHAR(50)),SPACE(1)) + '" ' +
'MaxBv154="'+ COALESCE(CAST(@maxbetv154 as VARCHAR(50)),SPACE(1)) + '" ' +
'MPMv154="'+ COALESCE(CAST(@maxpermatchv154 as VARCHAR(50)),SPACE(1))  + '" ' +
'MinBv99="'+ COALESCE(CAST(@minbetv99 as VARCHAR(50)),SPACE(1)) + '" ' +
'MaxBv99="'+ COALESCE(CAST(@maxbetv99 as VARCHAR(50)),SPACE(1)) + '" ' +
'MPMv99="'+ COALESCE(CAST(@maxpermatchv99 as VARCHAR(50)),SPACE(1)) + '" ' +
'MinBv99MP="'+ COALESCE(CAST(@minbetv99MP as VARCHAR(50)),SPACE(1)) + '" ' +
'MaxBv99MP="'+ COALESCE(CAST(@maxbetv99MP as VARCHAR(50)),SPACE(1)) + '" ' +
'MPMv99MP="'+ COALESCE(CAST(@maxpermatchv99MP as VARCHAR(50)),SPACE(1)) + '" ' +
'UMMB="'+ COALESCE(CAST(@UpdateMinMaxBet as VARCHAR(50)),SPACE(1)) + '" ' +
'UMMBv2="'+ COALESCE(CAST(@UpdateMinMaxBetv2 as VARCHAR(50)),SPACE(1)) + '" ' +
'UMMBv3="'+ COALESCE(CAST(@UpdateMinMaxBetv3 as VARCHAR(50)),SPACE(1)) + '" ' +
'UMMBv5="'+ COALESCE(CAST(@UpdateMinMaxBetv5 as VARCHAR(50)),SPACE(1)) + '" ' +
'UMMBv8="'+ COALESCE(CAST(@UpdateMinMaxBetv8 as VARCHAR(50)),SPACE(1)) + '" ' +
'UMMBv10="'+ COALESCE(CAST(@UpdateMinMaxBetv10 as VARCHAR(50)),SPACE(1)) + '" ' +
'UMMBv11="'+ COALESCE(CAST(@UpdateMinMaxBetv11 as VARCHAR(50)),SPACE(1)) + '" ' +
'UMMBv44="'+ COALESCE(CAST(@UpdateMinMaxBetv44 as VARCHAR(50)),SPACE(1)) + '" ' +
'UMMBv154="'+ COALESCE(CAST(@UpdateMinMaxBetv154 as VARCHAR(50)),SPACE(1)) + '" ' +
'UMMBv99="'+ COALESCE(CAST(@UpdateMinMaxBetv99 as VARCHAR(50)),SPACE(1)) + '" ' +
'UMMBv99MP="'+ COALESCE(CAST(@UpdateMinMaxBetv99MP as VARCHAR(50)),SPACE(1)) + '" ' +
'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
'Language="'+ COALESCE(CAST(@Language as VARCHAR(10)),SPACE(1)) + '" ' +
'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(5000)),SPACE(1)) + '" />'

DECLARE @TrackingValue2 VARCHAR(5000)
SELECT @TrackingValue2 ='<Lrf_CustomerUpdMember_MinMaxBet custid="'+ COALESCE(CAST(@custid as VARCHAR(50)),SPACE(1)) + '" ' +
'MinB="'+ COALESCE(CAST(@Old_minbet as VARCHAR(50)),SPACE(1)) + '" ' +
'MaxB="'+ COALESCE(CAST(@Old_maxbet as VARCHAR(50)),SPACE(1)) + '" ' +
'MPM="'+ COALESCE(CAST(@Old_maxpermatch as VARCHAR(50)),SPACE(1)) + '" ' +
'MinBv2="'+ COALESCE(CAST(@Old_minbetv2 as VARCHAR(50)),SPACE(1)) + '" ' +
'MaxBv2="'+ COALESCE(CAST(@Old_maxbetv2 as VARCHAR(50)),SPACE(1)) + '" ' +
'MPMv2="'+ COALESCE(CAST(@Old_maxpermatchv2 as VARCHAR(50)),SPACE(1)) + '" ' +
'MinBv3="'+ COALESCE(CAST(@Old_minbetv3 as VARCHAR(50)),SPACE(1)) + '" ' +
'MaxBv3="'+ COALESCE(CAST(@Old_maxbetv3 as VARCHAR(50)),SPACE(1)) + '" ' +
'MPMv3="'+ COALESCE(CAST(@Old_maxpermatchv3 as VARCHAR(50)),SPACE(1)) + '" ' +
'MinBv5="'+ COALESCE(CAST(@Old_minbetv5 as VARCHAR(50)),SPACE(1))  + '" ' +
'MaxBv5="'+ COALESCE(CAST(@Old_maxbetv5 as VARCHAR(50)),SPACE(1)) + '" ' +
'MPMv5="'+ COALESCE(CAST(@Old_maxpermatchv5 as VARCHAR(50)),SPACE(1)) + '" ' +
'MinBv8="'+ COALESCE(CAST(@Old_minbetv8 as VARCHAR(50)),SPACE(1)) + '" ' +
'MaxBv8="'+ COALESCE(CAST(@Old_maxbetv8 as VARCHAR(50)),SPACE(1)) + '" ' +
'MPMv8="'+ COALESCE(CAST(@Old_maxpermatchv8 as VARCHAR(50)),SPACE(1)) + '" ' +
'MinBv10="'+ COALESCE(CAST(@Old_minbetv10 as VARCHAR(50)),SPACE(1)) + '" ' +
'MaxBv10="'+ COALESCE(CAST(@Old_maxbetv10 as VARCHAR(50)),SPACE(1)) + '" ' +
'MPMv10="'+ COALESCE(CAST(@Old_maxpermatchv10 as VARCHAR(50)),SPACE(1)) + '" ' +
'MinBv11="'+ COALESCE(CAST(@Old_minbetv11 as VARCHAR(50)),SPACE(1)) + '" ' +
'MaxBv11="'+ COALESCE(CAST(@Old_maxbetv11 as VARCHAR(50)),SPACE(1)) + '" ' +
'MPMv11="'+ COALESCE(CAST(@Old_maxpermatchv11 as VARCHAR(50)),SPACE(1))  + '" ' +
'MinBv44="'+ COALESCE(CAST(@Old_minbetv44 as VARCHAR(50)),SPACE(1)) + '" ' +
'MaxBv44="'+ COALESCE(CAST(@Old_maxbetv44 as VARCHAR(50)),SPACE(1)) + '" ' +
'MPMv44="'+ COALESCE(CAST(@Old_maxpermatchv44 as VARCHAR(50)),SPACE(1))  + '" ' +	
'MinBv154="'+ COALESCE(CAST(@Old_minbetv154 as VARCHAR(50)),SPACE(1)) + '" ' +
'MaxBv154="'+ COALESCE(CAST(@Old_maxbetv154 as VARCHAR(50)),SPACE(1)) + '" ' +
'MPMv154="'+ COALESCE(CAST(@Old_maxpermatchv154 as VARCHAR(50)),SPACE(1))  + '" ' +
'MinBv99="'+ COALESCE(CAST(@Old_minbetv99 as VARCHAR(50)),SPACE(1)) + '" ' +
'MaxBv99="'+ COALESCE(CAST(@Old_maxbetv99 as VARCHAR(50)),SPACE(1)) + '" ' +
'MPMv99="'+ COALESCE(CAST(@Old_maxpermatchv99 as VARCHAR(50)),SPACE(1)) + '" ' +
'MinBv99MP="'+ COALESCE(CAST(@Old_minbetv99MP as VARCHAR(50)),SPACE(1)) + '" ' +
'MaxBv99MP="'+ COALESCE(CAST(@Old_maxbetv99MP as VARCHAR(50)),SPACE(1)) + '" ' +
'MPMv99MP="'+ COALESCE(CAST(@Old_maxpermatchv99MP as VARCHAR(50)),SPACE(1)) + '" ' +
'UMMB="'+ COALESCE(CAST(@UpdateMinMaxBet as VARCHAR(50)),SPACE(1)) + '" ' +
'UMMBv2="'+ COALESCE(CAST(@UpdateMinMaxBetv2 as VARCHAR(50)),SPACE(1)) + '" ' +
'UMMBv3="'+ COALESCE(CAST(@UpdateMinMaxBetv3 as VARCHAR(50)),SPACE(1)) + '" ' +
'UMMBv5="'+ COALESCE(CAST(@UpdateMinMaxBetv5 as VARCHAR(50)),SPACE(1)) + '" ' +
'UMMBv8="'+ COALESCE(CAST(@UpdateMinMaxBetv8 as VARCHAR(50)),SPACE(1)) + '" ' +
'UMMBv10="'+ COALESCE(CAST(@UpdateMinMaxBetv10 as VARCHAR(50)),SPACE(1)) + '" ' +
'UMMBv11="'+ COALESCE(CAST(@UpdateMinMaxBetv11 as VARCHAR(50)),SPACE(1)) + '" ' +
'UMMBv44="'+ COALESCE(CAST(@UpdateMinMaxBetv44 as VARCHAR(50)),SPACE(1)) + '" ' +
'UMMBv154="'+ COALESCE(CAST(@UpdateMinMaxBetv154 as VARCHAR(50)),SPACE(1)) + '" ' +
'UMMBv99="'+ COALESCE(CAST(@UpdateMinMaxBetv99 as VARCHAR(50)),SPACE(1)) + '" ' +
'UMMBv99MP="'+ COALESCE(CAST(@UpdateMinMaxBetv99MP as VARCHAR(50)),SPACE(1)) + '" ' +
'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
'Language="'+ COALESCE(CAST(@Language as VARCHAR(10)),SPACE(1)) + '" ' +
'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(5000)),SPACE(1)) + '" />'


SET @endRun = GETDATE()
SET @duration  = datediff (millisecond,@startRun,@endRun)

EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
	@UserID = @UserID,
	@CustID = @CustID,
	@ActionID = 2000,
	@TrackingValue = @TrackingValue,
	@TrackingValue2 = @TrackingValue2,
	@duration = @duration

---------------------------------------------------------
GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerUpdMember_MinMaxBet] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerUpdMember_MinMaxBet] TO [vnteam] AS [dbo]