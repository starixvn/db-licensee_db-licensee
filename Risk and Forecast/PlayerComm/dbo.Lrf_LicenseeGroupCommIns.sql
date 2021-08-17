/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_LicenseeGroupCommIns]
	@LicenseeID INT,
	@GroupName VARCHAR(100),
	@SBComm DECIMAL(9,8)=0,
	@ParlayComm DECIMAL(9,8)=0,
	@NGComm DECIMAL (9,8)=0,
	@RNGComm DECIMAL (9,8)=0,	
	@AllbetComm DECIMAL (9,8)=0,
	@MacauComm DECIMAL (9,8)=0,
	@PPComm DECIMAL (9,8)=0,
	--@AGComm DECIMAL (9,8)=0,
	--@GDComm DECIMAL (9,8)=0,
	@FWComm DECIMAL (9,8)=0,
	--start param of phase 2 
	@SexyGamingComm DECIMAL(9,8) = 0,
	@SpadeGamingComm DECIMAL(9,8) = 0,
	@KenoComm DECIMAL(9,8) = 0,
	@LotteryComm DECIMAL(9,8) = 0,
	@VSComm DECIMAL(9,8) = 0,
	@VS2Comm DECIMAL(9,8) = 0,
	@TableGameComm DECIMAL(9,8) = 0,
	-- end of phase 2
	-- phase 3
	@VirtualGamesComm DECIMAL(9,8) = 0,
	@ArcadiaGamingComm DECIMAL(9,8) = 0,
	@SabaclubComm DECIMAL(9,8) = 0,
	@SAGamingComm DECIMAL(9,8) = 0,
	@PGSoftComm DECIMAL(9,8) = 0,
	-->phase 4
	@WMCasinoComm		DECIMAL(9,8) = 0,
	@BigGamingComm		DECIMAL(9,8) = 0,
	@JokerComm			DECIMAL(9,8) = 0,
	@GDGComm			DECIMAL(9,8) = 0,
	@SportsLotteryComm	DECIMAL(9,8) = 0,
	@HabaneroComm		DECIMAL(9,8) = 0,
	@VGamingComm		DECIMAL(9,8) = 0,
	
	@GroupColor VARCHAR(20),
	@UserID INT,
	@IP VARCHAR(40),
	@GroupCommID INT=0 OUTPUT,
	@IsDefault BIT=0, 
	@IsResetDefault BIT=0,
	@Langkey VARCHAR(20) = 'en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(4000) = '' OUTPUT
AS

/*
Created: 20120726@Henry
Task : Insert new Group Commission
DB: DBCUST/bodb_Licensee

Revisions:
	- 20121227@Henry: Add column IsDefault
	- 20130413@Jim: support multi language
	- 20131023@Hannah: offer Live Casino commission
	- 20131126@Hannah: offer RNG Casino commission
	- 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]
	- 20171023@Johnson: offer Allbet commision [Redmine: #82036]
	- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
	- 20180809@Amanda: Remove Racing [RedmineID: #99378]
	- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
	- 20180927@Winnie: Remove AllBet [RedmineID: #99378]
	- 20200410@Johnson: Add comm for AB,Macau,PP,AG,GD [redmine:#131774] 
	- 20200511@Max: Add comm for FW, Remove AG, GD - [Redmine: #131774]
	- 20200814@Helen: LAP - Offer commission to 3rd party products - Phase 2 - [Redmine: #139238]   
	- 20201111@Helen: LAP - Offer commission to 3rd party products - Phase 3 - [Redmine: #145012] 
	- 20210603@Eden: LAP - Support commission for 3rd party products - Phase 4 [Redmine: #154048]  
	- 20210813@Johnson: Add VGaming [redmine: #159696]
	
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON
		
	DECLARE @startRun DATETIME
	DECLARE @endRun DATETIME
	DECLARE @duration INT
	SET @startRun = GETDATE()

	DECLARE @LogSPData VARCHAR(MAX)
	DECLARE @TrackingValue2 VARCHAR(MAX)

	SELECT @GroupName = rtrim(ltrim(@GroupName))

	--Validate data 
	IF @SBComm>0.15 
		OR @NGComm>0.15 
		OR @RNGComm>0.15 
		OR @ParlayComm > 0.15
		OR @AllbetComm > 0.15
		OR @MacauComm > 0.15 
		OR @PPComm > 0.15 
		--OR @GDComm > 0.15 
		--OR @AGComm > 0.15 
		OR @FWComm > 0.15
		-- phase 2
		OR @SexyGamingComm  > 0.15
		OR @SpadeGamingComm  > 0.15
		OR @KenoComm  > 0.15
		OR @LotteryComm  > 0.15
		OR @VSComm  > 0.15
		OR @VS2Comm > 0.15
		OR @TableGameComm  > 0.15
		--Phase 3
		OR @VirtualGamesComm > 0.15
		OR @ArcadiaGamingComm > 0.15
		OR @SabaclubComm > 0.15
		OR @SAGamingComm > 0.15
		OR @PGSoftComm > 0.15
		--Phase 4
		OR @WMCasinoComm > 0.15
		OR @BigGamingComm > 0.15
		OR @JokerComm > 0.15
		OR @GDGComm > 0.15
		OR @SportsLotteryComm > 0.15	
		OR @HabaneroComm > 0.15
		OR @VGamingComm > 0.15
	BEGIN
		SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'Player Commission should not greater than 0.15'
										ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200002,@Langkey)
										END, @ErrCode = 100
	END

	IF NOT EXISTS(
		SELECT TOP 1 1 FROM dbo.LicenseeGroupComm WITH (NOLOCK)
		WHERE LicenseeID = @LicenseeID AND	GroupName = @GroupName AND IsActive = 1
	)
	BEGIN
		IF @IsDefault=1
		BEGIN
			IF @IsResetDefault=0 AND EXISTS(SELECT TOP 1 1 FROM dbo.LicenseeGroupComm WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND  IsDefault=1 AND IsActive = 1 )
			BEGIN
				SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'Another group is currently set as default. Wanna set this group as default?'
													ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200018,@Langkey)
													END, @ErrCode = 102	
				RETURN
			END
			
			--Reset IsDefault Old to 0
			Update dbo.LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
			SET IsDefault=0 WHERE LicenseeID = @LicenseeID AND IsDefault=1
			
		END
		
		INSERT INTO dbo.LicenseeGroupComm (LicenseeID,GroupName,SBComm,NGComm,color,isDefault,RNGComm,ParlayComm
											,AllbetComm
											,MacauComm,PPComm
											--,GDComm,AGComm
											,FWComm
											,SexyGamingComm  
											,SpadeGamingComm  
											,KenoComm  
											,LotteryComm  
											,VSComm  
											,VS2Comm 
											,TableGameComm 
											
											,VirtualGamesComm 
											,ArcadiaGamingComm
											,SabaclubComm
											,SAGamingComm
											,PGSoftComm 
											--phase 4
											,WMCasinoComm
											,BigGamingComm
											,JokerComm
											,GDGComm
											,SportsLotteryComm
											,HabaneroComm
											,VGamingComm
											)
		VALUES (@LicenseeID,@GroupName,@SBComm,@NGComm,@GroupColor,@IsDefault,@RNGComm,@ParlayComm
				,@AllbetComm
				,@MacauComm,@PPComm
				--,@GDComm,@AGComm
				,@FWComm
				
				,@SexyGamingComm  
				,@SpadeGamingComm  
				,@KenoComm  
				,@LotteryComm  
				,@VSComm  
				,@VS2Comm 
				,@TableGameComm  
				
				,@VirtualGamesComm 
				,@ArcadiaGamingComm
				,@SabaclubComm
				,@SAGamingComm
				,@PGSoftComm
				-->phase 4
				,@WMCasinoComm		
				,@BigGamingComm		
				,@JokerComm			
				,@GDGComm			
				,@SportsLotteryComm	
				,@HabaneroComm
				,@VGamingComm		
				)
		
		IF (@@ERROR <> 0)
		BEGIN
			SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'Process create new group commission has been failed!'
									ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200019,@Langkey)
									END , @ErrCode = 101
		END	
		
		SELECT @GroupCommID = @@IDENTITY
		
		SELECT @GroupCommID = isnull(@GroupCommID,0)
		
		SET @endRun = GETDATE()
		SET @duration  = datediff (millisecond,@startRun,@endRun)	

		SELECT @LogSPData = '<Lrf_LicenseeGroupCommIns GroupCommID="'+ COALESCE(CAST(@GroupCommID as VARCHAR(50)),SPACE(1)) + '" ' +
		'LicenseeID="'+ COALESCE(CAST(@LicenseeID as VARCHAR(50)),SPACE(1)) + '" ' +
		'GroupName="'+ COALESCE(CAST(@GroupName as VARCHAR(100)),SPACE(1)) + '" ' +
		'SBComm="'+ COALESCE(CAST(@SBComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'NGComm="'+ COALESCE(CAST(@NGComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'RNGComm="'+ COALESCE(CAST(@RNGComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'ParlayComm="'+ COALESCE(CAST(@ParlayComm as VARCHAR(50)),SPACE(1)) + '" ' +	
		'AllbetComm="'+ COALESCE(CAST(@ALlbetComm as VARCHAR(50)),SPACE(1)) + '" ' +
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
		'TableGameComm="'+ COALESCE(CAST(@TableGameComm as VARCHAR(50)),SPACE(1)) + '" '+
		-- phase 3
		'VirtualGamesComm="'+ COALESCE(CAST(@VirtualGamesComm as VARCHAR(50)),SPACE(1)) + '" '+
		'ArcadiaGamingComm="'+ COALESCE(CAST(@ArcadiaGamingComm as VARCHAR(50)),SPACE(1)) + '" '+
		'SabaclubComm="'+ COALESCE(CAST(@SabaclubComm as VARCHAR(50)),SPACE(1)) + '" '+
		'SAGamingComm="'+ COALESCE(CAST(@SAGamingComm as VARCHAR(50)),SPACE(1)) + '" '+
		'PGSoftComm="'+ COALESCE(CAST(@PGSoftComm as VARCHAR(50)),SPACE(1)) + '" '+
		-->phase 4
		'WMCasinoComm="'+ COALESCE(CAST(@WMCasinoComm as VARCHAR(50)),SPACE(1)) + '" '+
		'BigGamingComm="'+ COALESCE(CAST(@BigGamingComm as VARCHAR(50)),SPACE(1)) + '" '+
		'JokerComm="'+ COALESCE(CAST(@JokerComm as VARCHAR(50)),SPACE(1)) + '" '+
		'GDGComm="'+ COALESCE(CAST(@GDGComm as VARCHAR(50)),SPACE(1)) + '" '+
		'SportsLotteryComm="'+ COALESCE(CAST(@SportsLotteryComm as VARCHAR(50)),SPACE(1)) + '" '+
		'HabaneroComm="'+ COALESCE(CAST(@HabaneroComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'VGamingComm="'+ COALESCE(CAST(@VGamingComm as VARCHAR(50)),SPACE(1)) + '" ' +
		
		'GroupColor="'+ COALESCE(CAST(@GroupColor as VARCHAR(40)),SPACE(1)) + '" ' +
		'IsDefault="'+ COALESCE(CAST(@IsDefault as VARCHAR(40)),SPACE(1)) + '" ' +
		'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
		'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
		'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
		'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'

		SELECT @TrackingValue2 = '<Lrf_LicenseeGroupCommIns GroupCommID="'+ COALESCE(CAST(@GroupCommID as VARCHAR(50)),SPACE(1)) + '" ' +
		'LicenseeID="'+ COALESCE(CAST(@LicenseeID as VARCHAR(50)),SPACE(1)) + '" ' +
		'GroupName="'+ COALESCE(CAST(@GroupName as VARCHAR(100)),SPACE(1)) + '" ' +
		'SBComm="'+ COALESCE(CAST(@SBComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'NGComm="'+ COALESCE(CAST(@NGComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'RNGComm="'+ COALESCE(CAST(@RNGComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'ParlayComm="'+ COALESCE(CAST(@ParlayComm as VARCHAR(50)),SPACE(1)) + '" ' +		
		'AllbetComm="'+ COALESCE(CAST(@ALlbetComm as VARCHAR(50)),SPACE(1)) + '" ' +
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
		-- phase 3
		'VirtualGamesComm="'+ COALESCE(CAST(@VirtualGamesComm as VARCHAR(50)),SPACE(1)) + '" '+
		'ArcadiaGamingComm="'+ COALESCE(CAST(@ArcadiaGamingComm as VARCHAR(50)),SPACE(1)) + '" '+
		'SabaclubComm="'+ COALESCE(CAST(@SabaclubComm as VARCHAR(50)),SPACE(1)) + '" '+
		'SAGamingComm="'+ COALESCE(CAST(@SAGamingComm as VARCHAR(50)),SPACE(1)) + '" '+
		'PGSoftComm="'+ COALESCE(CAST(@PGSoftComm as VARCHAR(50)),SPACE(1)) + '" '+
		-- phase 4
		'WMCasinoComm="'+ COALESCE(CAST(@WMCasinoComm as VARCHAR(50)),SPACE(1)) + '" '+
		'BigGamingComm="'+ COALESCE(CAST(@BigGamingComm as VARCHAR(50)),SPACE(1)) + '" '+
		'JokerComm="'+ COALESCE(CAST(@JokerComm as VARCHAR(50)),SPACE(1)) + '" '+
		'GDGComm="'+ COALESCE(CAST(@GDGComm as VARCHAR(50)),SPACE(1)) + '" '+
		'SportsLotteryComm="'+ COALESCE(CAST(@SportsLotteryComm as VARCHAR(50)),SPACE(1)) + '" '+
		'HabaneroComm="'+ COALESCE(CAST(@HabaneroComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'VGamingComm="'+ COALESCE(CAST(@VGamingComm as VARCHAR(50)),SPACE(1)) + '" ' +
		
		'GroupColor="'+ COALESCE(CAST(@GroupColor as VARCHAR(40)),SPACE(1)) + '" ' +
		'IsDefault="'+ COALESCE(CAST(@IsDefault as VARCHAR(40)),SPACE(1)) + '" ' +
		'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
		'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
		'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
		'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'				
		
		EXEC Lrf_WriteLog_UserLog_RunSP_Wrapper
					@UserID = @UserID,
					@CustID = @GroupCommID,
					@ActionID = 2609,
					@TrackingValue = @LogSPData,
					@TrackingValue2 = @TrackingValue2,
					@duration = @duration
		
	END
	ELSE
	BEGIN
		SELECT @ErrMsg =CASE @Langkey WHEN  'en-US' THEN 'This Group Name has been created before!'
									  ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200020,@Langkey)
									  END, @ErrCode = 102
	END
END
GO