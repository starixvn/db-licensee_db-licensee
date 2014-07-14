USE [CustDB]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[Lrf_CustomerUpdMember_MinMaxBetKN]
	@UserID INT =0,
	@Custid INT,
	@DataXML VARCHAR(max),
	@language VARCHAR(10) = 'en-US',
	@IP VARCHAR(40)='',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg nvarchar(4000) = '' OUTPUT
AS 
/*
Created: 20140326@Jim
Task : Edit bet settings of super
DB: DBTXN.CustDB
Original :

Revisions:
		- 20140605@Jim: use table DBAGE.bodb02.dbo.gametype_tmp instead of bodb02.dbo.Gametype for testing on UAT env
		- 20140606@Jim: exclude bettype 1511,1513 in temporarity 
		- 20140606@Jim: fix bug wrong when get value for parameter  @minbet_old
		- 20140714@Jim: support to active bettype 	1511,1513 (Kentucky,Michigan : #redmineID :17215)
Param's Explanation:
@dataXML Format :
	 '<settings>
	  <setting GameTypeID=''10'' minbet=''1'' maxbet=''2'' maxpermatch=''7'' > 
	 </setting>
	 <setting GameTypeID=''11'' minbet=''2'' maxbet=''3'' maxpermatch=''8'' > 
	 </setting>
	 </settings>'
	
*/

SET NOCOUNT ON

DECLARE @startRun   	  DATETIME,
		@endRun     	  DATETIME,
		@duration   	  INT,
		@iDoc 			  INT,
		@MinBet 		  MONEY,
		@maxbet 		  MONEY,
		@maxpermatch 	  MONEY,
		@minminbet 		  MONEY,
		@maxmaxbet 		  MONEY,
		@maxmaxpermatch   MONEY,
		@minbet_old 	  MONEY,
		@maxbet_old       MONEY,
		@maxpermatch_old  MONEY,
		@userName 		  VARCHAR(30),
		@recommend 		  INT,	
		@i 				  INT,
		@maxID			  INT,
		@GameTypeID		  INT,
		@GametypeName	  NVARCHAR(100)	 	
	 	
CREATE TABLE #Setting (ID INT IDENTITY(1,1),GameTypeID INT,minbet MONEY,maxbet MONEY,maxpermatch MONEY)		
EXEC sp_xml_preparedocument @iDoc OUTPUT,@dataXML
INSERT INTO #Setting (GameTypeID,minbet,maxbet,maxpermatch)
SELECT GameTypeID,minbet,maxbet,maxpermatch
FROM 
	OPENXML(@iDoc,'/settings/setting',0)
	WITH (GameTypeID INT,minbet MONEY,maxbet MONEY , maxpermatch MONEY )
EXEC sp_xml_removedocument @iDoc	

SELECT @userName = username
	  ,@recommend = recommend
FROM customer with (NOLOCK)
WHERE roleid = 1 AND CustID = @CustID


IF (@username = NULL) RETURN

IF EXISTS ( SELECT 1 FROM #Setting
			WHERE	
			(MinBet<0
			or MaxBet < 0
			or MaxPerMatch <0		
			)
		)	
	BEGIN
		SELECT @ErrCode = 2
		SELECT @ErrMsg = 	CASE @Language 
							WHEN 'en-us' THEN 'Wrong Min bet/ Max bet/ Max per match .'
							WHEN 'zh-cn' THEN N'最低投注/最高投注/单场最高投注不正确.'
							WHEN 'zh-tw' THEN N'最低投注/最高投注/單場最高投注不正確.'
							WHEN 'th-TH' THEN N'การกำหนดจำนวนเงินสำหรับการวางเดิมพันต่ำสุด/ สูงสุด/สูงสดต่อรายการไม่ถูกต้อง .'
							WHEN 'ja-JP' THEN N'Wrong Min bet/ Max bet/ Max per match.'
							WHEN 'ko-KR' THEN N'잘못된 최소 배팅/최대 배팅/경기당 최대 .'
							ELSE N'Wrong Min bet/ Max bet/ Max per match .'
					END
		RETURN
	END
/*
DELETE #Setting -- for temporarity (waiting confirmation from 12bet)
WHERE GameTypeID IN (11,13)
*/
SELECT @i=MIN(ID)
	   ,@maxID=MAX(ID)		
FROM   #Setting

WHILE (@i<=@maxID)
BEGIN 

	SELECT @minbet=ISNULL(minbet,0)
		  ,@maxbet=ISNULL(maxbet,0)
		  ,@maxpermatch=ISNULL(maxpermatch,0)
		  ,@GameTypeID=GameTypeID
	FROM  #Setting
	WHERE ID=@i

	SELECT @GametypeName=GametypeName
	---FROM DBAGE.bodb02.dbo.gametype_tmp WITH (NOLOCK) -- for UAT  env
	FROM bodb02.dbo.GameType WITH (NOLOCK)        -- for Prod env
	WHERE GameTypeID=@GameTypeID

	SELECT
			@MinMinBet = Max(CASE WHEN MinBet = 0 THEN 0 ELSE MinBet END), 
			@MaxMaxBet = Min(CASE WHEN MaxBet = 0 THEN 0 ELSE MaxBet END)
	FROM CustGameType cg WITH (NOLOCK)
		--INNER JOIN DBAGE.bodb02.dbo.gametype_tmp gt WITH (NOLOCK) ON cg.GameTypeID = gt.GameTypeID  -- for UAT  env
		INNER JOIN bodb02.dbo.GameType gt WITH (NOLOCK) ON cg.GameTypeID = gt.GameTypeID         -- for Prod env
		INNER JOIN custinfo AS ci WITH (NOLOCK) ON (cg.custid = ci.recommend OR cg.custid = ci.mrecommend OR cg.custid = ci.srecommend)
	WHERE ci.custid = @recommend  
		AND cg.GameTypeID=@GameTypeID
		
	SELECT @maxmaxpermatch= MIN(CASE WHEN MaxPerGameType = 0 THEN 0 ELSE cg.MaxPerGameType END)
	FROM 
		CustGameType AS cg WITH (NOLOCK)
		INNER JOIN custinfo AS ci WITH (NOLOCK) ON  (cg.custid = ci.recommend OR cg.custid = ci.mrecommend OR cg.custid = ci.srecommend)
		--INNER JOIN DBAGE.bodb02.dbo.gametype_tmp gt WITH (NOLOCK) ON cg.GameTypeID = gt.GameTypeID   -- for UAT  env
		INNER JOIN bodb02.dbo.GameType gt WITH (NOLOCK) ON cg.GameTypeID = gt.GameTypeID           -- for Prod env
	WHERE ci.custid = @recommend 
		AND cg.GameTypeID=@GameTypeID

	IF (@MinBet<>0 AND  @MinBet>@MaxBet) or (@MaxBet<> 0 AND @MaxBet>@MaxPerMatch) 
		BEGIN
			DELETE  #Setting WHERE ID=@i
			
			SELECT @ErrMsg =	@UserName + ': '+
							CASE @Language 
								WHEN 'en-us' THEN 'min bet must be less than max bet AND max bet must be less than max bet per match'
								WHEN 'zh-cn' THEN N'最低投注不能高于最高投注，最高投注不能高于单场最高投注设定'
								WHEN 'zh-tw' THEN N'最低投注不能高於最高投注,最高投注不能高於單場最高投注設定'
								WHEN 'th-TH' THEN N'จำนวนเงินต่ำสุดที่วางเดิมพันได้ต้องน้อยกว่าจำนวนเงินสูงสุดในการวางเดิมพันและจำนวนเงินสูงสุดในการวางเดิมพันต้องน้อยกว่าจำนวนเงินสูงสุดของเงินเดิมพันต่อเกม.'
								WHEN 'ja-JP' THEN N'min bet must be less than max bet AND max bet must be less than max bet per match'
								WHEN 'ko-KR' THEN N'최소 배팅은 최대 배팅 이하이여야 하고 최대 배팅은 경기당 최대 배팅보다 작아야 합니다.'
								ELSE N'min bet must be less than max bet AND max bet must be less than max bet per match'
							END						
							+ char(13) + char(10) + convert(VARCHAR(20), @MinBet) + '-' + convert(VARCHAR(20), @MaxBet) + '-' + convert(VARCHAR(20), @MaxPerMatch), @ErrCode = 108
				
			RETURN
			
		END
		
	IF (@MinMinBet>0 AND @MinBet>0 AND @MinBet<@MinMinBet)
	BEGIN
		DELETE  #Setting WHERE ID=@i
		
		SELECT @ErrMsg =	@GametypeName + ': ' +
						CASE @Language 
							WHEN 'en-us' THEN 'max bet must be equal to or less than Agent max bet'
							WHEN 'zh-cn' THEN N'最高投注需相等于或少于代理最高投注'
							WHEN 'zh-tw' THEN N'最高投注需相等於或少於代理最高投注'
							WHEN 'th-TH' THEN N'จำนวนการวางเดิมพันสูงสุดต้องเท่ากับ หรือ น้อยกว่าราคาเดิมพันสูงสุดของตัวแทน '
							WHEN 'ja-JP' THEN N'max bet must be equal to or less than Agent max bet'
							WHEN 'ko-KR' THEN N'최대 배팅은 에이전트의 최대 배팅 이하이여야 합니다.'
							ELSE N'max bet must be equal to or less than Agent max bet'
						END						
						+' (' + CONVERT(VARCHAR(20), @MinMinBet) + ').', @ErrCode = 109
				
		RETURN
	END

	IF (@MaxMaxBet>0 AND @MaxBet>0 AND @MaxBet>@MaxMaxBet)
		BEGIN
			DELETE  #Setting WHERE ID=@i
			
			SELECT @ErrMsg = @GametypeName+ ': '+
							CASE @Language 
								WHEN 'en-us' THEN 'The Max Bet must be equal to or less than the value '
								WHEN 'zh-cn' THEN N'最高投注需相等于或少于代理最高投注'
								WHEN 'zh-tw' THEN N'最高投注需相等於或少於代理最高投注'
								WHEN 'th-TH' THEN N'จำนวนการวางเดิมพันสูงสุดต้องเท่ากับ หรือ น้อยกว่าราคาเดิมพันสูงสุดของตัวแทน '
								WHEN 'ja-JP' THEN N'max bet must be equal to or less than Agent max bet'
								WHEN 'ko-KR' THEN N'최대 배팅은 에이전트의 최대 배팅 이하이여야 합니다'
								ELSE N'max bet must be equal to or less than Agent max bet'
							END						
							+'(' + CONVERT(VARCHAR(20), @MaxMaxBet) + ').', @ErrCode = 110
					
			RETURN
		END
		
	IF (@MaxMaxPerMatch>0 AND @MaxPerMatch>0 AND @MaxPerMatch>@MaxMaxPerMatch)
		BEGIN
			DELETE  #Setting WHERE ID=@i
			
			SELECT @ErrMsg =	@GametypeName + ': '+
							CASE @Language 
								WHEN 'en-us' THEN 'The Max Per Match must be equal to or less than the value '
								WHEN 'zh-cn' THEN N'单场最高投注需相等于或少于代理单场最高投注'
								WHEN 'zh-tw' THEN N'單場最高投注需相等於或少於代理單場最高投注'
								WHEN 'th-TH' THEN N'จำนวนเงินสูงสุดในการเล่นต่อรายการต้องเท่ากับหรือน้อยกว่าจำนวนเงินสูงสุดต่อรายการที่กำหนดไว้ของตัวแทน  '
								WHEN 'ja-JP' THEN N'Max Per Match must be equal to or less than Agent Max Per Match'
								WHEN 'ko-KR' THEN N'최대 경기는 에이전트의 최대 경기보다 작아야 합니다'
								ELSE N'Max Per Match must be equal to or less than Agent Max Per Match'
							END						
							+'(' + CONVERT(VARCHAR(20), @MaxMaxPerMatch) + ').', @ErrCode = 110
					
			RETURN
		END
		
	SELECT @minbet_old =MAX(ISNULL(minbet,0))
		   ,@maxbet_old =MAX(ISNULL(maxbet,0))
		   ,@maxpermatch_old=MAX(ISNULL(MaxPerGameType,0))
	FROM 
		CustGameType AS cg WITH (NOLOCK)
		INNER JOIN custinfo AS ci WITH (NOLOCK)  ON (cg.custid = ci.recommend OR cg.custid = ci.mrecommend OR cg.custid = ci.srecommend)
		--- INNER JOIN DBAGE.bodb02.dbo.gametype_tmp gt WITH (NOLOCK) ON cg.GameTypeID = gt.GameTypeID  -- for UAT  env
		INNER JOIN bodb02.dbo.GameType gt WITH (NOLOCK) ON cg.GameTypeID = gt.GameTypeID		-- for Prod env
	WHERE ci.custid =@Custid 
		AND cg.GameTypeID=@GameTypeID

	IF @MinBet <> @minbet_old OR @MaxBet <> @maxbet_old OR @MaxPerMatch <> @maxpermatch_old
		BEGIN
			UPDATE cg WITH (ROWLOCK, UPDLOCK)
			SET
				MinBet =@MinBet,
				MaxBet =@MaxBet,
				MaxPerGameType =@maxpermatch
			FROM CustGameType cg WITH (ROWLOCK, UPDLOCK)
				INNER JOIN custinfo AS ci WITH (NOLOCK) ON cg.CustID = ci.CustID
				--- INNER JOIN DBAGE.bodb02.dbo.gametype_tmp gt WITH (NOLOCK) ON cg.GameTypeID = gt.GameTypeID  -- for UAT  env
				INNER JOIN bodb02.dbo.GameType gt WITH (NOLOCK) ON cg.GameTypeID = gt.GameTypeID          -- for Prod env   
			WHERE ci.custid =@Custid
				AND cg.GameTypeID=@GameTypeID
				AND cg.IsDisabled=0
			IF (@@error <> 0)
			BEGIN
				SELECT @ErrMsg = @UserName + ': '+
								CASE @Language 
									WHEN 'en-us' THEN 'Update process is unsuccessful !'
									WHEN 'zh-cn' THEN N'更新程序不成功 !'
									WHEN 'zh-tw' THEN N'更新程序不成功 !'
									WHEN 'th-TH' THEN N'ขั้นตอนหรือกระบวนการในการปรับยอดไม่เสร็จสิ้น!'
									WHEN 'ja-JP' THEN N'アップデート出来ません。'
									WHEN 'ko-KR' THEN N'업데이트에 실패했습니다.'
									ELSE N'Update process is unsuccessful !'
								END, @ErrCode = 115
				RETURN
			END
		END

	DECLARE @TrackingValue VARCHAR(5000)
	SELECT @TrackingValue ='<Lrf_CustomerUpdMember_MinMaxBetKN custid="'+ COALESCE(CAST(@custid as VARCHAR(50)),SPACE(1)) + '" ' +
	'GameType="'+ COALESCE(CAST(@GametypeName as VARCHAR(50)),SPACE(1)) + '" ' +
	'MinB="'+ COALESCE(CAST(@minbet as VARCHAR(50)),SPACE(1)) + '" ' +
	'MaxB="'+ COALESCE(CAST(@maxbet as VARCHAR(50)),SPACE(1)) + '" ' +
	'MPM="'+ COALESCE(CAST(@maxpermatch as VARCHAR(50)),SPACE(1)) + '" ' +
	'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
	'Language="'+ COALESCE(CAST(@Language as VARCHAR(2)),SPACE(1)) + '" ' +
	'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
	'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
	'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(5000)),SPACE(1)) + '" />'

	DECLARE @TrackingValue2 VARCHAR(5000)
	SELECT @TrackingValue2 ='<Lrf_CustomerUpdMember_MinMaxBetKN custid="'+ COALESCE(CAST(@custid as VARCHAR(50)),SPACE(1)) + '" ' +
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
		@ActionID = 2038,
		@TrackingValue = @TrackingValue,
		@TrackingValue2 = @TrackingValue2,
		@duration = @duration
	SET @i=@i+1
END	

DROP TABLE #setting

GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerUpdMember_MinMaxBetKN] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerUpdMember_MinMaxBetKN] TO [vnteam]
