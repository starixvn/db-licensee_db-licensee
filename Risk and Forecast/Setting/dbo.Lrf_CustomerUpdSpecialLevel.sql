/*<info serverAlias="DBCUST-CustDB" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CustomerUpdSpecialLevel]
	@CustID INT,
	@UserID INT,
	@SpecialLevel INT,
	@IP VARCHAR(50),
	@Langkey VARCHAR(10) = 'en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg nvarchar(4000) = '' OUTPUT
AS

/*
Created: 20111222@Henry
Task : Update Special Level of member
DB: DBCUST.CustDB


Revisions:
	- 20130413@Jim: support multi language
	- 20180810@Sophia: Change the way to update/insert SpecialLevel, use new table Dep_CustSpecialLevel [redmine: #99464] 
	
Param's Explanation:

*/

DECLARE @startRun DATETIME
DECLARE @endRun DATETIME
DECLARE @duration INT, @OldSpecialLevel INT = 0
DECLARE @LogSPData VARCHAR(5000)
DECLARE @LogSPData2 VARCHAR(5000)

SET @startRun = GETDATE()

IF @SpecialLevel <0 OR @SpecialLevel>10
BEGIN
	SELECT @ErrMsg =
					CASE @Langkey 
						WHEN 'en-US' THEN 'Wrong special level !'
						ELSE [dbo].[Lrf_f_Get_MsgNamebyMsgID](200008,@Langkey)
					END, @ErrCode = 100
END
ELSE
IF (@SpecialLevel >= 1 AND @SpecialLevel <= 10)
BEGIN
	SELECT @OldSpecialLevel=SpecialLevel 
	FROM  dbo.Dep_CustSpecialLevel (NOLOCK)
	WHERE CustID = @CustID
	
	--- Not exists then insert new
	IF ISNULL(@OldSpecialLevel,0) = 0
	BEGIN 	
		INSERT INTO dbo.Dep_CustSpecialLevel (CustID, SpecialLevel)
		VALUES (@CustId, @SpecialLevel)			
	END	
	ELSE
	BEGIN
		UPDATE dbo.Dep_CustSpecialLevel WITH(ROWLOCK)
		SET SpecialLevel = @SpecialLevel 
		WHERE custid = @custid 
		
		IF (@@ERROR <> 0)
		BEGIN
			SELECT @ErrMsg =
				CASE @Langkey 
					WHEN 'en-US' THEN 'Could not update special level for this member !'
					ELSE [dbo].[Lrf_f_Get_MsgNamebyMsgID](200010,@Langkey)
				END, @ErrCode = 100
		END
	END
	
END
ELSE 
IF @SpecialLevel = 0
BEGIN 
	SELECT @OldSpecialLevel=SpecialLevel 
	FROM dbo.Dep_CustSpecialLevel WITH (NOLOCK)
	WHERE CustID = @CustID
	
	--- Not exists then insert new
	IF ISNULL(@OldSpecialLevel,0) <> 0
	BEGIN
		DELETE dbo.Dep_CustSpecialLevel WITH(ROWLOCK)		
		WHERE custid = @custid 
		
		IF (@@ERROR <> 0)
		BEGIN
			SELECT @ErrMsg =
				CASE @Langkey 
					WHEN 'en-US' THEN 'Could not update special level for this member !'
					ELSE [dbo].[Lrf_f_Get_MsgNamebyMsgID](200010,@Langkey)
				END, @ErrCode = 100
		END
	END
END


	
	
SELECT @LogSPData = '<Lrf_CustomerUpdSpecialLevel CustID="'+ COALESCE(CAST(@CustID as VARCHAR(50)),SPACE(1)) + '" ' +
'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
'Language="'+ COALESCE(CAST(@Langkey as VARCHAR(10)),SPACE(1)) + '" ' +
'SpecialLevel="'+ COALESCE(CAST(@SpecialLevel as VARCHAR(40)),SPACE(1)) + '" ' +
'IP="'+ COALESCE(CAST(@IP as VARCHAR(50)),SPACE(1)) + '" ' +
'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(5000)),SPACE(1))+ '" />'

SELECT @LogSPData2 = '<Lrf_CustomerUpdSpecialLevel CustID="'+ COALESCE(CAST(@CustID as VARCHAR(50)),SPACE(1)) + '" ' +
'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
'Language="'+ COALESCE(CAST(@Langkey as VARCHAR(10)),SPACE(1)) + '" ' +
'SpecialLevel="'+ COALESCE(CAST(@OldSpecialLevel as VARCHAR(40)),SPACE(1)) + '" ' +
'IP="'+ COALESCE(CAST(@IP as VARCHAR(50)),SPACE(1)) + '" ' +
'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(5000)),SPACE(1))+ '" />'


SET @endRun = GETDATE()
SET @duration  = datediff (millisecond,@startRun,@endRun)

EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
		@UserID = @UserID,
		@CustID = @CustID,
		@ActionID = 2407,
		@TrackingValue = @LogSPData,
		@TrackingValue2 = @LogSPData2,
		@duration = @duration


GO 