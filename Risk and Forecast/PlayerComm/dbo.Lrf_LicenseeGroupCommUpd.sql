/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0"></info>*/ 
ALTER PROCEDURE [dbo].[Lrf_LicenseeGroupCommUpd]
	@LicenseeID INT,
	@GroupCommID INT,
	@GroupName VARCHAR(100),
	@SBComm decimal(9,8),
	@ParlayComm decimal(9,8),
	@NGComm decimal (9,8)=0,
	@RNGComm decimal(9,8)=0,
	@AllbetComm DECIMAL(9,8)=0,
	@IsUpdateNG BIT = 0,
	@IsUpdateRNG BIT = 0,
	@IsUpdateAllbet BIT =0,
	@GroupColor VARCHAR(20),
	@IsDefault BIT=0, 
	@IsResetDefault BIT=0,
	@UserID INT,
	@IP varchar(40),
	@Langkey VARCHAR(20) = 'en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg varchar(8000) = '' OUTPUT,
	@StrCustID VARCHAR(MAX) = '' OUTPUT
AS

/*
Created: 20120726@Henry
Task : Update Group Commission
DB: DBLIC/bodb_Licensee


Revisions:
	- 20121227@Henry: Add column IsDefault
	- 20130413@Jim: support multi language 	
	- 20131023@Hannah: offer Live Casino commission
	- 20131126@Hannah: offer RNG Casino commission
	- 20140630@Francis: Remove link-server when calling write log sp
	- 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]
	- 20171020@Johnson: offer Allbet commision [Redmine: #82036]
	- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
	- 20180809@Amanda: Remove Racing [RedmineID: #99378]
	
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON
	
	IF (@IsUpdateNG = 0) AND  (@IsUpdateRNG = 0) AND (@IsUpdateAllbet =0)
	BEGIN
		UPDATE [bodb_licensee].[dbo].[LicenseeGroupComm]
		SET
			 GroupName = @GroupName,
			 color = @GroupColor,
			 IsDefault = @IsDefault
		WHERE id = @GroupCommID AND Licenseeid = @LicenseeID
		RETURN
	END
	DECLARE @startRun DATETIME
	DECLARE @endRun DATETIME
	DECLARE @duration INT
	SET @startRun = GETDATE()

	DECLARE @GroupName_Old VARCHAR(100)
		,@GroupColor_Old VARCHAR(20)
		,@SBComm_Old DECIMAL(9,8)
		,@ParlayComm_Old DECIMAL(9,8)
		,@NGComm_Old DECIMAL(9,8)
		,@RNGComm_Old DECIMAL(9,8)
		,@AllbetComm_Old DECIMAL(9,8)
		,@IsDefault_Old BIT
		
	DECLARE @LogSPData VARCHAR(MAX)
	DECLARE @TrackingValue2 VARCHAR(MAX)

	DECLARE @FlagUpdateGroupProperty BIT, @FlagUpdateComm BIT, @FlagUpdateIsDefault BIT

	SELECT @FlagUpdateGroupProperty=0,@FlagUpdateComm=0,@FlagUpdateIsDefault=0

	SELECT @GroupName = rtrim(ltrim(@GroupName))

	--Validate data
	IF @SBComm>0.15 OR @NGComm>0.15 OR @RNGComm>0.15 OR @ParlayComm >0.15 OR @AllbetComm> 0.15
	BEGIN
		SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'Player Commission should not greater than '
										ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200002,@Langkey)
										END +'0.15', @ErrCode = 100
		RETURN
	END

	IF NOT EXISTS(
		SELECT TOP 1 1 FROM dbo.LicenseeGroupComm WITH (NOLOCK)
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
		SELECT @GroupName_Old=GroupName
			,@GroupColor_Old=color
			,@SBComm_Old=SBComm
			,@ParlayComm_Old=ParlayComm
			,@NGComm_Old=NGComm
			,@RNGComm_Old=RNGComm
			,@AllbetComm_Old=AllbetComm
			,@IsDefault_Old=IsDefault			
		FROM dbo.LicenseeGroupComm WITH (NOLOCK)
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
				Update dbo.LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
				SET IsDefault=0 WHERE LicenseeID = @LicenseeID AND IsDefault=1
				
				--Set IsDefault for current group
				UPDATE dbo.LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
				SET IsDefault=1 WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
				
				SET @FlagUpdateIsDefault=1
			END
			ELSE
			BEGIN
				UPDATE dbo.LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
				SET IsDefault=0 WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
				
				SET @FlagUpdateIsDefault=1
			END
			
		END

		--Update Group Name and Group Color
		IF @GroupName_Old <> @GroupName OR @GroupColor_Old <> @GroupColor
		BEGIN
			IF EXISTS(
				SELECT TOP 1 1 FROM dbo.LicenseeGroupComm WITH (NOLOCK)
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
				Update dbo.LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
				SET GroupName=@GroupName,color=@GroupColor
				WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
				IF @@ROWCOUNT=1
				BEGIN			
					SET @FlagUpdateGroupProperty=1
				END
			END	
		END

		--Update Group Comm + Member Comm + all the comm settings
		IF @SBComm_Old<>@SBComm 
			OR @ParlayComm_Old<>@ParlayComm 
			OR @NGComm_Old <> @NGComm 
			OR @RNGComm_Old <> @RNGComm
			OR @AllbetComm_Old <> @AllbetComm
		BEGIN
			--Sportsbook
			Update dbo.LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
			SET SBComm=@SBComm
				,ParlayComm = @ParlayComm
			WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
			
			--NG
			IF @IsUpdateNG=1 
			BEGIN
				Update dbo.LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
				SET NGComm=@NGComm
				WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
			END
			
			--RNG
			IF @IsUpdateRNG=1
			BEGIN
				Update dbo.LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
				SET RNGComm=@RNGComm
				WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
			END
			
			IF @IsUpdateAllbet=1
			BEGIN
				UPDATE dbo.LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
				SET AllbetComm=@AllbetComm
				WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
			END
			
			--get list of affected Customers
			SELECT @StrCustID = STUFF(
				(   SELECT  ',' + CONVERT(NVARCHAR(20), custid) 
					FROM LicenseeCustComm WITH (NOLOCK)
					WHERE LicenseeID = @LicenseeID AND GroupCommID = @GroupCommID
					FOR xml path('')
				)
				, 1
				, 1
				, '')
			
			IF LTRIM(RTRIM(@StrCustID)) <> ''
			BEGIN
				--Update List of affected Customers               
				EXEC [Lrf_CustomerUpdMemberComm] 
					@LicenseeID=@LicenseeID
					,@StrCustID=@StrCustID
					,@UserID=@UserID
					,@GroupCommID=@GroupCommID
					,@SBComm=@SBComm
					,@ParlayComm=@ParlayComm
					,@NGComm=@NGComm
					,@RNGComm=@RNGComm
					,@AllbetComm=@AllbetComm
					,@IsUpdateNG=@IsUpdateNG
					,@IsUpdateRNG=@IsUpdateRNG
					,@IsUpdateAllbet=@IsUpdateAllbet
					,@IP=@IP
					,@Langkey=@langkey
					,@ErrCode=@ErrCode OUTPUT
					,@ErrMsg=@ErrMsg OUTPUT 
				WITH RECOMPILE
					
				SELECT @StrCustID = STUFF(
					(   SELECT  ',' + CONVERT(NVARCHAR(20), a.custid) 
						FROM bodb_Licensee.dbo.LicenseeCustComm b WITH (NOLOCK)
						INNER JOIN bodb02.dbo.custinfo a WITH (NOLOCK) ON a.custid = b.custid
						WHERE b.LicenseeID = @LicenseeID AND b.GroupCommID = @GroupCommID and a.SyncCasino = 1
						FOR xml path('')
					)
					, 1
					, 1
					, '')
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
			'ParlayComm="'+ COALESCE(CAST(@ParlayComm as VARCHAR(50)),SPACE(1)) + '" ' +
			'NGComm="'+ COALESCE(CAST(@NGComm as VARCHAR(50)),SPACE(1)) + '" ' +
			'RNGComm="'+ COALESCE(CAST(@RNGComm as VARCHAR(50)),SPACE(1)) + '" ' +
			'AllbetComm="'+ COALESCE(CAST(@AllbetComm as VARCHAR(50)),SPACE(1)) + '" ' +
			'IsUpdateNG="'+ COALESCE(CAST(@IsUpdateNG as VARCHAR(50)),SPACE(1)) + '" ' +
			'IsUpdateRNG="'+ COALESCE(CAST(@IsUpdateRNG as VARCHAR(50)),SPACE(1)) + '" ' +
			'IsUpdateAllbet="'+ COALESCE(CAST(@IsUpdateAllbet as VARCHAR(50)),SPACE(1)) + '" ' +
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
			'ParlayComm="'+ COALESCE(CAST(@ParlayComm_Old as VARCHAR(50)),SPACE(1)) + '" ' +
			'NGComm="'+ COALESCE(CAST(@NGComm_Old as VARCHAR(50)),SPACE(1)) + '" ' +
			'RNGComm="'+ COALESCE(CAST(@RNGComm_Old as VARCHAR(50)),SPACE(1)) + '" ' +
			'AllbetComm="'+ COALESCE(CAST(@AllbetComm_Old as VARCHAR(50)),SPACE(1)) + '" ' +
			'IsUpdateNG="'+ COALESCE(CAST(@IsUpdateNG as VARCHAR(50)),SPACE(1)) + '" ' +
			'IsUpdateRNG="'+ COALESCE(CAST(@IsUpdateRNG as VARCHAR(50)),SPACE(1)) + '" ' +
			'IsUpdateAllbet="'+ COALESCE(CAST(@IsUpdateAllbet as VARCHAR(50)),SPACE(1)) + '" ' +
			'GroupColor="'+ COALESCE(CAST(@GroupColor_Old as VARCHAR(40)),SPACE(1)) + '" ' +
			'IsDefault="'+ COALESCE(CAST(@IsDefault_Old as VARCHAR(40)),SPACE(1)) + '" ' +
			'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
			'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
			'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
			'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'
		
			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
					@UserID = @UserID,
					@CustID = @GroupCommID,
					@ActionID = 2610,
					@TrackingValue = @LogSPData,
					@TrackingValue2 = @TrackingValue2,
					@duration = @duration
		END
		IF @IsUpdateRNG=0
		SELECT @StrCustID = ''
	END
END	
GO 
  