/*<info serverAlias="DBCUST-CustDB" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CustomerUpdMaxPerMatch]
	@custid INT,
	@maxpermatch MONEY,
	@maxpermatchv2 MONEY,
	@maxpermatchv3 MONEY,
	@maxpermatchv5 MONEY,
	@maxpermatchv8 MONEY,
	@maxpermatchv10 MONEY,
	@maxpermatchv11 MONEY,
	@maxpermatchv99 MONEY,
	@maxpermatchv1MP MONEY = 0,
	@maxpermatchv99MP MONEY,	
	@UpdateMinMaxBet BIT = 1,
	@UpdateMinMaxBetv2 BIT = 1,
	@UpdateMinMaxBetv3 BIT = 1,
	@UpdateMinMaxBetv5 BIT = 1,
	@UpdateMinMaxBetv8 BIT = 1,
	@UpdateMinMaxBetv10 BIT = 1,
	@UpdateMinMaxBetv11 BIT = 1,
	@UpdateMinMaxBetv99 BIT = 1,
	@UpdateMinMaxBetv1MP BIT = 0,
	@UpdateMinMaxBetv99MP BIT = 1,
	@Language VARCHAR(10) = 'en-us',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg nvarchar(4000) = '' OUTPUT
AS
--Update Maxpermatch in db
/*
Created: 20101216@Henry
Task : Update Maxpermatch
DB: DBCUST/CustDB
Original: [Acc_CustomerUpdMaxPerMatch]
Revisions:
	- 20110520@Henry: Remove Number Game (by using SP: Lrf_CustomerUpdMaxPerMatch161)
	- 20140207@Jim: support to offer Horse Racing Fixed Odds
 
	- 20151023@Victor: Support New Simplified Chinese
 
	- 20151015@Jim: Integrate Sportbook2 (Feature #44759)
	- 20181009@Winnie: Remove Racing  (Feature #99378)
	- 20190909@Eden: 3rd party products - Remove InActive Products Phase 2 [Redmine: #118699]
	- 20200615@Johnson: add soccer parlay [redmine:#135261]
Param's Explanation:
• @ErrCode:
    = 0: Update successfully.
    > 0: Specific Error.
  
• @ErrMsg: Error description.
*/

update custinfo with (ROWLOCK, UPDLOCK)
SET 	
	MaxPerMatch=CASE WHEN @UpdateMinMaxBet=1 THEN @MaxPerMatch ELSE MaxPerMatch END,
	MaxPerMatch2=CASE WHEN @UpdateMinMaxBetv2=1 THEN @MaxPerMatchv2 ELSE MaxPerMatch2 END,
	MaxPerMatch3=CASE WHEN @UpdateMinMaxBetv3=1 THEN @MaxPerMatchv3 ELSE MaxPerMatch3 END,
	MaxPerMatch5=CASE WHEN  @UpdateMinMaxBetv5=1 THEN @MaxPerMatchv5 ELSE MaxPerMatch5 END,
	MaxPerMatch8=CASE WHEN  @UpdateMinMaxBetv8=1 THEN @MaxPerMatchv8 ELSE MaxPerMatch8 END,
	MaxPerMatch10=CASE WHEN @UpdateMinMaxBetv10=1 THEN @MaxPerMatchv10 ELSE MaxPerMatch10 END,
	MaxPerMatch11=CASE WHEN @UpdateMinMaxBetv11=1 THEN @MaxPerMatchv11 ELSE MaxPerMatch11 END,	
	MaxPerMatch99=CASE WHEN @UpdateMinMaxBetv99=1 THEN @MaxPerMatchv99 ELSE MaxPerMatch99 END,
	MaxPerMatch1MP=CASE WHEN @UpdateMinMaxBetv1MP=1 THEN @MaxPerMatchv1MP ELSE MaxPerMatch1MP END,
	MaxPerMatch99MP=CASE WHEN @UpdateMinMaxBetv99MP=1 THEN @MaxPerMatchv99MP ELSE MaxPerMatch99MP END
WHERE custid = @custid 
if (@@error <> 0)
begin
	SELECT @ErrMsg = CASE @Language 
						WHEN 'en-us' THEN 'Update process is unsuccessful !'
						WHEN 'zh-cn' THEN N'更新程序不成功 !'
						WHEN 'zh-tw' THEN N'更新程序不成功 !'
						WHEN 'zh-Hans' THEN N'更新程序不成功 !'
						WHEN 'TH' THEN N'ขั้นตอนหรือกระบวนการในการปรับยอดไม่เสร็จสิ้น.'
						WHEN 'Ja' THEN N'アップデート出来ません。'
						WHEN 'KO' THEN N'업데이트에 실패했습니다.'
						ELSE N'Update process is unsuccessful !'
					END, @ErrCode = 115
	RETURN
END

GO
