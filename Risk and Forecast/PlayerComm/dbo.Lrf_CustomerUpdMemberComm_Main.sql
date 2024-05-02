/*<info serverAlias="DBCUST-CustDB" executers="wsv_lap,wsv_nap,svc_tig" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CustomerUpdMemberComm_Main] 
	@strCustID VARCHAR(MAX)
	,@SBComm DECIMAL(9,8)
	,@NGComm DECIMAL(9,8) = 0
	,@ParlayComm DECIMAL(9,8) = 0
	,@AllbetComm DECIMAL(9,8) = 0
	,@MacauComm DECIMAL(9,8) = 0
	,@PPComm DECIMAL(9,8) = 0
	,@IsUpdateSB BIT = 1
	,@IsParlayComm BIT = 1
	,@IsUpdateNG BIT = 0
	,@IsUpdateAllbet BIT = 0
	,@IsUpdateMacau BIT = 0
	,@IsUpdatePP BIT = 0
	--start param of phase 2 
	,@IsUpdateSexyGaming BIT = 0	
	,@SexyGamingComm DECIMAL(9,8) = 0
	,@IsUpdateSpadeGaming BIT = 0	
	,@SpadeGamingComm DECIMAL(9,8) = 0
	,@IsUpdateKeno BIT = 0	
	,@KenoComm DECIMAL(9,8) = 0
	,@IsUpdateLottery BIT = 0	
	,@LotteryComm DECIMAL(9,8) = 0
	,@IsUpdateVS BIT = 0	
	,@VSComm DECIMAL(9,8) = 0
	,@IsUpdateTableGame BIT = 0	
	,@TableGameComm DECIMAL(9,8) = 0
	
	-- param of phase 3
	,@IsUpdateVirtualGames BIT = 0
	,@IsUpdateArcadiaGaming BIT = 0
	,@IsUpdateSabaclub BIT = 0
	,@IsUpdateSAGaming BIT = 0
	,@IsUpdatePGSoft BIT = 0
	,@VirtualGamesComm DECIMAL(9,8) = 0
	,@ArcadiaGamingComm DECIMAL(9,8) = 0
	,@SabaclubComm DECIMAL(9,8) = 0
	,@SAGamingComm DECIMAL(9,8) = 0
	,@PGSoftComm DECIMAL(9,8) = 0
	-->phase 4
	,@IsUpdateWMCasino		BIT = 0
	,@IsUpdateBigGaming		BIT = 0
	,@IsUpdateJoker			BIT = 0
	,@IsUpdateHabanero		BIT = 0
	,@IsUpdateVGaming 		BIT = 0
	-- phase 4.2
	,@IsUpdateCG			BIT = 0
	,@IsUpdateAdvant		BIT = 0
	,@IsUpdateAdvantMini	BIT = 0
	,@WMCasinoComm		DECIMAL(9,8) = 0
	,@BigGamingComm		DECIMAL(9,8) = 0
	,@JokerComm			DECIMAL(9,8) = 0
	,@HabaneroComm		DECIMAL(9,8) = 0
	,@VGamingComm		DECIMAL(9,8) = 0
	,@IsUpdateSabaCasino	BIT = 0
	,@SabaCasinoComm		DECIMAL(9,8) = 0
	,@CGComm			DECIMAL(9,8) = 0
	,@AdvantComm		DECIMAL(9,8) = 0
	,@AdvantMiniComm	DECIMAL(9,8) = 0
	
	,@IsUpdateMaxGame	BIT = 0
	,@IsUpdateFGG		BIT = 0
	,@IsUpdateJili		BIT = 0
	,@MaxGameComm		DECIMAL(9,8) = 0
	,@FGGComm			DECIMAL(9,8) = 0
	,@JiliComm			DECIMAL(9,8) = 0

	,@IsUpdateYeeBet	BIT = 0
	,@IsUpdateMgRNG		BIT = 0
	,@YeeBetComm		DECIMAL(9,8) = 0
	,@MgRNGComm			DECIMAL(9,8) = 0
AS
/*
	Created: 20120907@Viet
	Task : Update Licensee's players commission in DBCUST
	DB: DBCUST/CustDB
	Original: 

	Revisions:
		- 20131023@Hannah: offer Live Casino commission
		- 20140701@Viet: revise SP
	    - 20150527@Jim: force SB comm of BA member is zero  
	    - 20151005@Jim:HotFix #45031 (revise SP)
		- 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]
		- 20171020@Johnson: offer Allbet commision [Redmine: #82036]
		- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
		- 20180809@Amanda: Remove Racing [RedmineID: #99378]
		- 20180927@Winnie: Remove AllBet [RedmineID: #99378]
		- 20200409@Johnson: Add comm for AB,Macau,PP,GD,AG [redmine:#131774]
		- 20200511@Max: Add comm for FW, Remove AG, GD - [Redmine: #131774]
		- 20200518@Helen: Add comm for FW, Remove AG, GD - Tuning performance - [Redmine: #131774]
		- 20200701@Helen: Remove Allbet - [Redmine: #131774]
		- 20200814@Helen: LAP - Offer commission to 3rd party products - Phase 2 - [Redmine: #139238] 
		- 20201111@Helen: LAP - Offer commission to 3rd party products - Phase 3 - [Redmine: #145012] 
		- 20210603@Eden: LAP - Support commission for 3rd party products - Phase 4 [Redmine: #154048]  
		- 20210816@Johnson: Add VGaming [redmine: #159696]
		- 20211101@Winfred: Merge Sports Lottery under Sportsbook when turn on BA [redmine:#163191]
		- 20220112@Eden: LAP - RNG Casino - Implement DCS Settings [Redmine: #166217] 
		- 20220422@Winfred: LAP - Support commission for 3rd party products - Phase 4.2 [Redmine: #171586] 
		- 220614@Eden: DBCUST - modify sp syntax to adapt with the SQL Server upgrade to 2019 [Redmine: #171831] 
		- 20220301@Eden: Deposit - Sportsbook - Revise customer settings [Redmine: #167898]
		- 20221201@Tacy: Non-sports products - Remove GDG and Fishing World [RedmineID: #174511]
		- 20230314@Johnson: Add MaxGame, FGG, Jili Comm [redmine:#182922]
		- 20230804@Tacy: LAP - Offer Player Commission to Yeebet, MG-RNG [redmine: #192203]
		- 20230808@Tacy: LAP - Offer Player Commission to VS3 (new) [redmine: #192203]
		- 20240111@Tacy: LAP - Merge VS1, VS2, VS3 as Virtual Sports [Redmine: #199523]
		
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @res AS TABLE (custid INT, isfinished BIT DEFAULT 0, AgentID INT, IsScannedAgent BIT DEFAULT 0)
	
	INSERT INTO @res (custid)
	SELECT value
	FROM STRING_SPLIT(@strCustID,',')
	WHERE value <> ''

	UPDATE r
	SET r.AgentID = ci.recommend
	FROM dbo.CustInfo ci WITH(NOLOCK)
		INNER JOIN @res r ON ci.custid = r.custid

	DECLARE @ids VARCHAR(MAX), @rowcnt INT, @runningCNT INT, @batchSize INT
	DECLARE @res_batch_tmp AS TABLE (custid INT )
	
	SET @runningCNT = 0
	SET @batchSize = 600
	
	DECLARE @InputRes_updateComm_batch AS TABLE (custid INT PRIMARY KEY)
	DECLARE @AgentID INT = 0
	DECLARE @MacauComm_Group DECIMAL(9,8)=0,	
			@PPComm_Group DECIMAL(9,8)=0,
			-- phase 2
			@SexyGamingComm_Group DECIMAL(9,8)=0,
			@SpadeGamingComm_Group DECIMAL(9,8)=0,
			@LotteryComm_Group DECIMAL(9,8)=0,
			@VSComm_Group DECIMAL(9,8)=0,
			@TableGameComm_Group DECIMAL(9,8)=0
			-- phase 3
			,@VirtualGamesComm_Group DECIMAL(9,8) = 0	
			,@ArcadiaGamingComm_Group DECIMAL(9,8) = 0	
			,@SabaclubComm_Group DECIMAL(9,8) = 0	
			,@SAGamingComm_Group DECIMAL(9,8) = 0	
			,@PGSoftComm_Group DECIMAL(9,8) = 0	
			,@AllbetComm_Group DECIMAL(9,8)=0
			-->phase 4
			,@WMCasinoComm_Group		DECIMAL(9,8) = 0
			,@BigGamingComm_Group		DECIMAL(9,8) = 0
			,@JokerComm_Group			DECIMAL(9,8) = 0
			,@HabaneroComm_Group		DECIMAL(9,8) = 0
			,@VGamingComm_Group			DECIMAL(9,8) = 0
			,@SabaCasinoComm_Group		DECIMAL(9,8) = 0
			-- phase 4.2
			,@CGComm_Group				DECIMAL(9,8) = 0
			,@AdvantComm_Group			DECIMAL(9,8) = 0
			,@AdvantMiniComm_Group		DECIMAL(9,8) = 0
			
			,@MaxGameComm_Group			DECIMAL(9,8) = 0
			,@FGGComm_Group				DECIMAL(9,8) = 0
			,@JiliComm_Group			DECIMAL(9,8) = 0

			,@YeeBetComm_Group			DECIMAL(9,8) = 0
			,@MgRNGComm_Group			DECIMAL(9,8) = 0
			--> 
			,@SBComm_Group DECIMAL(9,8)
			,@ParlayComm_Group DECIMAL(9,8) = 0
			,@NGComm_Group DECIMAL(9,8) = 0
			,@KenoComm_Group DECIMAL(9,8) = 0

	WHILE (1 = 1) --Scan Agent
	BEGIN
		SELECT TOP 1 @AgentID = t.AgentID
		FROM @res t 
		WHERE IsScannedAgent = 0
			
		IF @@ROWCOUNT = 0 BREAK
	
		IF (	
			@IsUpdateAllbet = 1 
			OR @IsUpdateMacau = 1 
			OR @IsUpdatePP = 1
			OR @IsUpdateSexyGaming = 1
			OR @IsUpdateSpadeGaming = 1
			OR @IsUpdateLottery = 1
			OR @IsUpdateVS = 1
			OR @IsUpdateTableGame = 1
			OR @IsUpdateVirtualGames = 1	
			OR @IsUpdateArcadiaGaming = 1	
			OR @IsUpdateSabaclub  = 1	
			OR @IsUpdateSAGaming  = 1	
			OR @IsUpdatePGSoft  = 1	
			--> phase 4
			OR @IsUpdateWMCasino = 1	
			OR @IsUpdateBigGaming = 1	
			OR @IsUpdateJoker  = 1	
			OR @IsUpdateHabanero  = 1
			OR @IsUpdateVGaming  = 1	
			--SabaCasino
			OR @IsUpdateSabaCasino = 1		
			-- phase 4.2
			OR @IsUpdateCG				= 1
			OR @IsUpdateAdvant			= 1
			OR @IsUpdateAdvantMini		= 1
			
			OR @IsUpdateMaxGame			= 1
			OR @IsUpdateFGG				= 1
			OR @IsUpdateJili			= 1

			OR @IsUpdateYeeBet			= 1
			OR @IsUpdateMgRNG			= 1

			--
			OR @IsUpdateSB  = 1	
			OR @IsParlayComm  = 1	
			OR @IsUpdateKeno  = 1
			OR @IsUpdateNG  = 1	
			)
		BEGIN		
			SELECT 
				@AllbetComm_Group = MAX(CASE WHEN BetType = 2401 THEN playerdiscount ELSE 0 END),
				@MacauComm_Group = MAX(CASE WHEN BetType = 4001 THEN playerdiscount ELSE 0 END)
				,@PPComm_Group = MAX(CASE WHEN BetType = 4101 THEN playerdiscount ELSE 0 END)
				-- phase 2
				,@SexyGamingComm_Group = MAX(CASE WHEN BetType = 3101 THEN playerdiscount ELSE 0 END)
				,@SpadeGamingComm_Group = MAX(CASE WHEN BetType = 4301 THEN playerdiscount ELSE 0 END)
				,@LotteryComm_Group = MAX(CASE WHEN BetType = 1021 THEN playerdiscount ELSE 0 END)
				,@VSComm_Group = MAX(CASE WHEN BetType = 1201 THEN playerdiscount ELSE 0 END)
				,@TableGameComm_Group = MAX(CASE WHEN BetType = 4901 THEN playerdiscount ELSE 0 END)
				-- phase 3
				,@VirtualGamesComm_Group = MAX(CASE WHEN BetType = 4601 THEN playerdiscount ELSE 0 END)
				,@ArcadiaGamingComm_Group = MAX(CASE WHEN BetType = 1901 THEN playerdiscount ELSE 0 END)
				,@SabaclubComm_Group = MAX(CASE WHEN BetType = 1611 THEN playerdiscount ELSE 0 END)
				,@SAGamingComm_Group = MAX(CASE WHEN BetType = 3001 THEN playerdiscount ELSE 0 END)
				,@PGSoftComm_Group = MAX(CASE WHEN BetType = 6001 THEN playerdiscount ELSE 0 END)
				-->phase 4
				,@WMCasinoComm_Group = MAX(CASE WHEN BetType = 3401 THEN playerdiscount ELSE 0 END)
				,@BigGamingComm_Group = MAX(CASE WHEN BetType = 3501 THEN playerdiscount ELSE 0 END)
				,@JokerComm_Group = MAX(CASE WHEN BetType = 6401 THEN playerdiscount ELSE 0 END)
				,@HabaneroComm_Group = MAX(CASE WHEN BetType = 7001 THEN playerdiscount ELSE 0 END)
				,@VGamingComm_Group = MAX(CASE WHEN BetType = 3801 THEN playerdiscount ELSE 0 END)
				,@SabaCasinoComm_Group = MAX(CASE WHEN BetType = 2101 THEN playerdiscount ELSE 0 END)
				-- phase 4.2
				,@CGComm_Group = MAX(CASE WHEN BetType = 7301 THEN playerdiscount ELSE 0 END)
				,@AdvantComm_Group = MAX(CASE WHEN BetType = 7701 THEN playerdiscount ELSE 0 END)
				,@AdvantMiniComm_Group = MAX(CASE WHEN BetType = 7801 THEN playerdiscount ELSE 0 END)
				
				,@MaxGameComm_Group = MAX(CASE WHEN BetType = 5401 THEN playerdiscount ELSE 0 END)
				,@FGGComm_Group = MAX(CASE WHEN BetType = 8201 THEN playerdiscount ELSE 0 END)
				,@JiliComm_Group = MAX(CASE WHEN BetType = 5100 THEN playerdiscount ELSE 0 END)

				,@YeeBetComm_Group = MAX(CASE WHEN BetType = 3151 THEN playerdiscount ELSE 0 END)
				,@MgRNGComm_Group = MAX(CASE WHEN BetType = 8400 THEN playerdiscount ELSE 0 END)
				--
				,@SBComm_Group = MAX(CASE WHEN BetType = 1 AND SportType = 1 THEN playerdiscount ELSE 0 END)
				,@ParlayComm_Group = MAX(CASE WHEN BetType = 9 AND SportType = 1 THEN playerdiscount ELSE 0 END)
				,@NGComm_Group = MAX(CASE WHEN BetType = 81 THEN playerdiscount ELSE 0 END)
				,@KenoComm_Group = MAX(CASE WHEN BetType = 1501 THEN playerdiscount ELSE 0 END)
			FROM dbo.Dep_CustDiscountGroupSetting_Member grp WITH(NOLOCK)
			WHERE AgentID = @AgentID
				AND sporttype IN (212,248,219,243,247,220
								--Dummy VS
								,9908

								,222
								--phase 3
								,211, 245,165,200,244,232 
								--phase 4
								,233,239,234,236,238
								,171
								--SabaCasino
								,208
								--phase 4.2
								,167,172,174
								
								--MaxGame,FGG,Jili
								,158,176,237

								--MG_RnG,Yeebet
								,155,159

								--
								,1,161,202
								)
		END	
								
		WHILE (1 = 1)
		BEGIN
			SELECT @ids = '', @runningCNT = @runningCNT + 1
		
			DELETE @res_batch_tmp
		
			UPDATE TOP(@batchSize) t
				SET isfinished = 1
			OUTPUT deleted.custid
			INTO @res_batch_tmp(custid)
			FROM @res t 
			WHERE isfinished = 0
				AND AgentID = @AgentID
			
			IF @@ROWCOUNT = 0 BREAK
	
			SET @ids = (SELECT custid AS '@id'
							FROM @res_batch_tmp  t
							FOR XML PATH('r'), ROOT('root')
							)	
			EXEC [Acc_CustSetting3rd_16] 
				@ids = @ids
				,@SBComm = @SBComm
				,@NGComm = @NGComm
				,@ParlayComm = @ParlayComm
				,@AllbetComm = @AllbetComm
				,@MacauComm = @MacauComm
				,@PPComm = @PPComm
				,@IsUpdateSB  = @IsUpdateSB
				,@IsParlayComm  = @IsParlayComm
				,@IsUpdateNG = @IsUpdateNG			
				,@IsUpdateAllbet = @IsUpdateAllbet
				,@IsUpdateMacau = @IsUpdateMacau
				,@IsUpdatePP = @IsUpdatePP
				,@AgentID = @AgentID
				,@AllbetComm_Group = @AllbetComm_Group
				---start param of phase 2 - group 
				,@MacauComm_Group = @MacauComm_Group	
				,@PPComm_Group = @PPComm_Group
				,@SexyGamingComm_Group = @SexyGamingComm_Group
				,@SpadeGamingComm_Group = @SpadeGamingComm_Group 
				,@LotteryComm_Group = @LotteryComm_Group
				,@VSComm_Group = @VSComm_Group
				,@TableGameComm_Group = @TableGameComm_Group
				---start param of phase 2 - update value setting
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
				,@VirtualGamesComm_Group = @VirtualGamesComm_Group	
				,@ArcadiaGamingComm_Group = @ArcadiaGamingComm_Group	
				,@SabaclubComm_Group = @SabaclubComm_Group	
				,@SAGamingComm_Group = @SAGamingComm_Group	
				,@PGSoftComm_Group =  @PGSoftComm_Group	
				--> phase 4
				,@IsUpdateWMCasino		= @IsUpdateWMCasino		
				,@IsUpdateBigGaming		= @IsUpdateBigGaming		
				,@IsUpdateJoker			= @IsUpdateJoker			
				,@IsUpdateHabanero		= @IsUpdateHabanero	
				,@IsUpdateVGaming		= @IsUpdateVGaming	
				-- phase 4.2
				,@IsUpdateCG			= @IsUpdateCG	
				,@IsUpdateAdvant		= @IsUpdateAdvant	
				,@IsUpdateAdvantMini		= @IsUpdateAdvantMini	
				,@WMCasinoComm			= @WMCasinoComm		
				,@BigGamingComm			= @BigGamingComm		
				,@JokerComm			= @JokerComm			
				,@HabaneroComm			= @HabaneroComm		
				,@VGamingComm			= @VGamingComm		
				-- phase 4.2	
				,@CGComm			= @CGComm		
				,@AdvantComm			= @AdvantComm		
				,@AdvantMiniComm		= @AdvantMiniComm		
				,@WMCasinoComm_Group		= @WMCasinoComm_Group		
				,@BigGamingComm_Group		= @BigGamingComm_Group		
				,@JokerComm_Group		= @JokerComm_Group			
				,@HabaneroComm_Group		= @HabaneroComm_Group
				,@VGamingComm_Group		= @VGamingComm_Group	
				--SabaCasino
				,@IsUpdateSabaCasino =	@IsUpdateSabaCasino
				,@SabaCasinoComm = 	@SabaCasinoComm
				,@SabaCasinoComm_Group = @SabaCasinoComm_Group
				-- phase 4.2	
				,@CGComm_Group			= @CGComm_Group	
				,@AdvantComm_Group		= @AdvantComm_Group	
				,@AdvantMiniComm_Group		= @AdvantMiniComm_Group	
				
				,@IsUpdateMaxGame		= @IsUpdateMaxGame
				,@IsUpdateFGG			= @IsUpdateFGG
				,@IsUpdateJili			= @IsUpdateJili
				,@MaxGameComm			= @MaxGameComm
				,@FGGComm				= @FGGComm
				,@JiliComm				= @JiliComm
				,@MaxGameComm_Group		= @MaxGameComm_Group
				,@FGGComm_Group			= @FGGComm_Group				
				,@JiliComm_Group		= @JiliComm_Group

				,@IsUpdateYeeBet		= @IsUpdateYeeBet
				,@IsUpdateMgRNG			= @IsUpdateMgRNG
				,@YeeBetComm			= @YeeBetComm
				,@MgRNGComm				= @MgRNGComm
				,@YeeBetComm_Group		= @YeeBetComm_Group				
				,@MgRNGComm_Group		= @MgRNGComm_Group
				--
				,@SBComm_Group = @SBComm_Group
				,@ParlayComm_Group = @ParlayComm_Group
				,@NGComm_Group = @NGComm_Group
				,@KenoComm_Group = @KenoComm_Group		
			-- delay 00.100ms after 5 times continuous running
			IF @runningCNT % 2 = 0 WAITFOR DELAY '00:00:00.280'
		END

		UPDATE t
		SET t.IsScannedAgent = 1
		FROM @res t
		WHERE AgentID = @AgentID
	END
END	
GO
