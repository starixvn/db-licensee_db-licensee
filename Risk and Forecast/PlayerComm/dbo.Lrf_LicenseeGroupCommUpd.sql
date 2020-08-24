/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Lrf_LicenseeGroupCommUpd]
	@LicenseeID INT,
	@GroupCommID INT,
	@GroupName VARCHAR(100),
	@SBComm decimal(9,8),
	@ParlayComm decimal(9,8),
	@NGComm decimal (9,8)=0,
	@RNGComm decimal(9,8)=0,
	--@AllbetComm decimal (9,8)=0,
	@MacauComm decimal (9,8)=0,
	@PPComm decimal (9,8)=0,
	--@GDComm decimal (9,8)=0,
	--@AGComm decimal (9,8)=0,
	@FWComm decimal (9,8)=0,
	@IsUpdateNG BIT = 0,
	@IsUpdateRNG BIT = 0,	
	--@IsUpdateAllbet BIT = 0,
	@IsUpdateMacau BIT = 0,
	@IsUpdatePP BIT = 0,
	--@IsUpdateGD BIT = 0,
	--@IsUpdateAG BIT = 0,
	@IsUpdateFW BIT = 0,
	--start param of phase 2 
	@IsUpdateSexyGaming BIT = 0,	
	@SexyGamingComm DECIMAL(9,8) = 0,
	@IsUpdateSpadeGaming BIT = 0,	
	@SpadeGamingComm DECIMAL(9,8) = 0,
	@IsUpdateKeno BIT = 0,	
	@KenoComm DECIMAL(9,8) = 0,
	@IsUpdateLottery BIT = 0,	
	@LotteryComm DECIMAL(9,8) = 0,
	@IsUpdateVS BIT = 0,	
	@VSComm DECIMAL(9,8) = 0,
	@IsUpdateVS2 BIT = 0,	
	@VS2Comm DECIMAL(9,8) = 0,
	@IsUpdateTableGame BIT = 0,	
	@TableGameComm DECIMAL(9,8) = 0,
	-- end param of phase 2
	@GroupColor VARCHAR(20),
	@IsDefault BIT=0, 
	@IsResetDefault BIT=0,
	@UserID INT,
	@IP varchar(40),
	@Langkey VARCHAR(20) = 'en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(4000) = '' OUTPUT,
	@StrCustID VARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: 20120726@Henry
	Task : Update Group Commission
	DB: DBCUST/bodb_Licensee

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
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
		- 20180927@Winnie: Remove AllBet [RedmineID: #99378]
		- 20200410@Johnson: Add comm for AB,Macau,PP,GD,AG [redmine:#131774] 
		- 20200511@Max: Add comm for FW, Remove AG, GD - [Redmine: #131774]
		- 20200518@Helen: Add comm for FW, Remove AG, GD - Tuning performance - [Redmine: #131774]
		- 20200701@Helen: Remove Allbet - [Redmine: #131774]  
		- 20200814@Helen: LAP - Offer commission to 3rd party products - Phase 2 - [Redmine: #139238] 
		
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON
	
	IF (@IsUpdateNG = 0) AND  (@IsUpdateRNG = 0) 
	BEGIN
		UPDATE [dbo].[LicenseeGroupComm]
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
		--,@AllbetComm_Old DECIMAL(9,8)
		,@MacauComm_Old DECIMAL(9,8)
		,@PPComm_Old DECIMAL(9,8)
		--,@GDComm_Old DECIMAL(9,8)
		--,@AGComm_Old DECIMAL(9,8)
		,@FWComm_Old DECIMAL(9,8)
		,@SexyGamingComm_Old DECIMAL(9,8)=0
		,@SpadeGamingComm_Old DECIMAL(9,8)=0
		,@LotteryComm_Old DECIMAL(9,8)=0
		,@KenoComm_Old DECIMAL(9,8)=0
		,@VSComm_Old DECIMAL(9,8)=0
		,@VS2Comm_Old DECIMAL(9,8)=0
		,@TableGameComm_Old DECIMAL(9,8)=0
		
		,@IsDefault_Old BIT
		,@custID_cnt INT = 0
	DECLARE @IsexistMember BIT = 0
		
	DECLARE @LogSPData VARCHAR(MAX)
	DECLARE @TrackingValue2 VARCHAR(MAX)

	DECLARE @FlagUpdateGroupProperty BIT, @FlagUpdateComm BIT, @FlagUpdateIsDefault BIT

	SELECT @FlagUpdateGroupProperty=0,@FlagUpdateComm=0,@FlagUpdateIsDefault=0

	SELECT @GroupName = rtrim(ltrim(@GroupName))

	--Validate data
	IF @SBComm>0.15 OR @NGComm>0.15 OR @RNGComm>0.15 OR @ParlayComm >0.15 
		--OR @AllbetComm>0.15 
		OR @MacauComm>0.15 OR @PPComm>0.15 
		--OR @GDComm>0.15 OR @AGComm>0.15
		OR @SexyGamingComm  > 0.15
		OR @SpadeGamingComm  > 0.15
		OR @KenoComm  > 0.15
		OR @LotteryComm  > 0.15
		OR @VSComm  > 0.15
		OR @VS2Comm > 0.15
		OR @TableGameComm  > 0.15 
	BEGIN
		SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'Player Commission should not greater than '
										ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200002,@Langkey)
										END +'0.15', @ErrCode = 100
		RETURN
	END

	SET @custID_cnt = (SELECT COUNT(1) FROM LicenseeCustComm WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND GroupCommID = @GroupCommID)
	
	IF @custID_cnt > 200000
	BEGIN
		SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'You have reached the maximum number of updating customers'' commission. Please contact Customer Service to process your request.'
										ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200049,@Langkey)
										END, @ErrCode = 100
		
		RETURN
	END
		
	IF NOT EXISTS(
		SELECT TOP 1 1 FROM dbo.LicenseeGroupComm WITH (NOLOCK)
		WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
	)
	BEGIN
		SELECT @ErrMsg =CASE @Langkey WHEN 'en-US' THEN 'This Group does not exist!'
									  ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200016,@Langkey)
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
			--,@AllbetComm_Old=AllbetComm
			,@MacauComm_Old=MacauComm
			,@PPComm_Old=PPComm
			--,@GDComm_Old=GDComm
			--,@AGComm_Old=AGComm
			,@FWComm_Old = FWComm
			,@SexyGamingComm_Old = SexyGamingComm
			,@SpadeGamingComm_Old = SpadeGamingComm
			,@LotteryComm_Old = LotteryComm
			,@KenoComm_Old = KenoComm
			,@VSComm_Old = VSComm
			,@VS2Comm_Old = VS2Comm
			,@TableGameComm_Old =TableGameComm
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
													ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200018,@Langkey)
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
											   ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200020,@Langkey)
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

		-- Verify changes before update
		DECLARE @IsUpdateSB BIT = 0, @IsParlayComm BIT = 0
		
		SELECT @IsUpdateSB = CASE WHEN @SBComm_Old <> @SBComm THEN 1 ELSE 0 END,
			@IsParlayComm = CASE WHEN @ParlayComm_Old <> @ParlayComm  THEN 1 ELSE 0 END,
			@IsUpdateNG  = CASE WHEN @IsUpdateNG = 1 AND @NGComm_Old <> @NGComm  THEN 1 ELSE 0 END,
			@IsUpdateRNG  = CASE WHEN @IsUpdateRNG = 1 AND @RNGComm_Old <> @RNGComm	  THEN 1 ELSE 0 END,	
			@IsUpdateMacau  = CASE WHEN @IsUpdateMacau = 1 AND @MacauComm_Old <> @MacauComm  THEN 1 ELSE 0 END,
			@IsUpdatePP  = CASE WHEN @IsUpdatePP = 1 AND @PPComm_Old <> @PPComm  THEN 1 ELSE 0 END,
			@IsUpdateFW  = CASE WHEN @IsUpdateFW = 1 AND @FWComm_Old <> @FWComm  THEN 1 ELSE 0 END,
			--- phase 2
			@IsUpdateSexyGaming  = CASE WHEN @IsUpdateSexyGaming = 1 AND @SexyGamingComm_Old <> @SexyGamingComm  THEN 1 ELSE 0 END,
			@IsUpdateSpadeGaming  = CASE WHEN @IsUpdateSpadeGaming = 1 AND @SpadeGamingComm_Old <> @SpadeGamingComm  THEN 1 ELSE 0 END,
			@IsUpdateLottery  = CASE WHEN @IsUpdateLottery = 1 AND @LotteryComm_Old <> @LotteryComm  THEN 1 ELSE 0 END,
			@IsUpdateKeno  = CASE WHEN @IsUpdateKeno = 1 AND @KenoComm_Old <> @KenoComm  THEN 1 ELSE 0 END,
			@IsUpdateVS  = CASE WHEN @IsUpdateVS = 1 AND @VSComm_Old <> @VSComm  THEN 1 ELSE 0 END,
			@IsUpdateVS2  = CASE WHEN @IsUpdateVS2 = 1 AND @VS2Comm_Old <> @VS2Comm  THEN 1 ELSE 0 END,
			@IsUpdateTableGame  = CASE WHEN @IsUpdateTableGame = 1 AND @TableGameComm_Old <> @TableGameComm  THEN 1 ELSE 0 END
			
		--Update Group Comm + Member Comm + all the comm settings
		IF (@IsUpdateSB = 1
			OR @IsParlayComm = 1
			OR @IsUpdateNG = 1
			OR @IsUpdateRNG = 1
			--OR @IsUpdateAllbet = 1
			OR @IsUpdateMacau = 1
			OR @IsUpdatePP = 1
			OR @IsUpdateFW = 1
			OR @IsUpdateSexyGaming = 1
			OR @IsUpdateSpadeGaming = 1
			OR @IsUpdateKeno = 1
			OR @IsUpdateLottery = 1
			OR @IsUpdateVS = 1
			OR @IsUpdateVS2 = 1
			OR @IsUpdateTableGame = 1
			)
		
		BEGIN
			
			UPDATE dbo.LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
				SET SBComm = CASE WHEN @IsUpdateSB = 1 THEN @SBComm ELSE SBComm END
					,ParlayComm = CASE WHEN @IsParlayComm = 1 THEN @ParlayComm ELSE ParlayComm END
					, NGComm =CASE WHEN @IsUpdateNG = 1 THEN @NGComm ELSE NGComm END   
					, RNGComm = CASE WHEN @IsUpdateRNG = 1 THEN @RNGComm ELSE RNGComm END  
					--, AllbetComm =CASE WHEN @IsUpdateAllbet = 1 THEN @AllbetComm ELSE AllbetComm END   
					, MacauComm = CASE WHEN @IsUpdateMacau = 1 THEN @MacauComm ELSE MacauComm END  
					, PPComm= CASE WHEN @IsUpdatePP = 1 THEN @PPComm ELSE PPComm END      
					, FWComm = CASE WHEN @IsUpdateFW = 1 THEN @FWComm ELSE FWComm END 
					-- phase 2
					, SexyGamingComm  = CASE WHEN @IsUpdateSexyGaming = 1 THEN @SexyGamingComm ELSE SexyGamingComm END 
					, SpadeGamingComm  = CASE WHEN @IsUpdateSpadeGaming = 1 THEN @SpadeGamingComm ELSE SpadeGamingComm END
					, KenoComm  = CASE WHEN @IsUpdateKeno = 1 THEN @KenoComm ELSE KenoComm END
					, LotteryComm  = CASE WHEN @IsUpdateLottery = 1 THEN @LotteryComm ELSE LotteryComm END
					, VSComm  = CASE WHEN @IsUpdateVS = 1 THEN @VSComm ELSE VSComm END
					, VS2Comm = CASE WHEN @IsUpdateVS2 = 1 THEN @VS2Comm ELSE VS2Comm END
					, TableGameComm  = CASE WHEN @IsUpdateTableGame = 1 THEN @TableGameComm ELSE TableGameComm END
					--, GDComm = CASE WHEN @IsUpdateGD = 1 THEN @GDComm ELSE GDComm END  
					--, AGComm = CASE WHEN @IsUpdateAG =1  THEN @AGComm ELSE AGComm END  
			WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
			
			SET @IsexistMember = (SELECT TOP (1) 1 
						FROM LicenseeCustComm ls WITH (NOLOCK)
							INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON ls.CustID = c.custid
						WHERE LicenseeID = @LicenseeID AND GroupCommID = @GroupCommID)
						
			IF @IsexistMember = 1			
			BEGIN
				--Update List of affected Customers               
				EXEC [Lrf_CustomerUpdMemberComm] 
					@LicenseeID=@LicenseeID
					,@StrCustID = ''
					,@IsUpdateGroupComm = 1
					,@UserID=@UserID
					,@GroupCommID=@GroupCommID
					,@SBComm=@SBComm
					,@ParlayComm=@ParlayComm
					,@NGComm=@NGComm
					,@RNGComm=@RNGComm
					--,@AllbetComm=@AllbetComm
					,@MacauComm=@MacauComm
					,@PPComm=@PPComm
					--,@GDComm=@GDComm
					--,@AGComm=@AGComm	
					,@FWComm = @FWComm
					,@IsUpdateSB = @IsUpdateSB
					,@IsParlayComm = @IsParlayComm
					,@IsUpdateNG=@IsUpdateNG
					,@IsUpdateRNG=@IsUpdateRNG					
					--,@IsUpdateAllbet=@IsUpdateAllbet
					,@IsUpdateMacau=@IsUpdateMacau
					,@IsUpdatePP=@IsUpdatePP
					--,@IsUpdateGD=@IsUpdateGD
					--,@IsUpdateAG=@IsUpdateAG
					,@IsUpdateFW = @IsUpdateFW
					---start param of phase 2
					,@IsUpdateSexyGaming = @IsUpdateSexyGaming	
					,@SexyGamingComm = @SexyGamingComm
					,@IsUpdateSpadeGaming = @IsUpdateSpadeGaming	
					,@SpadeGamingComm =  @SpadeGamingComm
					,@IsUpdateKeno = @IsUpdateKeno
					,@KenoComm =  @KenoComm
					,@IsUpdateLottery  = @IsUpdateLottery	
					,@LotteryComm =  @LotteryComm
					,@IsUpdateVS = @IsUpdateVS 	
					,@VSComm =  @VSComm
					,@IsUpdateVS2 =  @IsUpdateVS2	
					,@VS2Comm = @VS2Comm 
					,@IsUpdateTableGame = @IsUpdateTableGame
					,@TableGameComm = @TableGameComm
					-- end of param phase 2
					,@IP=@IP
					,@Langkey=@langkey
					,@ErrCode=@ErrCode OUTPUT
					,@ErrMsg=@ErrMsg OUTPUT 
				WITH RECOMPILE
					
				SELECT @StrCustID = STUFF(
					(   SELECT  ',' + CONVERT(NVARCHAR(20), a.custid) 
						FROM dbo.LicenseeCustComm b WITH (NOLOCK)
						INNER JOIN CustDB.dbo.custinfo a WITH (NOLOCK) ON a.custid = b.custid
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
			--'AllbetComm="'+ COALESCE(CAST(@AllbetComm as VARCHAR(50)),SPACE(1)) + '" ' +
			'MacauComm="'+ COALESCE(CAST(@MacauComm as VARCHAR(50)),SPACE(1)) + '" ' +
			'PPComm="'+ COALESCE(CAST(@PPComm as VARCHAR(50)),SPACE(1)) + '" ' +
			--'GDComm="'+ COALESCE(CAST(@GDComm as VARCHAR(50)),SPACE(1)) + '" ' +
			--'AGComm="'+ COALESCE(CAST(@AGComm as VARCHAR(50)),SPACE(1)) + '" ' +
			'FWComm="'+ COALESCE(CAST(@FWComm as VARCHAR(50)),SPACE(1)) + '" ' +
				-- phase 2
			'SexyGamingComm="'+ COALESCE(CAST(@SexyGamingComm as VARCHAR(50)),SPACE(1)) + '" '+
			'SpadeGamingComm="'+ COALESCE(CAST(@SpadeGamingComm as VARCHAR(50)),SPACE(1)) + '" '+
			'KenoComm="'+ COALESCE(CAST(@KenoComm as VARCHAR(50)),SPACE(1)) + '" '+
			'LotteryComm="'+ COALESCE(CAST(@LotteryComm as VARCHAR(50)),SPACE(1)) + '" '+
			'VSComm="'+ COALESCE(CAST(@VSComm as VARCHAR(50)),SPACE(1)) + '" '+
			'VS2Comm="'+ COALESCE(CAST(@VS2Comm as VARCHAR(50)),SPACE(1)) + '" '+
			'TableGameComm="'+ COALESCE(CAST(@TableGameComm as VARCHAR(50)),SPACE(1)) + '" ' +
			
			'IsUpdateNG="'+ COALESCE(CAST(@IsUpdateNG as VARCHAR(50)),SPACE(1)) + '" ' +
			'IsUpdateRNG="'+ COALESCE(CAST(@IsUpdateRNG as VARCHAR(50)),SPACE(1)) + '" ' +			
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
			--'AllbetComm="'+ COALESCE(CAST(@AllbetComm_Old as VARCHAR(50)),SPACE(1)) + '" ' +
			'MacauComm="'+ COALESCE(CAST(@MacauComm_Old as VARCHAR(50)),SPACE(1)) + '" ' +
			'PPComm="'+ COALESCE(CAST(@PPComm_Old as VARCHAR(50)),SPACE(1)) + '" ' +
			--'GDComm="'+ COALESCE(CAST(@GDComm_Old as VARCHAR(50)),SPACE(1)) + '" ' +
			--'AGComm="'+ COALESCE(CAST(@AGComm_Old as VARCHAR(50)),SPACE(1)) + '" ' +
			'FWComm="'+ COALESCE(CAST(@FWComm_Old as VARCHAR(50)),SPACE(1)) + '" ' +
			-- phase 2
			'SexyGamingComm="'+ COALESCE(CAST(@SexyGamingComm_old as VARCHAR(50)),SPACE(1)) + '" '+
			'SpadeGamingComm="'+ COALESCE(CAST(@SpadeGamingComm_old as VARCHAR(50)),SPACE(1)) + '" '+
			'KenoComm="'+ COALESCE(CAST(@KenoComm_old as VARCHAR(50)),SPACE(1)) + '" '+
			'LotteryComm="'+ COALESCE(CAST(@LotteryComm_old as VARCHAR(50)),SPACE(1)) + '" '+
			'VSComm="'+ COALESCE(CAST(@VSComm_old as VARCHAR(50)),SPACE(1)) + '" '+
			'VS2Comm="'+ COALESCE(CAST(@VS2Comm_old as VARCHAR(50)),SPACE(1)) + '" '+
			'TableGameComm="'+ COALESCE(CAST(@TableGameComm_old as VARCHAR(50)),SPACE(1)) + '" ' +
			
			'IsUpdateNG="'+ COALESCE(CAST(@IsUpdateNG as VARCHAR(50)),SPACE(1)) + '" ' +
			'IsUpdateRNG="'+ COALESCE(CAST(@IsUpdateRNG as VARCHAR(50)),SPACE(1)) + '" ' +			
			--'IsUpdateAllbet="'+ COALESCE(CAST(@IsUpdateAllbet as VARCHAR(50)),SPACE(1)) + '" ' +
			'IsUpdateMacau="'+ COALESCE(CAST(@IsUpdateMacau as VARCHAR(50)),SPACE(1)) + '" ' +
			'IsUpdatePP="'+ COALESCE(CAST(@IsUpdatePP as VARCHAR(50)),SPACE(1)) + '" ' +
			--'IsUpdateGD="'+ COALESCE(CAST(@IsUpdateGD as VARCHAR(50)),SPACE(1)) + '" ' +
			--'IsUpdateAG="'+ COALESCE(CAST(@IsUpdateAG as VARCHAR(50)),SPACE(1)) + '" ' +
			'GroupColor="'+ COALESCE(CAST(@GroupColor_Old as VARCHAR(40)),SPACE(1)) + '" ' +
			'IsDefault="'+ COALESCE(CAST(@IsDefault_Old as VARCHAR(40)),SPACE(1)) + '" ' +
			'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
			'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
			'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
			'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'
		
			EXEC Lrf_WriteLog_UserLog_RunSP_Wrapper
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