ALTER PROCEDURE [dbo].[Lrf_CustomerUpdClosed]
	@LicenseeID INT,	
	@Custid INT,--memberid  
	@Closed BIT,	
	@UserID INT,
	@Language VARCHAR(10) = 'en-us',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT,
	@IP VARCHAR(40)=''
AS
/*
Created: 20110808@Henry
Task : UPDATE status 'closed' for customer
DB: DBTXN/bodb02
Original:

Revisions:
   20130123@Daniel: Change link server alias & failover writelog to DBTXN
   20151023@Victor: Support New Simplified Chinese
	
Param's Explanation:
• @custid: custid that need to be viewed.   

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
 if (@status = 0) RETURN  

--Check disable user  
EXEC DBLIC.bodb02.dbo.Lrf_CustomerSelCheckEnable @custid = @custid, @ErrCode=@ErrCode_Cur OUTPUT,@ErrMsg=@ErrMsg_Cur OUTPUT  
IF @ErrCode_Cur > 0  
BEGIN  
 SELECT @ErrCode = @ErrCode + CAST(@ErrCode_cur as VARCHAR(300)) + char(7),   
   @ErrMsg = @ErrMsg + @ErrMsg_Cur + char(7)  
 RETURN  
END  
--END  

DECLARE @roleid INT, @Old_Closed BIT, @UplineClosed BIT, @recommend INT 


SELECT @Old_Closed = closed,
	@recommend = recommend,
	@roleid = roleid
FROM custinfo WITH (nolock)
WHERE custid = @custid

IF @Old_Closed = @Closed 
	RETURN

SELECT @roleid = ISNULL(@roleid, 0)

if @roleid <> 1
BEGIN
	SELECT @ErrMsg = CASE @Language 
						WHEN 'en-us' THEN 'Invalid user!!'
						WHEN 'zh-cn' THEN N'账号无效.'
						WHEN 'zh-tw' THEN N'帳號無效.'
						WHEN 'zh-Hans' THEN N'账号无效.'
						WHEN 'TH' THEN N'ผู้ใช้ไม่ถูกต้อง!!'
						WHEN 'Ja' THEN 'Invalid user!!'
						WHEN 'KO' THEN N'잘못된 사용자 입니다!!'
						ELSE 'Invalid user!!'
					END	,
		@ErrCode = 100	
	return
END


SELECT @UplineClosed = isnull(closed,0)
FROM Custinfo WITH (nolock) WHERE custid = @recommend 

	
IF @UplineClosed = 1 AND @Old_Closed <> @Closed
BEGIN
	SELECT @ErrMsg =  CASE @Language 
							WHEN 'en-us' THEN 'This user''s upline was closed. Cannot edit.'
							WHEN 'zh-cn' THEN N'This user''s upline was closed. Cannot edit.'
							WHEN 'zh-tw' THEN N'This user''s upline was closed. Cannot edit.'
							WHEN 'zh-Hans' THEN N'This user''s upline was closed. Cannot edit.'
							WHEN 'TH' THEN N'This user''s upline was closed. Cannot edit.'
							WHEN 'Ja' THEN N'This user''s upline was closed. Cannot edit.'
							WHEN 'KO' THEN N'This user''s upline was closed. Cannot edit.'
							ELSE N'This user''s upline was closed. Cannot edit.'
						END, @ErrCode = 105
	return
END



UPDATE custinfo WITH (ROWLOCK, UPDLOCK) SET Closed = @Closed
WHERE custid = @custid



if (@@error <> 0)
begin
	SELECT @ErrMsg =
					CASE @Language 
						WHEN 'en-us' THEN 'Update process is unsuccessful !'
						WHEN 'zh-cn' THEN N'更新程序不成功 !'
						WHEN 'zh-tw' THEN N'更新程序不成功 !'
						WHEN 'zh-Hans' THEN N'更新程序不成功 !'
						WHEN 'TH' THEN N'ขั้นตอนหรือกระบวนการในการปรับยอดไม่เสร็จสิ้น!!'
						WHEN 'Ja' THEN N'アップデート出来ません。'
						WHEN 'KO' THEN N'업데이트에 실패했습니다.'
						ELSE N'Update process is unsuccessful !'
					END	, @ErrCode = 101
	return
END

DECLARE @TrackingValue1 VARCHAR(2000)
DECLARE @TrackingValue2 VARCHAR(2000)

SELECT @TrackingValue1 = '<Lrf_CustomerUpdClosed CustID="'+ COALESCE(CAST(@CustID AS VARCHAR(50)),SPACE(1)) + '" ' +
					'Closed="'+ COALESCE(CAST(@Closed AS VARCHAR(50)),SPACE(1)) + '" ' +
					'UserID="'+ COALESCE(CAST(@UserID AS VARCHAR(50)),SPACE(1)) + '" ' +
					'Language="'+ COALESCE(CAST(@Language AS VARCHAR(10)),SPACE(1))+'" ' +
					'ErrCode="'+ COALESCE(CAST(@ErrCode AS VARCHAR(50)),SPACE(1)) + '" ' +
					'ErrMsg="'+ COALESCE(CAST(@ErrMsg AS VARCHAR(400)),SPACE(1))+'" ' +
					'IP="'+ COALESCE(CAST(@IP AS VARCHAR(40)),SPACE(1))+'" />'
					
SELECT @TrackingValue2 = '<Lrf_CustomerUpdClosed CustID="'+ COALESCE(CAST(@CustID AS VARCHAR(50)),SPACE(1)) + '" ' +
					'Closed="'+ COALESCE(CAST(@Old_Closed AS VARCHAR(50)),SPACE(1)) + '" ' +
					'UserID="'+ COALESCE(CAST(@UserID AS VARCHAR(50)),SPACE(1)) + '" ' +
					'Language="'+ COALESCE(CAST(@Language AS VARCHAR(10)),SPACE(1))+'" ' +
					'ErrCode="'+ COALESCE(CAST(@ErrCode AS VARCHAR(50)),SPACE(1)) + '" ' +
					'ErrMsg="'+ COALESCE(CAST(@ErrMsg AS VARCHAR(400)),SPACE(1))+'" ' +
					'IP="'+ COALESCE(CAST(@IP AS VARCHAR(40)),SPACE(1))+'" />'					

/* 1105	Acc_CustomerUpdClosed	UPDATE Closed status  */

SET @endRun = GETDATE()
SET @duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)

BEGIN TRY
    EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
	    @UserID = @UserID,
	    @CustID = @CustID,
	    @ActionID = 2200,
	    @TrackingValue = @TrackingValue1,
	    @TrackingValue2 = @TrackingValue2,
	    @duration = @duration
END TRY
BEGIN CATCH
    EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
	    @UserID = @UserID,
	    @CustID = @CustID,
	    @ActionID = 2200,
	    @TrackingValue = @TrackingValue1,
	    @TrackingValue2 = @TrackingValue2,
	    @duration = @duration
END CATCH

GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerUpdClosed] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerUpdClosed] TO [vnteam] AS [dbo]