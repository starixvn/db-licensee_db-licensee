/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet,bodbAdminNet,Dot_Member" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CustomerUpdMemberComm]
(
	@LicenseeID INT,
	@strCustID VARCHAR(MAX) = '',--member
	@UserID INT,
	@GroupCommID INT = 0,
	@SBComm DECIMAL(9,8)=0,
	@NGComm DECIMAL(9,8)=0,	
	@RNGComm DECIMAL(9,8)=0,
	@ParlayComm DECIMAL(9,8)=0,	
	@AllbetComm DECIMAL(9,8)=0,	
	@MacauComm DECIMAL(9,8)=0,	
	@PPComm DECIMAL(9,8)=0,	
	@IsUpdateSB BIT = 1,
	@IsParlayComm BIT = 1,
	@IsUpdateComm BIT=1,
	@IsUpdateNG BIT = 0,
	@IsUpdateRNG BIT = 0,	
	@IsUpdateAllbet BIT = 0,
	@IsUpdateMacau BIT = 0,
	@IsUpdatePP BIT = 0,
	@IsUpdateGroupComm BIT = 0,
	@isClearGroupComm BIT = 0,
	@ClearGroupCommGroupID INT = 0,
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
	@IsUpdateTableGame BIT = 0,	
	@TableGameComm DECIMAL(9,8) = 0,
	-- end of phase 2
	-- phase 3
	@IsUpdateVirtualGames BIT = 0,	
	@IsUpdateArcadiaGaming BIT = 0,	
	@IsUpdateSabaclub BIT = 0,	
	@IsUpdateSAGaming BIT = 0,	
	@IsUpdatePGSoft BIT = 0,	
	@VirtualGamesComm DECIMAL(9,8) = 0,	
	@ArcadiaGamingComm DECIMAL(9,8) = 0,	
	@SabaclubComm DECIMAL(9,8) = 0,	
	@SAGamingComm DECIMAL(9,8) = 0,	
	@PGSoftComm DECIMAL(9,8) = 0,	
	-->phase 4
	@IsUpdateWMCasino		BIT = 0,
	@IsUpdateBigGaming		BIT = 0,
	@IsUpdateJoker			BIT = 0,
	@IsUpdateHabanero		BIT = 0,
	@IsUpdateVgaming		BIT = 0,
	@IsUpdateCG				BIT = 0,
	@IsUpdateAdvant			BIT = 0,
	@IsUpdateAdvantMini		BIT = 0,
	@IsUpdateMaxGame		BIT = 0,
	@IsUpdateFGG			BIT = 0,
	@IsUpdateJili			BIT = 0,
	@WMCasinoComm		DECIMAL(9,8) = 0,
	@BigGamingComm		DECIMAL(9,8) = 0,
	@JokerComm			DECIMAL(9,8) = 0,
	@HabaneroComm		DECIMAL(9,8) = 0,
	@VGamingComm		DECIMAL(9,8) = 0,
	@CGComm				DECIMAL(9,8) = 0,
	@AdvantComm			DECIMAL(9,8) = 0,
	@AdvantMiniComm		DECIMAL(9,8) = 0,
	@MaxGameComm		DECIMAL(9,8) = 0,
	@FGGComm			DECIMAL(9,8) = 0,
	@JiliComm			DECIMAL(9,8) = 0,

	@IsUpdateYeeBet			BIT = 0,
	@IsUpdateMgRNG			BIT = 0,
	@YeeBetComm			DECIMAL(9,8) = 0,
	@MgRNGComm			DECIMAL(9,8) = 0,

	@IP VARCHAR(40),
	@Langkey VARCHAR(10) = 'en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(4000) = '' OUTPUT
)
AS
/*
	Created: 20120726@Henry
	Task : Update Commission of Player
	DB: DBCUST/bodb_licensee

	Revisions:
		- 20130124@Daniel: Change link server alias & failover writelog to DBTXN 
		- 20130413@Jim: support multi language
		- 20131023@Hannah: offer Live Casino commission
		- 20131126@Hannah: offer RNG Casino commission
		- 20131226@winnie: Change to DBTXN.CustDB
		- 20140612@Victor: fix VARCHAR(4000) issue
		- 20140618@Francis: Enhance performance
		- 20140618@Francis: Update Comm info and write logs using batch by batch in stead of row by row method
		- 20150513@Jim: force BA member get SB comm zero
		- 20151005@Jim:HotFix #45031
		- 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]	
		- 20171017@Johnson: offer Allbet commision [Redmine: #82036]
		- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
		- 20180704@Winnie:  LAP - There is a locking DB resource when doing 1st deposit many sessions at same time [Redmine: #97829]
		- 20180809@Sophia: HA - remove LicenseeCustInfo table [Redmine: #99464]
		- 20180809@Amanda: Remove Racing [RedmineID: #99378]
		- 20180827@Elodie: Change to use DBCUST.CustDB.dbo.Customer [Redmine: #99464]
		- 20180927@Winnie: Remove AllBet [RedmineID: #99378]
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
		- 20181205@Winnie: LAP-Security Risks found_settings [RedmineID: #105701]
		- 20200409@Johnson: Add comm for AB,Macau,PP,GD,AG [redmine:#131774]
		- 20200416@Max: Move Code Update LicenseeCustComm to Execrep SP [Redmine: #131774]
		- 20200511@Max: Add comm for FW, Remove AG, GD - [Redmine: #131774]
		- 20200518@Helen: Add comm for FW, Remove AG, GD - Tuning performance - [Redmine: #131774]
		- 20200701@Helen: Remove Allbet - [Redmine: #131774]
		- 20200814@Helen: LAP - Offer commission to 3rd party products - Phase 2 - [Redmine: #139238] 
		- 20201111@Helen: LAP - Offer commission to 3rd party products - Phase 3 - [Redmine: #145012] 
		- 20210603@Eden: LAP - Support commission for 3rd party products - Phase 4 [Redmine: #154048]   
		- 20210813@Johnson: Add VGaming [redmine: #159696]
		- 20211101@Winfred: Merge Sports Lottery under Sportsbook when turn on BA [redmine:#163191]
		- 20220112@Eden: LAP - RNG Casino - Implement DCS Settings [Redmine: #166217] 
		- 20220422@Winfred: LAP - Support commission for 3rd party products - Phase 4.2 [Redmine: #171586] 
		- 20220614@Eden: DBCUST - modify sp syntax to adapt with the SQL Server upgrade to 2019 [Redmine: #171831] 
		- 20221201@Tacy: Non-sports products - Remove GDG and Fishing World [RedmineID: #174511]
		- 20230313@Johnson: Add MaxGame, FGG, Jili Comm [redmine:#182922]
		- 20230804@Tacy: LAP - Offer Player Commission to Yeebet, MG-RNG [redmine: #192203]
		- 20230814@Luke: LAP - SEA Localization [Redmine: #187132]
		- 20240111@Tacy: LAP - Merge VS1, VS2, VS3 as Virtual Sports [Redmine: #199523]
		
	Param's Explanation:
		1. To update a member/batch members without GroupCommID
EXEC [Lrf_CustomerUpdMemberComm_907] @LicenseeID=xx,@strCustID,xx,@UserID=xx,@SBComm=xx,@NGComm=xx,@RNGComm=xx, @IsUpdateNG=xx,@IsUpdateRNG=xx,@IP=xx,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
		2. To update a member/batch members with GroupCommID
EXEC [Lrf_CustomerUpdMemberComm_907] @LicenseeID=xx,@strCustID,xx,@UserID=xx,@GroupCommID=xx,@SBComm=xx,@NGComm=xx,@RNGComm=xx,@IsUpdateNG=xx,@IsUpdateRNG=xx,@IP=xx,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
		3. To update member group without update commission
EXEC [Lrf_CustomerUpdMemberComm_907] @IsUpdateComm=0,@LicenseeID=xx,@strCustID,xx,@UserID=xx,@GroupCommID=xx,@SBComm=xx,@NGComm=xx,@RNGComm=xx,@IsUpdateNG=xx,@IsUpdateRNG=xx,@IP=xx,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @startRun DATETIME
	DECLARE @endRun DATETIME
	DECLARE @duration INT
	DECLARE	@GroupCommID_tmp INT
	DECLARE @CustID_Direct INT

	SET @startRun = GETDATE()

	DECLARE @TotalMemCount INT

	DECLARE @LogSPData VARCHAR(4000)
	DECLARE @LogSPData2 VARCHAR(4000)
	DECLARE @MacauLicenseeID INT

	SELECT  @MacauLicenseeID =  LicenseeID
	FROM dbo.Licensees WITH (NOLOCK)
	WHERE LicenseeName ='Macaubet'
		
	SELECT @strCustID = ltrim(rtrim(@strCustID))

	IF @strCustID = '' AND @IsUpdateGroupComm = 0
	BEGIN
		SELECT @ErrCode=101
		SELECT @ErrMsg = CASE @Langkey WHEN 'en-US'THEN 'Wrong input, please check again!'
										ELSE  CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200003,@Langkey)
						END 	
		RETURN
	END

	IF @GroupCommID>0 --Get SBComm,NGComm,RNGComm From Group
	BEGIN
		--Check existence
		IF NOT EXISTS (SELECT 1 FROM dbo.LicenseeGroupComm WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND id = @GroupCommID AND IsActive=1)
		BEGIN
			SELECT @ErrCode=101
			SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'The Group Commission does not exist, please check again!'
										   ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200001,@Langkey)		
										   END
			RETURN
		END
	
		SELECT @SBComm=SBComm
			,@NGComm=NGComm
			,@RNGComm=RNGComm
			,@ParlayComm= ParlayComm
			,@AllbetComm = AllbetComm
			,@MacauComm = MacauComm
			,@PPComm = PPComm
			-- phase 2
			,@SexyGamingComm  = SexyGamingComm 
			,@SpadeGamingComm  = SpadeGamingComm
			,@KenoComm  = KenoComm
			,@LotteryComm  = LotteryComm
			,@VSComm  = VSComm
			,@TableGameComm  = TableGameComm
			-- phase 3
			,@VirtualGamesComm = VirtualGamesComm	
			,@ArcadiaGamingComm = ArcadiaGamingComm	
			,@SabaclubComm = SabaclubComm
			,@SAGamingComm = SAGamingComm	
			,@PGSoftComm = PGSoftComm	
			--Phase 4
			,@WMCasinoComm		= WMCasinoComm
			,@BigGamingComm		= BigGamingComm
			,@JokerComm			= JokerComm
			,@HabaneroComm		= HabaneroComm
			,@VGamingComm		= VGamingComm
			--> phase 4.2
			,@CGComm			= CGComm
			,@AdvantComm		= AdvantComm
			,@AdvantMiniComm	= AdvantMiniComm
			
			,@MaxGameComm		= MaxGameComm
			,@FGGComm			= FGGComm
			,@JiliComm			= JiliComm

			,@YeeBetComm		= YeeBetComm
			,@MgRNGComm			= MgRNGComm
		FROM dbo.LicenseeGroupComm WITH (NOLOCK)
		WHERE LicenseeID = @LicenseeID AND id = @GroupCommID AND IsActive=1
	END

	SELECT @SBComm=ISNULL(@SBComm,0)
		,@NGComm=ISNULL(@NGComm,0)
		,@RNGComm=ISNULL(@RNGComm,0)
		,@ParlayComm = ISNULL(@ParlayComm,0)
		,@AllbetComm = ISNULL(@AllbetComm,0)
		,@MacauComm = ISNULL(@MacauComm,0)
		,@PPComm = ISNULL(@PPComm,0)
		-- phase 2
		,@SexyGamingComm  =  ISNULL (@SexyGamingComm, 0)
		,@SpadeGamingComm  = ISNULL (@SpadeGamingComm, 0)
		,@KenoComm  = ISNULL (@KenoComm, 0)
		,@LotteryComm  = ISNULL (@LotteryComm, 0)
		,@VSComm  = ISNULL (@VSComm, 0)
		,@TableGameComm  = ISNULL (@TableGameComm, 0)
		-- phase 3
		,@VirtualGamesComm = ISNULL(@VirtualGamesComm,0)	
		,@ArcadiaGamingComm = ISNULL(@ArcadiaGamingComm,0)
		,@SabaclubComm = ISNULL(@SabaclubComm,0)
		,@SAGamingComm = ISNULL(@SAGamingComm,0)	
		,@PGSoftComm = ISNULL(@PGSoftComm,0)	
		-- phase 4
		,@WMCasinoComm = ISNULL(@WMCasinoComm,0)	
		,@BigGamingComm = ISNULL(@BigGamingComm,0)
		,@JokerComm = ISNULL(@JokerComm,0)
		,@HabaneroComm = ISNULL(@HabaneroComm,0)
		,@VGamingComm = ISNULL(@VGamingComm,0)
		,@CGComm = ISNULL(@CGComm,0)
		,@AdvantComm	 = ISNULL(@AdvantComm	,0)
		,@AdvantMiniComm = ISNULL(@AdvantMiniComm,0)
		
		,@MaxGameComm = ISNULL(@MaxGameComm,0)
		,@FGGComm = ISNULL(@FGGComm,0)
		,@JiliComm = ISNULL(@JiliComm,0)

		,@YeeBetComm = ISNULL(@YeeBetComm,0)
		,@MgRNGComm = ISNULL(@MgRNGComm,0)

	--Validate data
	IF @SBComm>0.15 OR @NGComm>0.15 OR @RNGComm>0.15 OR @ParlayComm > 0.15
		OR @AllbetComm > 0.15 
		OR @MacauComm > 0.15 OR @PPComm > 0.15 
		--OR @GDComm > 0.15 OR @AGComm > 0.15
		OR @SexyGamingComm  > 0.15
		OR @SpadeGamingComm  > 0.15
		OR @KenoComm  > 0.15
		OR @LotteryComm  > 0.15
		OR @VSComm  > 0.15
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
		OR @HabaneroComm > 0.15
		OR @VGamingComm > 0.15
		--> phase 4.2
		OR @CGComm > 0.15
		OR @AdvantComm > 0.15
		OR @AdvantMiniComm > 0.15
		
		OR @MaxGameComm > 0.15
		OR @FGGComm > 0.15
		OR @JiliComm > 0.15

		OR @YeeBetComm > 0.15
		OR @MgRNGComm > 0.15
	BEGIN
		SELECT @ErrCode=101
		SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN 'Player commission should not be greater than'
										ELSE 	CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200002,@Langkey)
										END +' 0.15'
		RETURN
	END
	
	DECLARE @TempLicenseeBA AS TABLE (CustID INT)
	
	DECLARE @TempCustID AS TABLE (CustID INT,IsFinished BIT)
	DECLARE @TempList_batch AS TABLE (CustID INT)
	
	IF @isClearGroupComm = 1
		SET @GroupCommID_tmp = @ClearGroupCommGroupID
	ELSE
		SET @GroupCommID_tmp = @GroupCommID
			
	IF @IsUpdateGroupComm = 1 AND @strCustID = ''
	BEGIN
		INSERT INTO @TempCustID (CustID)
		SELECT ls.custid
		FROM LicenseeCustComm ls WITH (NOLOCK)
			INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON ls.CustID = c.custid
		WHERE ls.LicenseeID = @LicenseeID AND ls.GroupCommID = @GroupCommID_tmp
		
		SELECT @TotalMemCount=@@ROWCOUNT
		
	END
	ELSE IF @strCustID <> ''
	BEGIN
		INSERT INTO @TempCustID (CustID)
		SELECT c.CustID
		FROM CustDB.dbo.Customer c WITH (NOLOCK) 
			INNER JOIN STRING_SPLIT (@strCustID,',') AS tmp ON RTRIM(LTRIM(tmp.value)) = c.custid
		
		SELECT @TotalMemCount=@@ROWCOUNT
		
	END
	
	--Call execrep to update player commission
	IF @IsUpdateComm=1
	BEGIN
		IF @TotalMemCount=1
		BEGIN
			SET @CustID_Direct =  (SELECT TOP 1 CustID FROM @TempCustID)
			
			EXEC CustDB.dbo.[Lrf_CustomerUpdMemberComm_Direct] 
				@CustID=@CustID_Direct
				,@SBComm=@SBComm
				,@NGComm=@NGComm
				,@ParlayComm = @ParlayComm
				,@AllbetComm=@AllbetComm	
				,@MacauComm=@MacauComm
				,@PPComm=@PPComm
				,@IsUpdateSB = @IsUpdateSB
				,@IsParlayComm = @IsParlayComm
				,@IsUpdateNG=@IsUpdateNG			
				,@IsUpdateAllbet=@IsUpdateAllbet
				,@IsUpdateMacau=@IsUpdateMacau	
				,@IsUpdatePP=@IsUpdatePP	
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
				,@IsUpdateTableGame = @IsUpdateTableGame
				,@TableGameComm = @TableGameComm
				---end of phase 2
				-- phase 3
				,@IsUpdateVirtualGames = @IsUpdateVirtualGames
				,@IsUpdateArcadiaGaming = @IsUpdateArcadiaGaming
				,@IsUpdateSabaclub  = @IsUpdateSabaclub
				,@IsUpdateSAGaming  = @IsUpdateSAGaming
				,@IsUpdatePGSoft  = @IsUpdatePGSoft
				,@VirtualGamesComm = @VirtualGamesComm
				,@ArcadiaGamingComm = @ArcadiaGamingComm
				,@SabaclubComm = @SabaclubComm
				,@SAGamingComm = @SAGamingComm
				,@PGSoftComm = @PGSoftComm
				--> phase 4
				,@IsUpdateWMCasino		= @IsUpdateWMCasino		
				,@IsUpdateBigGaming		= @IsUpdateBigGaming		
				,@IsUpdateJoker			= @IsUpdateJoker			
				,@IsUpdateHabanero		= @IsUpdateHabanero	
				,@IsUpdateVGaming		= @IsUpdateVGaming	
				,@IsUpdateCG			= @IsUpdateCG			
				,@IsUpdateAdvant		= @IsUpdateAdvant		
				,@IsUpdateAdvantMini	= @IsUpdateAdvantMini		
				,@WMCasinoComm				= @WMCasinoComm		
				,@BigGamingComm				= @BigGamingComm		
				,@JokerComm					= @JokerComm			
				,@HabaneroComm				= @HabaneroComm		
				,@VGamingComm				= @VGamingComm
				--Saba Casino
				,@IsUpdateSabaCasino = @IsUpdateRNG
				,@SabaCasinoComm = @RNGComm
				,@CGComm					= @CGComm		
				,@AdvantComm				= @AdvantComm		
				,@AdvantMiniComm			= @AdvantMiniComm		
				
				,@IsUpdateMaxGame			= @IsUpdateMaxGame
				,@IsUpdateFGG				= @IsUpdateFGG
				,@IsUpdateJili				= @IsUpdateJili
				,@MaxGameComm				= @MaxGameComm				
				,@FGGComm					= @FGGComm
				,@JiliComm					= @JiliComm

				,@IsUpdateYeeBet			= @IsUpdateYeeBet
				,@IsUpdateMgRNG				= @IsUpdateMgRNG
				,@YeeBetComm				= @YeeBetComm				
				,@MgRNGComm					= @MgRNGComm
		END		
		ELSE
		BEGIN	
			--- separate BA member with Non-BA
			--BA and not belong Macaubet have got SBcomm=0	
			
			DECLARE @strBA 	VARCHAR(MAX)
			
			IF @LicenseeID <> @MacauLicenseeID
			BEGIN 
				INSERT INTO @TempLicenseeBA (CustID)
				SELECT t.CustID 
				FROM @TempCustID  t
					INNER JOIN dbo.LicenseeBAHistory ba WITH (NOLOCK) ON t.CustID=ba.CustID
				WHERE ba.Status ='Running' AND ba.LicenseeID = @LicenseeID 
				ORDER BY t.[CustID]
			END	 
				 
			SELECT @strBA = STUFF((SELECT ',' + CAST(CustID AS VARCHAR(20))
							FROM @TempLicenseeBA
							FOR XML PATH('')
							),1,1,'')
			IF @strBA  <> ''
			BEGIN				
				EXEC CustDB.dbo.[Lrf_CustomerUpdMemberComm_Main] 
					@strCustID=@strBA
					,@SBComm=0
					,@NGComm=@NGComm
					,@ParlayComm = 0	
					,@AllbetComm = @AllbetComm
					,@MacauComm = @MacauComm
					,@PPComm = @PPComm
					,@IsUpdateSB = @IsUpdateSB
					,@IsParlayComm = @IsParlayComm
					,@IsUpdateNG=@IsUpdateNG
					,@IsUpdateAllbet=@IsUpdateAllbet
					,@IsUpdateMacau=@IsUpdateMacau
					,@IsUpdatePP=@IsUpdatePP
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
					,@IsUpdateTableGame = @IsUpdateTableGame
					,@TableGameComm = @TableGameComm
					---end of phase 2
					-- phase 3
					,@IsUpdateVirtualGames = @IsUpdateVirtualGames
					,@IsUpdateArcadiaGaming = @IsUpdateArcadiaGaming
					,@IsUpdateSabaclub  = @IsUpdateSabaclub
					,@IsUpdateSAGaming  = @IsUpdateSAGaming
					,@IsUpdatePGSoft  = @IsUpdatePGSoft
					,@VirtualGamesComm = @VirtualGamesComm
					,@ArcadiaGamingComm = @ArcadiaGamingComm
					,@SabaclubComm = @SabaclubComm
					,@SAGamingComm = @SAGamingComm
					,@PGSoftComm = @PGSoftComm
					--> phase 4
					,@IsUpdateWMCasino		= @IsUpdateWMCasino		
					,@IsUpdateBigGaming		= @IsUpdateBigGaming		
					,@IsUpdateJoker			= @IsUpdateJoker			
					,@IsUpdateHabanero		= @IsUpdateHabanero		
					,@IsUpdateVGaming		= @IsUpdateVGaming	
					,@IsUpdateCG			= @IsUpdateCG			
					,@IsUpdateAdvant		= @IsUpdateAdvant		
					,@IsUpdateAdvantMini	= @IsUpdateAdvantMini		
					,@IsUpdateMaxGame		= @IsUpdateMaxGame	
					,@IsUpdateFGG			= @IsUpdateFGG	
					,@IsUpdateJili			= @IsUpdateJili
					,@WMCasinoComm				= @WMCasinoComm		
					,@BigGamingComm				= @BigGamingComm		
					,@JokerComm					= @JokerComm			
					,@HabaneroComm				= @HabaneroComm
					,@VGamingComm				= @VGamingComm	
					--Saba Casino
					,@IsUpdateSabaCasino = @IsUpdateRNG
					,@SabaCasinoComm = @RNGComm			
					,@CGComm					= @CGComm		
					,@AdvantComm				= @AdvantComm		
					,@AdvantMiniComm			= @AdvantMiniComm		
					,@MaxGameComm				= @MaxGameComm					
					,@FGGComm					= @FGGComm
					,@JiliComm					= @JiliComm

					,@IsUpdateYeeBet			= @IsUpdateYeeBet
					,@IsUpdateMgRNG				= @IsUpdateMgRNG
					,@YeeBetComm				= @YeeBetComm				
					,@MgRNGComm					= @MgRNGComm
			END					
			-- Non-BA and BA under Macaubet have got SBcomm=@SBcomm
			DECLARE  @strNonBA 	VARCHAR(MAX)
			
			SELECT @strNonBA = STUFF((SELECT ',' + CAST(t.[CustID] AS VARCHAR(20))
								FROM @TempCustID  t
									LEFT JOIN @TempLicenseeBA ba ON t.CustID = ba.CustID
								WHERE ba.CustID IS NULL
								ORDER BY t.[CustID]
								FOR XML PATH('')
							),1,1,'')
			
			IF @strNonBA  <> ''
			BEGIN
				EXEC CustDB.dbo.[Lrf_CustomerUpdMemberComm_Main] 
					@strCustID=@strNonBA
					,@SBComm=@SBComm
					,@NGComm=@NGComm
					,@ParlayComm = @ParlayComm					
					,@AllbetComm = @AllbetComm
					,@MacauComm = @MacauComm
					,@PPComm = @PPComm
					,@IsUpdateSB = @IsUpdateSB
					,@IsParlayComm = @IsParlayComm
					,@IsUpdateNG=@IsUpdateNG
					,@IsUpdateAllbet=@IsUpdateAllbet
					,@IsUpdateMacau=@IsUpdateMacau
					,@IsUpdatePP=@IsUpdatePP
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
					,@IsUpdateTableGame = @IsUpdateTableGame
					,@TableGameComm = @TableGameComm
					---end of phase 2
					-- phase 3
					,@IsUpdateVirtualGames = @IsUpdateVirtualGames
					,@IsUpdateArcadiaGaming = @IsUpdateArcadiaGaming
					,@IsUpdateSabaclub  = @IsUpdateSabaclub
					,@IsUpdateSAGaming  = @IsUpdateSAGaming
					,@IsUpdatePGSoft  = @IsUpdatePGSoft
					,@VirtualGamesComm = @VirtualGamesComm
					,@ArcadiaGamingComm = @ArcadiaGamingComm
					,@SabaclubComm = @SabaclubComm
					,@SAGamingComm = @SAGamingComm
					,@PGSoftComm = @PGSoftComm
					--> phase 4
					,@IsUpdateWMCasino		= @IsUpdateWMCasino		
					,@IsUpdateBigGaming		= @IsUpdateBigGaming		
					,@IsUpdateJoker			= @IsUpdateJoker			
					,@IsUpdateHabanero		= @IsUpdateHabanero	
					,@IsUpdateVGaming		= @IsUpdateVGaming		
					,@IsUpdateCG			= @IsUpdateCG			
					,@IsUpdateAdvant		= @IsUpdateAdvant		
					,@IsUpdateAdvantMini	= @IsUpdateAdvantMini		
					,@WMCasinoComm				= @WMCasinoComm		
					,@BigGamingComm				= @BigGamingComm		
					,@JokerComm					= @JokerComm			
					,@HabaneroComm				= @HabaneroComm
					,@VGamingComm				= @VGamingComm	
					--Saba Casino
					,@IsUpdateSabaCasino = @IsUpdateRNG
					,@SabaCasinoComm = @RNGComm					
					,@CGComm					= @CGComm		
					,@AdvantComm				= @AdvantComm		
					,@AdvantMiniComm			= @AdvantMiniComm		
					
					,@IsUpdateMaxGame		= @IsUpdateMaxGame	
					,@IsUpdateFGG			= @IsUpdateFGG	
					,@IsUpdateJili			= @IsUpdateJili					
					,@MaxGameComm			= @MaxGameComm					
					,@FGGComm				= @FGGComm
					,@JiliComm				= @JiliComm

					,@IsUpdateYeeBet			= @IsUpdateYeeBet
					,@IsUpdateMgRNG				= @IsUpdateMgRNG
					,@YeeBetComm				= @YeeBetComm				
					,@MgRNGComm					= @MgRNGComm
			END
		END
	END	
	
	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF (millisecond,@startRun,@endRun)	

	--Write Log
	-- new value
	SELECT @LogSPData = 'GroupCommID="'+ COALESCE(CAST(@GroupCommID as VARCHAR(50)),SPACE(1)) + '" ' +
		'LicenseeID="'+ COALESCE(CAST(@LicenseeID as VARCHAR(50)),SPACE(1)) + '" ' +
		'SBComm="'+ COALESCE(CAST(@SBComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'NGComm="'+ COALESCE(CAST(@NGComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'RNGComm="'+ COALESCE(CAST(@RNGComm as VARCHAR(50)),SPACE(1)) + '" '+
		'ParlayComm="'+ COALESCE(CAST(@ParlayComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'AllbetComm="'+ COALESCE(CAST(@AllbetComm as VARCHAR(50)),SPACE(1)) + '" '+
		'MacauComm="'+ COALESCE(CAST(@MacauComm as VARCHAR(50)),SPACE(1)) + '" '+
		'PPComm="'+ COALESCE(CAST(@PPComm as VARCHAR(50)),SPACE(1)) + '" '+
		-- phase 2
		'SexyGamingComm="'+ COALESCE(CAST(@SexyGamingComm as VARCHAR(50)),SPACE(1)) + '" '+
		'SpadeGamingComm="'+ COALESCE(CAST(@SpadeGamingComm as VARCHAR(50)),SPACE(1)) + '" '+
		'KenoComm="'+ COALESCE(CAST(@KenoComm as VARCHAR(50)),SPACE(1)) + '" '+
		'LotteryComm="'+ COALESCE(CAST(@LotteryComm as VARCHAR(50)),SPACE(1)) + '" '+
		'VSComm="'+ COALESCE(CAST(@VSComm as VARCHAR(50)),SPACE(1)) + '" '+
		'TableGameComm="'+ COALESCE(CAST(@TableGameComm as VARCHAR(50)),SPACE(1)) + '" '+
		-- phase 3
		'VirtualGamesComm="'+ COALESCE(CAST(@VirtualGamesComm as VARCHAR(50)),SPACE(1)) + '" '+
		'ArcadiaGamingComm="'+ COALESCE(CAST(@ArcadiaGamingComm as VARCHAR(50)),SPACE(1)) + '" '+
		'SabaclubComm="'+ COALESCE(CAST(@SabaclubComm as VARCHAR(50)),SPACE(1)) + '" '+
		'SAGamingComm="'+ COALESCE(CAST(@SAGamingComm as VARCHAR(50)),SPACE(1)) + '" '+
		'PGSoftComm="'+ COALESCE(CAST(@PGSoftComm as VARCHAR(50)),SPACE(1)) + '" ' +
		-- phase 4
		'WMCasinoComm="'+ COALESCE(CAST(@WMCasinoComm as VARCHAR(50)),SPACE(1)) + '" '+
		'BigGamingComm="'+ COALESCE(CAST(@BigGamingComm as VARCHAR(50)),SPACE(1)) + '" '+
		'JokerComm="'+ COALESCE(CAST(@JokerComm as VARCHAR(50)),SPACE(1)) + '" '+
		'HabaneroComm="'+ COALESCE(CAST(@HabaneroComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'VGamingComm="'+ COALESCE(CAST(@VGamingComm as VARCHAR(50)),SPACE(1)) + '" ' +
		-- phase 4.2
		'CGComm="'+ COALESCE(CAST(@CGComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'AdvantComm="'+ COALESCE(CAST(@AdvantComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'AdvantMiniComm="'+ COALESCE(CAST(@AdvantMiniComm as VARCHAR(50)),SPACE(1)) + '" ' +
		
		'MaxGameComm="'+ COALESCE(CAST(@MaxGameComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'FGGComm="'+ COALESCE(CAST(@FGGComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'JiliComm="'+ COALESCE(CAST(@JiliComm as VARCHAR(50)),SPACE(1)) + '" ' +

		'YeeBetComm="'+ COALESCE(CAST(@YeeBetComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'MgRNGComm="'+ COALESCE(CAST(@MgRNGComm as VARCHAR(50)),SPACE(1)) + '" ' 

	-- old value
	SELECT @LogSPData2 = 'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
		'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
		'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'
	
	DECLARE @runningCNT INT = 0
	WHILE (1=1)
	BEGIN
		SELECT @runningCNT = @runningCNT + 1

		DELETE FROM @TempList_batch
		
		UPDATE TOP (1000) t
			SET IsFinished = 1
		OUTPUT deleted.CustID 
		INTO @TempList_batch (custID)
		FROM @TempCustID t
		WHERE IsFinished IS NULL
		
		--Check empty batches
		IF (@@ROWCOUNT = 0)
			BREAK

		SET @strCustID = STUFF((SELECT ',' + CAST(custid AS VARCHAR(20))
						FROM @TempList_batch
						FOR XML PATH('')
						),1,1,'')
		---------- write log for servicebroker
		DECLARE @log xml, @SB_Error BIT = 0, @currentdate DATETIME = GETDATE ()
		SELECT @log = (
					SELECT a.CustID AS '@CustID'
							, @UserID AS	'@UserID'	
							, 2612 '@ActionID'
							--TrackingValue
							, '<Lrf_CustomerUpdMemberComm custid="'+ COALESCE(CAST(a.CustID as VARCHAR(50)),SPACE(1)) + '" ' + 
						   @LogSPData +  
						   'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
						   @LogSPData2 AS '@TrackingValue'
						   --TrackingValue2
						   ,'<Lrf_CustomerUpdMemberComm custid="'+ COALESCE(CAST(a.CustID as VARCHAR(50)),SPACE(1)) + '" ' +
						   'GroupCommID="'+ COALESCE(CAST(ISNULL(lcc.GroupCommID,0) as VARCHAR(50)),SPACE(1)) + '" ' +
						   'LicenseeID="'+ COALESCE(CAST(ISNULL(lcc.LicenseeID,0) as VARCHAR(50)),SPACE(1)) + '" ' +
						   'SBComm="'+ COALESCE(CAST(ISNULL(lcc.SBComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
						   'ParlayComm="'+ COALESCE(CAST(ISNULL(lcc.ParlayComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
						   'NGComm="'+ COALESCE(CAST(ISNULL(lcc.NGComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
						   --'LCComm="'+ COALESCE(CAST(ISNULL(lcc.LCComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
						   'RNGComm="'+ COALESCE(CAST(ISNULL(lcc.RNGComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +			 
						   'AllbetComm="'+ COALESCE(CAST(ISNULL(lcc.AllbetComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
						   'MacauComm="'+ COALESCE(CAST(ISNULL(lcc.MacauComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
						   'PPComm="'+ COALESCE(CAST(ISNULL(lcc.PPComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
						    -- phase 2
							'SexyGamingComm="'+ COALESCE(CAST(ISNULL(lcc.SexyGamingComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
							'SpadeGamingComm="'+ COALESCE(CAST(ISNULL(lcc.SpadeGamingComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
							'KenoComm="'+ COALESCE(CAST(ISNULL(lcc.KenoComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
							'LotteryComm="'+ COALESCE(CAST(ISNULL(lcc.LotteryComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
							'VSComm="'+ COALESCE(CAST(ISNULL(lcc.VSComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
							'TableGameComm="'+ COALESCE(CAST(ISNULL(lcc.TableGameComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
							-- phase 3
							'VirtualGamesComm="'+ COALESCE(CAST(ISNULL(lcc.VirtualGamesComm,0) as VARCHAR(50)),SPACE(1)) + '" '+
							'ArcadiaGamingComm="'+ COALESCE(CAST(ISNULL(lcc.ArcadiaGamingComm,0) as VARCHAR(50)),SPACE(1)) + '" '+
							'SabaclubComm="'+ COALESCE(CAST(ISNULL(lcc.SabaclubComm,0) as VARCHAR(50)),SPACE(1)) + '" '+
							'SAGamingComm="'+ COALESCE(CAST(ISNULL(lcc.SAGamingComm,0) as VARCHAR(50)),SPACE(1)) + '" '+
							'PGSoftComm="'+ COALESCE(CAST(ISNULL(lcc.PGSoftComm,0) as VARCHAR(50)),SPACE(1)) + '" '+
							-- phase 4
							'WMCasinoComm="'+ COALESCE(CAST(ISNULL(lcc.WMCasinoComm,0) as VARCHAR(50)),SPACE(1)) + '" '+
							'BigGamingComm="'+ COALESCE(CAST(ISNULL(lcc.BigGamingComm,0) as VARCHAR(50)),SPACE(1)) + '" '+
							'JokerComm="'+ COALESCE(CAST(ISNULL(lcc.JokerComm,0) as VARCHAR(50)),SPACE(1)) + '" '+
							'HabaneroComm="'+ COALESCE(CAST(ISNULL(lcc.HabaneroComm,0) as VARCHAR(50)),SPACE(1)) + '" '+
							'VGamingComm="'+ COALESCE(CAST(ISNULL(lcc.VGamingComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
							-- phase 4.2
							'CGComm="'+ COALESCE(CAST(ISNULL(lcc.CGComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
							'AdvantComm="'+ COALESCE(CAST(ISNULL(lcc.AdvantComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
							'AdvantMiniComm="'+ COALESCE(CAST(ISNULL(lcc.AdvantMiniComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +

							'MaxGameComm="'+ COALESCE(CAST(ISNULL(lcc.MaxGameComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
							'FGGComm="'+ COALESCE(CAST(ISNULL(lcc.FGGComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
							'JiliComm="'+ COALESCE(CAST(ISNULL(lcc.JiliComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +

							'YeeBetComm="'+ COALESCE(CAST(ISNULL(lcc.YeeBetComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
							'MgRNGComm="'+ COALESCE(CAST(ISNULL(lcc.MgRNGComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +

						   'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
						   @LogSPData2 AS '@TrackingValue2'
						   , @currentdate AS '@LogDate'
						   , @duration AS '@Duration'
						   
					FROM @TempList_batch a
						LEFT JOIN dbo.LicenseeCustComm lcc WITH (NOLOCK) ON a.CustID = lcc.CustID
					FOR XML PATH('Row')	
					)
	
		EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @log, 
													@MessageType='MessageType_CustomerLog_UserLog_RunSP', 
													@functionName = 'UserLog_Others',
													@SB_Error = @SB_Error OUT


		--SELECT @SB_Error
		IF @SB_Error = 1
		BEGIN
			BEGIN TRY
			
				EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_UpdMemComm_RunSP
							@UserID = @UserID,
							@strCustID = @strCustID,
							@ActionID = 2612,
							@LogSPData = @LogSPData,
							@LogSPData2 = @LogSPData2,
							@duration = @duration
			END TRY
			BEGIN CATCH
				EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_UpdMemComm_RunSP
							@UserID = @UserID,
							@strCustID = @strCustID,
							@ActionID = 2612,
							@LogSPData = @LogSPData,
							@LogSPData2 = @LogSPData2,
							@duration = @duration
			END CATCH
		END
		
		--Update LicenseeCustComm
		IF (@IsUpdateComm = 1)
		BEGIN
			BEGIN TRY
			
			EXEC dbo.Lrf_ExecRep_00
					@strCustId = @strCustID,
					@LicenseeID = @LicenseeID,
					@GroupCommID = @GroupCommID,
					@MacauLicenseeID = @MacauLicenseeID,
					@IsUpdateNG = @IsUpdateNG,
					@IsUpdateRNG = @IsUpdateRNG,	
					@IsUpdateAllbet = @IsUpdateAllbet,
					@IsUpdateMacau = @IsUpdateMacau,
					@IsUpdatePP = @IsUpdatePP,
					@SBComm = @SBComm,
					@NGComm = @NGComm,	
					@RNGComm = @RNGComm,
					@ParlayComm = @ParlayComm,	
					@AllbetComm = @AllbetComm,	
					@MacauComm = @MacauComm,	
					@PPComm = @PPComm,	
					@IsUpdateGroupComm = @IsUpdateGroupComm
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
					,@IsUpdateTableGame = @IsUpdateTableGame
					,@TableGameComm = @TableGameComm
					-------end of phase 2
					-- phase 3
					,@IsUpdateVirtualGames = @IsUpdateVirtualGames
					,@IsUpdateArcadiaGaming = @IsUpdateArcadiaGaming
					,@IsUpdateSabaclub  = @IsUpdateSabaclub
					,@IsUpdateSAGaming  = @IsUpdateSAGaming
					,@IsUpdatePGSoft  = @IsUpdatePGSoft
					,@VirtualGamesComm = @VirtualGamesComm
					,@ArcadiaGamingComm = @ArcadiaGamingComm
					,@SabaclubComm = @SabaclubComm
					,@SAGamingComm = @SAGamingComm
					,@PGSoftComm = @PGSoftComm
					--> phase 4
					,@IsUpdateWMCasino		= @IsUpdateWMCasino		
					,@IsUpdateBigGaming		= @IsUpdateBigGaming		
					,@IsUpdateJoker			= @IsUpdateJoker			
					,@IsUpdateHabanero		= @IsUpdateHabanero		
					,@IsUpdateVGaming		= @IsUpdateVGaming	
					,@IsUpdateCG			= @IsUpdateCG			
					,@IsUpdateAdvant		= @IsUpdateAdvant		
					,@IsUpdateAdvantMini	= @IsUpdateAdvantMini		
					,@WMCasinoComm				= @WMCasinoComm		
					,@BigGamingComm				= @BigGamingComm		
					,@JokerComm					= @JokerComm			
					,@HabaneroComm				= @HabaneroComm	
					,@VGamingComm				= @VGamingComm
					--> phase 4.2
					,@CGComm					= @CGComm		
					,@AdvantComm				= @AdvantComm		
					,@AdvantMiniComm			= @AdvantMiniComm		

					,@MaxGameComm				= @MaxGameComm
					,@FGGComm					= @FGGComm
					,@JiliComm					= @JiliComm
					,@IsUpdateMaxGame			= @IsUpdateMaxGame
					,@IsUpdateFGG				= @IsUpdateFGG
					,@IsUpdateJili				= @IsUpdateJili

					,@IsUpdateYeeBet			= @IsUpdateYeeBet
					,@IsUpdateMgRNG				= @IsUpdateMgRNG
					,@YeeBetComm				= @YeeBetComm				
					,@MgRNGComm					= @MgRNGComm
			END TRY
			BEGIN CATCH
				SELECT @ErrCode = ERROR_NUMBER()
					, @ErrMsg = ERROR_MESSAGE()
			END CATCH
			
		END
		IF @runningCNT % 5 = 0 
			WAITFOR DELAY '00:00:00.280'
		
	END	
END

