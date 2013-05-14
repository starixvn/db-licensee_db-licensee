set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[Lrf_LicenseeGroupCommUpd]
	@LicenseeID INT,
	@GroupCommID INT,
	@GroupName VARCHAR(100),
	@SBComm decimal(9,8),
	@NGComm decimal (9,8)=0,
	@RacingComm decimal(9,8)=0,
	@IsUpdateNG BIT = 0,
	@IsUpdateRacing BIT = 0,
	@GroupColor VARCHAR(20),
	@IsDefault BIT=0, 
	@IsResetDefault BIT=0,
	@UserID INT,
	@IP varchar(40),
	@Langkey VARCHAR(20) = 'en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg varchar(8000) = '' OUTPUT
AS

/*
Created: 20120726@Henry
Task : Update Group Commission
DB: DB052.bodb_Licensee


Revisions:
- 20121227@Henry: Add column IsDefault
- 20130413@Jim: support multi language 	
Param's Explanation:

*/

DECLARE @startRun DATETIME
DECLARE @endRun DATETIME
DECLARE @duration INT
SET @startRun = GETDATE()

DECLARE @GroupName_Old VARCHAR(100), @GroupColor_Old VARCHAR(20),
@SBComm_Old decimal(9,8), @RacingComm_Old decimal(9,8), @NGComm_Old decimal(9,8), @IsDefault_Old BIT

DECLARE @LogSPData VARCHAR(MAX)
DECLARE @TrackingValue2 VARCHAR(MAX)

DECLARE @FlagUpdateGroupProperty BIT, @FlagUpdateComm BIT, @FlagUpdateIsDefault BIT

SELECT @FlagUpdateGroupProperty=0,@FlagUpdateComm=0,@FlagUpdateIsDefault=0

SELECT @GroupName = rtrim(ltrim(@GroupName))

--Validate data
IF @SBComm>0.15 OR @RacingComm>0.15 OR @NGComm>0.15
BEGIN
	SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'Player Commission should not greater than '
									ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200002,@Langkey)
									END +'0.15', @ErrCode = 100
	RETURN
END

IF NOT EXISTS(
	SELECT TOP 1 1 FROM LicenseeGroupComm WITH (NOLOCK)
	WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
)
BEGIN
	SELECT @ErrMsg =CASE @Langkey WHEN 'en-US' THEN 'This Group does not exist!'
								  ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200016,@Langkey)
								 END , @ErrCode = 101	
	RETURN
END
ELSE
BEGIN
	SELECT @GroupName_Old=GroupName,@GroupColor_Old=color,@SBComm_Old=SBComm,@NGComm_Old=NGComm,@RacingComm_Old=RacingComm,@IsDefault_Old=IsDefault
	FROM LicenseeGroupComm WITH (NOLOCK)
	WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID

	--Update IsDefault
	IF @IsDefault <> @IsDefault_Old
	BEGIN
		IF @IsDefault=1 --Set IsDefault for current update group
		BEGIN
			--Check exist ISDefault
			IF @IsResetDefault=0 AND EXISTS(SELECT TOP 1 1 FROM LicenseeGroupComm WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND ID <> @GroupCommID AND IsDefault=1 AND IsActive = 1)
			BEGIN
				SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN 'Another group is currently set as default. Wanna set this group as default?'
												ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200018,@Langkey)
												END, @ErrCode = 103	
				RETURN
			END
			
			--Reset IsDefault Old to 0
			Update LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
			SET IsDefault=0 WHERE LicenseeID = @LicenseeID AND IsDefault=1
			
			--Set IsDefault for current group
			UPDATE LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
			SET IsDefault=1 WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
			
			SET @FlagUpdateIsDefault=1
		END
		ELSE
		BEGIN
			UPDATE LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
			SET IsDefault=0 WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
			
			SET @FlagUpdateIsDefault=1
		END
		
	END

	--Update Group Name and Group Color
	IF @GroupName_Old <> @GroupName OR @GroupColor_Old <> @GroupColor
	BEGIN
		IF EXISTS(
			SELECT TOP 1 1 FROM LicenseeGroupComm WITH (NOLOCK)
			WHERE LicenseeID = @LicenseeID AND GroupName=@GroupName AND ID <> @GroupCommID AND IsActive=1
		)
		BEGIN
			SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'This group name has been already chosen, please try another name!'
										   ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200020,@Langkey)
										   END , @ErrCode = 102
			RETURN
		END
		ELSE
		BEGIN
			Update LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
			SET GroupName=@GroupName,color=@GroupColor
			WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
			IF @@ROWCOUNT=1
			BEGIN			
				SET @FlagUpdateGroupProperty=1
			END
		END	
	END

	--Update Group Comm + Member Comm + all the comm settings
	IF @SBComm_Old<>@SBComm OR @NGComm_Old <> @NGComm OR @RacingComm_Old <> @RacingComm
	BEGIN
		--Sportsbook
		Update LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
		SET SBComm=@SBComm
		WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
		
		--NG
		IF @IsUpdateNG=1 
		BEGIN
			Update LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
			SET NGComm=@NGComm
			WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
		END
		
		--racing
		IF @IsUpdateRacing=1
		BEGIN
			Update LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
			SET RacingComm=@RacingComm
			WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
		END
		
		
		--get list of affected Customers
		DECLARE @strCustID VARCHAR(MAX)
		 SELECT @strCustID = STUFF(
                        (   SELECT  ',' + CONVERT(NVARCHAR(20), custid) 
                            FROM LicenseeCustComm WITH (NOLOCK)
							WHERE LicenseeID = @LicenseeID AND GroupCommID = @GroupCommID
                            FOR xml path('')
                        )
                        , 1
                        , 1
                        , '')
        
        IF LTRIM(RTRIM(@strCustID)) <> ''
        BEGIN
			--Update List of affected Customers               
			EXEC [Lrf_CustomerUpdMemberComm] @LicenseeID=@LicenseeID,@strCustID=@strCustID,@UserID=@UserID,@GroupCommID=@GroupCommID,@SBComm=@SBComm,@NGComm=@NGComm,@RacingComm=@RacingComm,@IsUpdateNG=@IsUpdateNG,@IsUpdateRacing=@IsUpdateRacing,@IP=@IP,@Langkey=@langkey,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
		END
				
		SET @FlagUpdateComm = 1
	END
	
	
	

	IF @FlagUpdateComm=1 OR @FlagUpdateGroupProperty=1 OR @FlagUpdateIsDefault=1 --Writelog
	BEGIN
		SET @endRun = GETDATE()
		SET @duration  = datediff (millisecond,@startRun,@endRun)	
	
		SELECT @LogSPData = '<Lrf_LicenseeGroupCommUpd GroupCommID="'+ COALESCE(CAST(@GroupCommID as VARCHAR(50)),SPACE(1)) + '" ' +
		'LicenseeID="'+ COALESCE(CAST(@LicenseeID as VARCHAR(50)),SPACE(1)) + '" ' +
		'GroupName="'+ COALESCE(CAST(@GroupName as VARCHAR(100)),SPACE(1)) + '" ' +
		'SBComm="'+ COALESCE(CAST(@SBComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'NGComm="'+ COALESCE(CAST(@NGComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'RacingComm="'+ COALESCE(CAST(@RacingComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'IsUpdateNG="'+ COALESCE(CAST(@IsUpdateNG as VARCHAR(50)),SPACE(1)) + '" ' +
		'IsUpdateRacing="'+ COALESCE(CAST(@IsUpdateRacing as VARCHAR(50)),SPACE(1)) + '" ' +
		'GroupColor="'+ COALESCE(CAST(@GroupColor as VARCHAR(40)),SPACE(1)) + '" ' +
		'IsDefault="'+ COALESCE(CAST(@IsDefault as VARCHAR(40)),SPACE(1)) + '" ' +
		'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
		'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
		'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
		'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'

		SELECT @TrackingValue2 = '<Lrf_LicenseeGroupCommUpd GroupCommID="'+ COALESCE(CAST(@GroupCommID as VARCHAR(50)),SPACE(1)) + '" ' +
		'LicenseeID="'+ COALESCE(CAST(@LicenseeID as VARCHAR(50)),SPACE(1)) + '" ' +
		'GroupName="'+ COALESCE(CAST(@GroupName_Old as VARCHAR(100)),SPACE(1)) + '" ' +
		'SBComm="'+ COALESCE(CAST(@SBComm_Old as VARCHAR(50)),SPACE(1)) + '" ' +
		'NGComm="'+ COALESCE(CAST(@NGComm_Old as VARCHAR(50)),SPACE(1)) + '" ' +
		'RacingComm="'+ COALESCE(CAST(@RacingComm_Old as VARCHAR(50)),SPACE(1)) + '" ' +
		'IsUpdateNG="'+ COALESCE(CAST(@IsUpdateNG as VARCHAR(50)),SPACE(1)) + '" ' +
		'IsUpdateRacing="'+ COALESCE(CAST(@IsUpdateRacing as VARCHAR(50)),SPACE(1)) + '" ' +
		'GroupColor="'+ COALESCE(CAST(@GroupColor_Old as VARCHAR(40)),SPACE(1)) + '" ' +
		'IsDefault="'+ COALESCE(CAST(@IsDefault_Old as VARCHAR(40)),SPACE(1)) + '" ' +
		'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
		'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
		'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
		'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'
	
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
				@UserID = @UserID,
				@CustID = @GroupCommID,
				@ActionID = 2610,
				@TrackingValue = @LogSPData,
				@TrackingValue2 = @TrackingValue2,
				@duration = @duration
	END

END

	
GO
GRANT EXECUTE ON [dbo].[Lrf_LicenseeGroupCommUpd] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_LicenseeGroupCommUpd] TO [vnteam]  
  
