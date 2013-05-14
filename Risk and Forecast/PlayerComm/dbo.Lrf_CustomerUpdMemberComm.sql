set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go


ALTER PROCEDURE [dbo].[Lrf_CustomerUpdMemberComm]
	@LicenseeID INT,
	@strCustID VARCHAR(MAX),--member
	@UserID INT,
	@GroupCommID INT = 0,
	@SBComm DECIMAL(9,8)=0 ,
	@NGComm DECIMAL(9,8)=0,	
	@RacingComm DECIMAL(9,8)=0,
	@IsUpdateComm BIT=1,
	@IsUpdateNG BIT = 0,
	@IsUpdateRacing BIT = 0,
	@IP VARCHAR(40),
	@Langkey VARCHAR(10) = 'en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg varchar(8000) = '' OUTPUT
AS

/*
Created: 20120726@Henry
Task : Update Commission of Player
DB: DBLIC/bodb_licensee

Revisions:
    - 20130124@Daniel: Change link server alias & failover writelog to DBTXN 
	- 20130413@Jim: support multi language
Param's Explanation:

1. To update a member/batch members without GroupCommID
EXEC [Lrf_CustomerUpdMemberComm_907] @LicenseeID=xx,@strCustID,xx,@UserID=xx,@SBComm=xx,@NGComm=xx,@RacingComm=xx,@IsUpdateNG=xx,@IsUpdateRacing=xx,@IP=xx,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
2. To update a member/batch members with GroupCommID
EXEC [Lrf_CustomerUpdMemberComm_907] @LicenseeID=xx,@strCustID,xx,@UserID=xx,@GroupCommID=xx,@SBComm=xx,@NGComm=xx,@RacingComm=xx,@IsUpdateNG=xx,@IsUpdateRacing=xx,@IP=xx,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
3. To update member group without update commission
EXEC [Lrf_CustomerUpdMemberComm_907] @IsUpdateComm=0,@LicenseeID=xx,@strCustID,xx,@UserID=xx,@GroupCommID=xx,@SBComm=xx,@NGComm=xx,@RacingComm=xx,@IsUpdateNG=xx,@IsUpdateRacing=xx,@IP=xx,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT

*/

DECLARE @startRun DATETIME
DECLARE @endRun DATETIME
DECLARE @duration INT
SET @startRun = GETDATE()

DECLARE @SBComm_Old DECIMAL(9,8) , @RacingComm_Old DECIMAL(9,8) ,@NGComm_Old DECIMAL(9,8),@CustID INT, @GroupCommID_Old INT
DECLARE @TotalMemCount INT

DECLARE @LogSPData VARCHAR(MAX)
DECLARE @TrackingValue2 VARCHAR(MAX)
DECLARE @i	 AS INT

SELECT @strCustID = ltrim(rtrim(@strCustID))

IF @strCustID = ''
BEGIN
	SELECT @ErrMsg = CASE @Langkey WHEN 'en-US'THEN 'Wrong input, please check again!'
			ELSE  [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200003,@Langkey)
			END 	
	RETURN
END

IF @GroupCommID>0 --Get SBComm,NGComm,RacingComm From Group
BEGIN
	--Check existence
	IF NOT EXISTS (SELECT 1 FROM LicenseeGroupComm WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND id = @GroupCommID AND IsActive=1)
	BEGIN
		SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'The Group Commission does not exist, please check again!'
									   ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200001,@Langkey)		
									   END
		RETURN
	END
	
	SELECT @SBComm=SBComm,@NGComm=NGComm, @RacingComm=RacingComm
	FROM LicenseeGroupComm WITH (NOLOCK)
	WHERE LicenseeID = @LicenseeID AND id = @GroupCommID AND IsActive=1
END

SELECT @SBComm=ISNULL(@SBComm,0), @NGComm=ISNULL(@NGComm,0),@RacingComm=ISNULL(@RacingComm,0)

--Validate data
IF @SBComm>0.15 OR @RacingComm>0.15 OR @NGComm>0.15
BEGIN
	SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN 'Player commission should not be greater than'
												ELSE 	[bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200002,@Langkey)
												END +'0.15'
	RETURN
END

DECLARE @TempCustID  AS TABLE (ID int IDENTITY(1,1),CustID INT)
INSERT INTO @TempCustID (CustID)
SELECT c.CustID 
FROM dbo.LicenseeCustInfo c WITH (NOLOCK) 
WHERE 
	c.CustID IN (SELECT RTRIM(LTRIM(VAL)) FROM strSplit(@strCustID,','))
	

SELECT @TotalMemCount=@@ROWCOUNT

--Call execrep to update player commission
IF @IsUpdateComm=1
BEGIN
	IF @TotalMemCount=1
				EXEC DBTXN.bodb02.dbo.[Lrf_CustomerUpdMemberComm_Direct] @CustID=@strCustID,@SBComm=@SBComm,@NGComm=@NGComm,@RacingComm=@RacingComm,@IsUpdateNG=@IsUpdateNG,@IsUpdateRacing=@IsUpdateRacing
	ELSE	
		EXEC DBTXN.bodb02.dbo.[Lrf_CustomerUpdMemberComm_Main] @strCustID=@strCustID,@SBComm=@SBComm,@NGComm=@NGComm,@RacingComm=@RacingComm,@IsUpdateNG=@IsUpdateNG,@IsUpdateRacing=@IsUpdateRacing
END	
		
SET @endRun = GETDATE()
SET @duration  = datediff (millisecond,@startRun,@endRun)		
			
--Write Log
SELECT @i = 1
WHILE (@i<=(SELECT MAX(ID) FROM @TempCustID))
BEGIN
	SELECT @CustID = CustID FROM @TempCustID WHERE ID=@i
	
	--Get old setting
	SELECT @SBComm_Old=SBComm,@NGComm_Old=NGComm,@RacingComm_Old=RacingComm,@GroupCommID_Old=GroupCommID
	FROM LicenseeCustComm WITH (NOLOCK)
	WHERE LicenseeID = @LicenseeID AND CustID = @CustID
	
	
	SELECT @SBComm_Old=ISNULL(@SBComm_Old,0),@NGComm_Old=ISNULL(@NGComm_Old,0),@RacingComm_Old=ISNULL(@RacingComm_Old,0),@GroupCommID_Old=ISNULL(@GroupCommID_Old,0)
	
	SELECT @LogSPData = '<Lrf_CustomerUpdMemberComm custid="'+ COALESCE(CAST(@custid as VARCHAR(50)),SPACE(1)) + '" ' +
	'GroupCommID="'+ COALESCE(CAST(@GroupCommID as VARCHAR(50)),SPACE(1)) + '" ' +
	'LicenseeID="'+ COALESCE(CAST(@LicenseeID as VARCHAR(50)),SPACE(1)) + '" ' +
	'SBComm="'+ COALESCE(CAST(@SBComm as VARCHAR(50)),SPACE(1)) + '" ' +
	'NGComm="'+ COALESCE(CAST(@NGComm as VARCHAR(50)),SPACE(1)) + '" ' +
	'RacingComm="'+ COALESCE(CAST(@RacingComm as VARCHAR(50)),SPACE(1)) + '" ' +
	'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
	'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
	'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
	'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'

	SELECT @TrackingValue2 = '<Lrf_CustomerUpdMemberComm custid="'+ COALESCE(CAST(@custid as VARCHAR(50)),SPACE(1)) + '" ' +
	'GroupCommID="'+ COALESCE(CAST(@GroupCommID_Old as VARCHAR(50)),SPACE(1)) + '" ' +
	'LicenseeID="'+ COALESCE(CAST(@LicenseeID as VARCHAR(50)),SPACE(1)) + '" ' +
	'SBComm="'+ COALESCE(CAST(@SBComm_Old as VARCHAR(50)),SPACE(1)) + '" ' +
	'NGComm="'+ COALESCE(CAST(@NGComm_Old as VARCHAR(50)),SPACE(1)) + '" ' +
	'RacingComm="'+ COALESCE(CAST(@RacingComm_Old as VARCHAR(50)),SPACE(1)) + '" ' +
	'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
	'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
	'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
	'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'


	
    BEGIN TRY
	    EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
				    @UserID = @UserID,
				    @CustID = @CustID,
				    @ActionID = 2612,
				    @TrackingValue = @LogSPData,
				    @TrackingValue2 = @TrackingValue2,
				    @duration = @duration
    END TRY
    BEGIN CATCH
	    EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
				    @UserID = @UserID,
				    @CustID = @CustID,
				    @ActionID = 2612,
				    @TrackingValue = @LogSPData,
				    @TrackingValue2 = @TrackingValue2,
				    @duration = @duration
    END CATCH	

	--Update LicenseeCustComm
	IF NOT EXISTS(SELECT 1 FROM LicenseeCustComm WITH (ROWLOCK,UPDLOCK) WHERE CustID=@CustID AND LicenseeID = @LicenseeID )
	BEGIN
		--Sportbook
		INSERT INTO LicenseeCustComm (LicenseeID,CustID,SBComm,GroupCommID)
		VALUES (@LicenseeID,@CustID,@SBComm,@GroupCommID)
		
		--NG
		IF @IsUpdateNG=1 
		BEGIN
			Update LicenseeCustComm WITH (ROWLOCK,UPDLOCK)
				SET NGComm=@NGComm
			WHERE 
				LicenseeID = @LicenseeID 
				AND custid = @CustID
		END

		--racing
		IF @IsUpdateRacing=1
		BEGIN
			Update LicenseeCustComm WITH (ROWLOCK,UPDLOCK)
				SET RacingComm=@RacingComm
			WHERE 
				LicenseeID = @LicenseeID 
				AND custid = @CustID
		END
	END
	ELSE
	BEGIN
		--Update GroupcommID
		IF @GroupCommID>0
		BEGIN
			Update LicenseeCustComm WITH (ROWLOCK,UPDLOCK)
				SET GroupCommID=@GroupCommID
				
				WHERE 
					LicenseeID = @LicenseeID 
					AND custid = @CustID
		END
	
	
		IF @IsUpdateComm=1
		BEGIN
			--Update LicenseeCustComm
			--sportsbook
			Update LicenseeCustComm WITH (ROWLOCK,UPDLOCK)
					SET SBComm=@SBComm
					
					WHERE 
						LicenseeID = @LicenseeID 
						AND custid = @CustID

			--NG
			IF @IsUpdateNG=1 
			BEGIN
				Update LicenseeCustComm WITH (ROWLOCK,UPDLOCK)
					SET NGComm=@NGComm
				WHERE 
					LicenseeID = @LicenseeID 
					AND custid = @CustID
			END

			--racing
			IF @IsUpdateRacing=1
			BEGIN
				Update LicenseeCustComm WITH (ROWLOCK,UPDLOCK)
					SET RacingComm=@RacingComm
				WHERE 
					LicenseeID = @LicenseeID 
					AND custid = @CustID
			END
		END
		
	END
	
	SET @i=@i+1		
END


GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerUpdMemberComm] TO [bodbAdminNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerUpdMemberComm] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerUpdMemberComm] TO [Dot_Member] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerUpdMemberComm] TO [vnteam] AS [dbo]