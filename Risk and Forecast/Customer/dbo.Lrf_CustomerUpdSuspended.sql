ALTER PROCEDURE [dbo].[Lrf_CustomerUpdSuspended]
	@LicenseeID INT,	
	@Custid INT,--memberid  
	@Suspended BIT,	
	@UserID INT,
	@Language VARCHAR(10) = 'en-us',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT,
	@IP VARCHAR(40)=''
AS
/*
Created: 20110809@Henry
Task : UPDATE suspended
DB: DBCUST/CustDB
Original:

Revisions:
    - 20130123@Daniel: Change link server alias & failover writelog to DBTXN
	- 20151023@Victor: Support New Simplified Chinese

 
Param's Explanation:
• @ErrCode:
    = 0: UPDATE successfully.
    > 0: Specific Error.
  
• @ErrMsg: Error description.
*/

SET NOCOUNT ON

DECLARE @startRun DATETIME
DECLARE @endRun DATETIME
DECLARE @duration INT
SET @startRun = GETDATE()

---------------------------  
-- ***Check Downline Belonging***  
DECLARE @status INT, @ErrCode_Cur INT, @ErrMsg_Cur nvarchar(4000)  
SELECT @ErrCode_Cur = 0, @ErrMsg_Cur = '', @ErrCode = '', @ErrMsg = ''  
  
EXEC DBLIC.bodb02.dbo.Lrf_CustomerSelCheckBelonging   
 @LicenseeID = @LicenseeID,
 @custid = @custid,   
 @status = @status OUTPUT
 IF (@status = 0) RETURN  

--Check disable user  
EXEC DBLIC.bodb02.dbo.Lrf_CustomerSelCheckEnable @custid = @custid, @ErrCode=@ErrCode_Cur OUTPUT,@ErrMsg=@ErrMsg_Cur OUTPUT  
IF @ErrCode_Cur > 0  
BEGIN  
 SELECT @ErrCode = @ErrCode + CAST(@ErrCode_cur AS VARCHAR(300)) + CHAR(7),   
   @ErrMsg = @ErrMsg + @ErrMsg_Cur + CHAR(7)  
 RETURN  
END  
--END  



DECLARE @RoleID INT , @UplineSuspended BIT , @Old_Suspended BIT, @UplineClosed BIT, @recommend INT
SELECT 
	@RoleID = RoleID, 
	@Old_Suspended = ISNULL(reject,0),
	@recommend = recommend
from Custinfo WITH (nolock)
WHERE CustID = @CustID


SELECT @UplineSuspended = ISNULL(reject,0),
	@UplineClosed = ISNULL(closed,0)
from Custinfo WITH (nolock) WHERE custid = @recommend 


IF @UplineSuspended = 1 AND @Old_Suspended <> @Suspended
BEGIN
	SELECT @ErrMsg =  CASE @Language 
						WHEN 'en-us' THEN 'This user''s upline was suspended. Cannot edit.'
						WHEN 'zh-cn' THEN N'此用户的上线暂停，不能编辑。'
						WHEN 'zh-tw' THEN N'此用戶的上線暫停，不能編輯。'
						WHEN 'zh-Hans' THEN N'此用户的上线暂停，不能编辑。'
						WHEN 'TH' THEN N'ยูเซอร์นี้ได้ถูกระงับการใช้งานโดยอัพลายร์. ไม่สามารถแก้ไขได้'
						WHEN 'Ja' THEN N'This user''s upline was suspended. Cannot edit.'
						WHEN 'KO' THEN N'This user''s upline was suspended. Cannot edit.'
						ELSE N'This user''s upline was suspended. Cannot edit.'
					END, @ErrCode = 100
	return
END 
IF @UplineClosed = 1 AND @Old_Suspended <> @Suspended
BEGIN
	SELECT @ErrMsg =  CASE @Language 
							WHEN 'en-us' THEN 'This user''s upline was closed. Cannot edit.'
							WHEN 'zh-cn' THEN N'此用户的上线关闭，不能编辑。'
							WHEN 'zh-tw' THEN N'此用户的上线关闭，不能编辑。'
							WHEN 'zh-Hans' THEN N'此用户的上线关闭，不能编辑。'
							WHEN 'TH' THEN N'ยูเซอร์นี้ได้ถูกปิดการใช้งานโดยอัพลายร์. ไม่สามารถแก้ไขได้'
							WHEN 'Ja' THEN N'This user''s upline was closed. Cannot edit.'
							WHEN 'KO' THEN N'This user''s upline was closed. Cannot edit.'
							ELSE N'This user''s upline was closed. Cannot edit.'
							
						END, @ErrCode = 101
	return
END
SELECT @RoleID = ISNULL(@RoleID, 0)

IF @RoleID <> 1
BEGIN
	SELECT @ErrMsg = CASE @Language 
						WHEN 'en-us' THEN 'Invalid user!!'
						WHEN 'zh-cn' THEN N'账号无效 !'
						WHEN 'zh-tw' THEN N'帳號無效. !'
						WHEN 'zh-Hans' THEN N'账号无效 !'
						WHEN 'TH' THEN N'ผู้ใช้ไม่ถูกต้อง!!'
						WHEN 'Ja' THEN N'Invalid user!!'
						WHEN 'KO' THEN N'잘못된 사용자 입니다!!'
						ELSE N'Invalid user!!'
					END
	
	,
		@ErrCode = 102	
	return
END

IF @Old_Suspended = @Suspended RETURN 
-------------

UPDATE CustInfo WITH (ROWLOCK, UPDLOCK) SET Reject = @Suspended
WHERE CustID = @CustID
IF (@@error <> 0)
BEGIN
	
	SELECT @ErrMsg =
					CASE @Language 
						WHEN 'en-us' THEN 'Update process is unsuccessful !'
						WHEN 'zh-cn' THEN N'更新程序不成功 !'
						WHEN 'zh-tw' THEN N'更新程序不成功 !'
						WHEN 'zh-Hans' THEN N'更新程序不成功 !'
						WHEN 'TH' THEN N'ขั้นตอนหรือกระบวนการในการปรับยอดไม่เสร็จสิ้น'
						WHEN 'Ja' THEN N'アップデート出来ません。'
						WHEN 'KO' THEN N'업데이트에 실패했습니다.'
						ELSE N'Update process is unsuccessful !'
					END	, @ErrCode = 103
	return
END


---------------
DECLARE @TrackingValue1 VARCHAR(2000)
DECLARE @TrackingValue2 VARCHAR(2000)

SELECT @TrackingValue1 = '<Lrf_CustomerUpdSuspended CustID="'+ COALESCE(CAST(@CustID AS VARCHAR(50)),SPACE(1)) + '" '+
					'Suspended="'+ COALESCE(CAST(@Suspended AS VARCHAR(50)),SPACE(1)) + '" '+
					'UserID="'+ COALESCE(CAST(@UserID AS VARCHAR(50)),SPACE(1)) + '" '+
					'Language="'+ COALESCE(CAST(@Language AS VARCHAR(10)),SPACE(1))+'" '+
					'ErrCode="'+ COALESCE(CAST(@ErrCode AS VARCHAR(50)),SPACE(1)) + '" '+
					'ErrMsg="'+ COALESCE(CAST(@ErrMsg AS VARCHAR(400)),SPACE(1))+'" '+
					'IP="'+ COALESCE(CAST(@IP AS VARCHAR(40)),SPACE(1))+'" />'
					
SELECT @TrackingValue2 = '<Lrf_CustomerUpdSuspended CustID="'+ COALESCE(CAST(@CustID AS VARCHAR(50)),SPACE(1)) + '" '+
					'Suspended="'+ COALESCE(CAST(@Old_Suspended AS VARCHAR(50)),SPACE(1)) + '" '+
					'UserID="'+ COALESCE(CAST(@UserID AS VARCHAR(50)),SPACE(1)) + '" '+
					'Language="'+ COALESCE(CAST(@Language AS VARCHAR(10)),SPACE(1))+'" '+
					'ErrCode="'+ COALESCE(CAST(@ErrCode AS VARCHAR(50)),SPACE(1)) + '" '+
					'ErrMsg="'+ COALESCE(CAST(@ErrMsg AS VARCHAR(400)),SPACE(1))+'" '+
					'IP="'+ COALESCE(CAST(@IP AS VARCHAR(40)),SPACE(1))+'" />'					

SET @endRun = GETDATE()
SET @duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)


	
BEGIN TRY
    EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
	    @UserID = @UserID,
	    @CustID = @CustID,
	    @ActionID = 2201,
	    @TrackingValue = @TrackingValue1,
	    @TrackingValue2 = @TrackingValue2,
	    @duration = @duration
END TRY
BEGIN CATCH
    EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
	    @UserID = @UserID,
	    @CustID = @CustID,
	    @ActionID = 2201,
	    @TrackingValue = @TrackingValue1,
	    @TrackingValue2 = @TrackingValue2,
	    @duration = @duration
END CATCH	
	
GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerUpdSuspended] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerUpdSuspended] TO [vnteam] AS [dbo]