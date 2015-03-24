
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO
 
 
CREATE  PROCEDURE [dbo].[Lrf_CustomerUpdUgroup]
	@CustID INT,
	@UserID INT,
	@OddsGroup VARCHAR(3),
	@IP VARCHAR(50),
	@Langkey VARCHAR(10) = 'en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg nvarchar(4000) = '' OUTPUT
AS

/*
Created: 20150120@Jim
Task : Update OddsGroup for member
DB: DBTXN/CustDB

Revisions:
	- 20150211@Jim: check isBA condition
Param's Explanation:
	--@ErrCode = 100: Wrong odds group,please have a check'
	--@ErrCode = 101: Could not update odds group for this member 

*/

DECLARE @startRun DATETIME
DECLARE @endRun DATETIME
DECLARE @duration INT, @OldUgroup VARCHAR(3)
DECLARE @LogSPData VARCHAR(5000)
DECLARE @LogSPData2 VARCHAR(5000)

SET @startRun = GETDATE()
SET @OddsGroup = LOWER(@OddsGroup)

SELECT @OldUgroup = ugroup 
FROM dbo.Customer WITH  (NOLOCK)
WHERE CustID = @CustID

IF @OldUgroup = @OddsGroup
BEGIN
	SELECT @ErrMsg = 'Wrong odds group,please have a check'
					 , @ErrCode = 100
	RETURN				 
END
ELSE IF EXISTS (SELECT 1 FROM DBLIC.bodb_licensee.dbo.LicenseeBAHistory WITH (NOLOCK) WHERE CustID = @CustID AND Status = 'Running')
	  BEGIN 
			SELECT @ErrMsg = 'This is BA member, please check again'
					 , @ErrCode = 102
					RETURN	
	  END
ELSE
BEGIN
	IF LEFT (@OldUgroup,2) = 'hk'
	SET @OddsGroup ='hk'+ @OddsGroup 
	
	UPDATE dbo.Customer WITH(ROWLOCK, UPDLOCK)
	SET ugroup  = @OddsGroup
	WHERE custid = @custid 
	
	IF (@@ERROR <> 0)
	BEGIN
		SELECT @ErrMsg ='Could not update odds group for this member !'
			, @ErrCode = 101
	END
	
	
	SELECT @LogSPData = '<Lrf_CustomerUpdUgroup CustID="'+ COALESCE(CAST(@CustID as VARCHAR(50)),SPACE(1)) + '" ' +
	'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
	'Language="'+ COALESCE(CAST(@Langkey as VARCHAR(10)),SPACE(1)) + '" ' +
	'OddGroup="'+ COALESCE(CAST(@OddsGroup as VARCHAR(40)),SPACE(1)) + '" ' +
	'IP="'+ COALESCE(CAST(@IP as VARCHAR(50)),SPACE(1)) + '" ' +
	'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
	'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(5000)),SPACE(1))+ '" />'

	SELECT @LogSPData2 = '<Lrf_CustomerUpdUgroup  CustID="'+ COALESCE(CAST(@CustID as VARCHAR(50)),SPACE(1)) + '" ' +
	'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
	'Language="'+ COALESCE(CAST(@Langkey as VARCHAR(10)),SPACE(1)) + '" ' +
	'OddGroup="'+ COALESCE(CAST(@OldUgroup as VARCHAR(40)),SPACE(1)) + '" ' +
	'IP="'+ COALESCE(CAST(@IP as VARCHAR(50)),SPACE(1)) + '" ' +
	'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
	'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(5000)),SPACE(1))+ '" />'
 

	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF (millisecond,@startRun,@endRun)
	 
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
			@UserID = @UserID,
			@CustID = @CustID,
			@ActionID = 2417,
			@TrackingValue = @LogSPData,
			@TrackingValue2 = @LogSPData2,
			@duration = @duration
	END TRY
	BEGIN CATCH
		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
			@UserID = @UserID,
			@CustID = @CustID,
			@ActionID = 2417,
			@TrackingValue = @LogSPData,
			@TrackingValue2 = @LogSPData2,
			@duration = @duration
	END CATCH				
	
END

GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerUpdUgroup] TO [vnteam]
GO 
 GRANT EXECUTE ON [dbo].[Lrf_CustomerUpdUgroup] TO [bodbLicenseeNet]
GO 
