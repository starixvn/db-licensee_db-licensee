 ALTER PROCEDURE [dbo].[Lrf_CustomerUpdMember_MinMaxBet153_51]
	@custid			INT,-- MemberID
	@minbet			MONEY,
	@maxbet			MONEY,
	@maxpermatch	MONEY,
	@UserID			INT = 0,	
	@Language		VARCHAR(2)		= 'E',
	@IP				VARCHAR(40)		='',
	@ErrCode		INT				= 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000)	= '' OUTPUT
AS

/*
Created: 20110330@Henry
Task : Update member's minbet, maxbet, max per match for Harness racing
DB: DBTRANS.bodb02

Revisions:
	- 20110505@Henry: change the ActionID
	- 20110518@Henry: Logging Enhancement
	- 20120326@Dom: Change CustSetting3rd to Dep_CustSetting3rd
Param's Explanation:
• @ErrCode:
    = 0: Transaction recorded successfully.
    > 0: Specific Error.
  
• @ErrMsg: Error description.
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @startRun DATETIME,
			@endRun DATETIME,
			@duration INT,
			@minbet_old MONEY,
			@maxbet_old MONEY,
			@maxpermatch_old MONEY

	SET @startRun = GETDATE()

	DECLARE @MinMinBet		MONEY, 
			@MaxMaxBet		MONEY,	
			@MaxMaxPerMatch MONEY
		
	DECLARE @ErrAcc		VARCHAR(4000), 
			@ErrType	VARCHAR(4000),
			@UserName	VARCHAR(30), 
			@recommend	INT
			
	SELECT @UserName = username, @recommend = recommend
	FROM customer WITH (NOLOCK)
	WHERE roleid = 1 AND CustID = @CustID

	IF (@username = NULL) RETURN

	---------------------------------------------------------------
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
	---------------------------------------------------------------

	SELECT
		@MinMinBet = MAX(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
		@MaxMaxBet = MIN(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
	FROM 
		Dep_CustSetting3rd AS cs WITH (NOLOCK)
		INNER JOIN custinfo AS ci WITH (NOLOCK) ON (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
		AND cs.bettype = 51 AND cs.sporttype=153
	WHERE ci.custid = @recommend


	SELECT @MaxMaxperMatch = MIN(CASE WHEN cs.MaxPerMatch153_AU = 0 THEN NULL ELSE cs.MaxPerMatch153_AU END)
	FROM
		custinfo AS cs WITH (NOLOCK) 
		INNER JOIN custinfo AS ci WITH (NOLOCK) ON (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
	WHERE ci.custid = @recommend

	IF (@MinBet<>0 AND  @MinBet>@MaxBet) or (@MaxBet<> 0 AND @MaxBet>@MaxPerMatch) 
		BEGIN
			SELECT @ErrMsg =	@UserName + ': '+
							CASE @Language 
								WHEN 'E' THEN 'min bet must be less than max bet AND max bet must be less than max bet per match!!!'
								WHEN 'CS' THEN N'最低投注不能高于最高投注，最高投注不能高于单场最高投注设定!!!'
								WHEN 'CT' THEN N'最低投注不能高於最高投注,最高投注不能高於單場最高投注設定!!!'
								WHEN 'TH' THEN N'จำนวนเงินต่ำสุดที่วางเดิมพันได้ต้องน้อยกว่าจำนวนเงินสูงสุดในการวางเดิมพันและจำนวนเงินสูงสุดในการวางเดิมพันต้องน้อยกว่าจำนวนเงินสูงสุดของเงินเดิมพันต่อเกม.'
								WHEN 'J' THEN N'min bet must be less than max bet AND max bet must be less than max bet per match!!!'
								WHEN 'KO' THEN N'최소 배팅은 최대 배팅 이하이여야 하고 최대 배팅은 경기당 최대 배팅보다 작아야 합니다.'
								ELSE N'min bet must be less than max bet AND max bet must be less than max bet per match!!!'
							END						
							+ CHAR(13) + CHAR(10) + CONVERT(VARCHAR(20), @MinBet) + '-' + CONVERT(VARCHAR(20), @MaxBet) + '-' + CONVERT(VARCHAR(20), @MaxPerMatch), @ErrCode = 108				
			RETURN			
		END
		
		IF (@MinMinBet>0 AND @MinBet>0 AND @MinBet<@MinMinBet)
		BEGIN
			SELECT @ErrMsg =	@UserName + ': ' +
							CASE @Language 
								WHEN 'E' THEN 'min bet must be equal to or greater than Agent min bet'
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
			SELECT @ErrMsg =	@UserName + ': '+
							CASE @Language 
								WHEN 'E' THEN 'max bet must be equal to or less than Agent max bet'
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
			SELECT @ErrMsg =	@UserName + ': '+
							CASE @Language 
								WHEN 'E' THEN 'Max Per Match must be equal to or less than Agent Max Per Match'
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
WHERE custid = @custid AND sporttype = 153 AND bettype = 51

SELECT @maxpermatch_old = maxpermatch153_AU FROM custinfo WITH(NOLOCK) WHERE custid = @custid

IF @MinBet <> @minbet_old OR @MaxBet <> @maxbet_old
BEGIN
	UPDATE Dep_CustSetting3rd WITH (ROWLOCK, UPDLOCK)
	SET
		MinBet=@MinBet,
		MaxBet=@MaxBet
	WHERE custid=@custid AND sporttype = 153 AND bettype in(51,52)
	IF (@@ERROR <> 0)
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

IF @MaxPerMatch <> @maxpermatch_old
BEGIN
	EXEC dbo.Lrf_CustomerUpdMaxPerMatch153_51
		@custid		= @custid,
		@MaxPerMatch= @MaxPerMatch,
		@Language	= @Language,
		@ErrCode	= @ErrCode OUTPUT,
		@ErrMsg		= @ErrMsg OUTPUT
		IF @ErrCode > 0
		BEGIN
			RETURN
		END
END
	/*319	Acc_CustomerUpdMember_MinMaxBetOpenTote	Update Horse racing Bet Setting for member*/	



	DECLARE @TrackingValue VARCHAR(5000)
	SELECT @TrackingValue ='<Lrf_CustomerUpdMember_MinMaxBet153_51 custid="'+ COALESCE(CAST(@custid AS VARCHAR(50)),SPACE(1)) + '" ' +
	'MinB="'+ COALESCE(CAST(@minbet AS VARCHAR(50)),SPACE(1)) + '" ' +
	'MaxB="'+ COALESCE(CAST(@maxbet AS VARCHAR(50)),SPACE(1)) + '" ' +
	'MPM="'+ COALESCE(CAST(@maxpermatch AS VARCHAR(50)),SPACE(1)) + '" ' +
	'UserID="'+ COALESCE(CAST(@UserID AS VARCHAR(50)),SPACE(1)) + '" ' +
	'Language="'+ COALESCE(CAST(@Language AS VARCHAR(2)),SPACE(1)) + '" ' +
	'IP="'+ COALESCE(CAST(@IP AS VARCHAR(40)),SPACE(1)) + '" ' +
	'ErrCode="'+ COALESCE(CAST(@ErrCode AS VARCHAR(50)),SPACE(1)) + '" ' +
	'ErrMsg="'+ COALESCE(CAST(@ErrMsg AS VARCHAR(5000)),SPACE(1)) + '" />'
	
	DECLARE @TrackingValue2 VARCHAR(5000)
	SELECT @TrackingValue2 ='<Lrf_CustomerUpdMember_MinMaxBet153_51 custid="'+ COALESCE(CAST(@custid AS VARCHAR(50)),SPACE(1)) + '" ' +
	'MinB="'+ COALESCE(CAST(@minbet_old AS VARCHAR(50)),SPACE(1)) + '" ' +
	'MaxB="'+ COALESCE(CAST(@maxbet_old AS VARCHAR(50)),SPACE(1)) + '" ' +
	'MPM="'+ COALESCE(CAST(@maxpermatch_old AS VARCHAR(50)),SPACE(1)) + '" ' +
	'UserID="'+ COALESCE(CAST(@UserID AS VARCHAR(50)),SPACE(1)) + '" ' +
	'Language="'+ COALESCE(CAST(@Language AS VARCHAR(2)),SPACE(1)) + '" ' +
	'IP="'+ COALESCE(CAST(@IP AS VARCHAR(40)),SPACE(1)) + '" ' +
	'ErrCode="'+ COALESCE(CAST(@ErrCode AS VARCHAR(50)),SPACE(1)) + '" ' +
	'ErrMsg="'+ COALESCE(CAST(@ErrMsg AS VARCHAR(5000)),SPACE(1)) + '" />'

	SET @endRun = GETDATE()
	SET @duration  = datediff (millisecond,@startRun,@endRun)

	EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
		@UserID = @UserID,
		@CustID = @CustID,
		@ActionID = 2006,
		@TrackingValue = @TrackingValue	,
		@TrackingValue2 = @TrackingValue2,
		@duration = @duration 
END




GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerUpdMember_MinMaxBet153_51] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerUpdMember_MinMaxBet153_51] TO [vnteam]
 