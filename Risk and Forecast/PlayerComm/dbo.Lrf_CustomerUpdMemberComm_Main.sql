/*<info serverAlias="DBCUST-CustDB" executers="bodbLicenseeNet,bodbAdminNet,Dot_Member" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CustomerUpdMemberComm_Main] 
	@strCustID VARCHAR(MAX)
	,@SBComm DECIMAL(9,8)
	,@NGComm DECIMAL(9,8) = 0
	,@ParlayComm DECIMAL(9,8) = 0
	,@AllbetComm DECIMAL(9,8) = 0
	,@MacauComm DECIMAL(9,8) = 0
	,@PPComm DECIMAL(9,8) = 0
	,@FWComm DECIMAL(9,8) = 0
	,@IsUpdateSB BIT = 1
	,@IsParlayComm BIT = 1
	,@IsUpdateNG BIT = 0
	,@IsUpdateAllbet BIT = 0
	,@IsUpdateMacau BIT = 0
	,@IsUpdatePP BIT = 0
	,@IsUpdateFW BIT = 0
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
	,@IsUpdateVS2 BIT = 0	
	,@VS2Comm DECIMAL(9,8) = 0
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
	,@IsUpdateGDG			BIT = 0
	,@IsUpdateHabanero		BIT = 0
	,@IsUpdateVGaming 		BIT = 0
	,@WMCasinoComm		DECIMAL(9,8) = 0
	,@BigGamingComm		DECIMAL(9,8) = 0
	,@JokerComm			DECIMAL(9,8) = 0
	,@GDGComm			DECIMAL(9,8) = 0
	,@HabaneroComm		DECIMAL(9,8) = 0
	,@VGamingComm		DECIMAL(9,8) = 0
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
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @res AS TABLE (custid INT, isfinished BIT)
	
	INSERT INTO @res (custid, isfinished)
	SELECT VAL, 0
	FROM dbo.f_SplitString(@strCustID,',')
	OPTION (MAXRECURSION 0)

	DECLARE @ids VARCHAR(MAX), @rowcnt INT, @runningCNT INT, @batchSize INT
	DECLARE @res_batch_tmp AS TABLE (custid INT )
	
	SET @runningCNT = 0
	SET @batchSize = 600
	
	DECLARE @InputRes_updateComm_batch AS TABLE (custid INT PRIMARY KEY)
	DECLARE @AgentID INT = 0
	DECLARE @MacauComm_Group DECIMAL(9,8)=0,	
			@PPComm_Group DECIMAL(9,8)=0,
			@FWComm_Group DECIMAL(9,8)=0,
			-- phase 2
			@SexyGamingComm_Group DECIMAL(9,8)=0,
			@SpadeGamingComm_Group DECIMAL(9,8)=0,
			@KenoComm_Group DECIMAL(9,8)=0,
			@LotteryComm_Group DECIMAL(9,8)=0,
			@VSComm_Group DECIMAL(9,8)=0,
			@VS2Comm_Group DECIMAL(9,8)=0,
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
			,@GDGComm_Group				DECIMAL(9,8) = 0
			,@HabaneroComm_Group		DECIMAL(9,8) = 0
			,@VGamingComm_Group			DECIMAL(9,8) = 0

	
	IF (	@IsUpdateAllbet = 1 OR 
		@IsUpdateFW = 1 OR @IsUpdateMacau = 1 OR @IsUpdatePP = 1
		OR @IsUpdateSexyGaming = 1
		OR @IsUpdateSpadeGaming = 1
		OR @IsUpdateLottery = 1
		OR @IsUpdateVS = 1
		OR @IsUpdateVS2 = 1
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
		OR @IsUpdateGDG  = 1	
		OR @IsUpdateHabanero  = 1
		OR @IsUpdateVGaming  = 1		

		)
	BEGIN		
		SET @AgentID = (SELECT TOP (1) recommend 
							FROM dbo.CustInfo ci WITH(NOLOCK)
								INNER JOIN @res r ON ci.custid = r.custid
							)
		SELECT 
			@AllbetComm_Group = MAX(CASE WHEN BetType = 2401 THEN playerdiscount ELSE 0 END),
			@MacauComm_Group = MAX(CASE WHEN BetType = 4001 THEN playerdiscount ELSE 0 END)
			,@PPComm_Group = MAX(CASE WHEN BetType = 4101 THEN playerdiscount ELSE 0 END)
			,@FWComm_Group = MAX(CASE WHEN BetType = 1011 THEN playerdiscount ELSE 0 END)
			-- phase 2
			,@SexyGamingComm_Group = MAX(CASE WHEN BetType = 3101 THEN playerdiscount ELSE 0 END)
			,@SpadeGamingComm_Group = MAX(CASE WHEN BetType = 4301 THEN playerdiscount ELSE 0 END)
			,@LotteryComm_Group = MAX(CASE WHEN BetType = 1021 THEN playerdiscount ELSE 0 END)
			,@VSComm_Group = MAX(CASE WHEN BetType = 1201 THEN playerdiscount ELSE 0 END)
			,@VS2Comm_Group = MAX(CASE WHEN BetType = 2701 THEN playerdiscount ELSE 0 END)
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
			,@GDGComm_Group = MAX(CASE WHEN BetType = 5701 THEN playerdiscount ELSE 0 END)
			,@HabaneroComm_Group = MAX(CASE WHEN BetType = 7001 THEN playerdiscount ELSE 0 END)
			,@VGamingComm_Group = MAX(CASE WHEN BetType = 3801 THEN playerdiscount ELSE 0 END)
		FROM dbo.Dep_CustDiscountGroupSetting_Member grp WITH(NOLOCK)
		WHERE AgentID = @AgentID
			AND sporttype IN (212,248,219,243,247,220,180,190,222
								--phase 3
							,211, 245,165,200,244,232 
							--phase 4
							,233,239,234,236,238
							,171
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
			,@FWComm = @FWComm
			,@IsUpdateSB  = @IsUpdateSB
			,@IsParlayComm  = @IsParlayComm
			,@IsUpdateNG = @IsUpdateNG			
			,@IsUpdateAllbet = @IsUpdateAllbet
			,@IsUpdateMacau = @IsUpdateMacau
			,@IsUpdatePP = @IsUpdatePP
			,@IsUpdateFW = @IsUpdateFW
			,@AgentID = @AgentID
			,@AllbetComm_Group = @AllbetComm_Group
			---start param of phase 2 - group 
			,@MacauComm_Group = @MacauComm_Group	
			,@PPComm_Group = @PPComm_Group
			,@FWComm_Group = @FWComm_Group
			,@SexyGamingComm_Group = @SexyGamingComm_Group
			,@SpadeGamingComm_Group = @SpadeGamingComm_Group 
			,@LotteryComm_Group = @LotteryComm_Group
			,@VSComm_Group = @VSComm_Group
			,@VS2Comm_Group = @VS2Comm_Group
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
			,@IsUpdateVS2 =  @IsUpdateVS2	
			,@VS2Comm = @VS2Comm 
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
			,@IsUpdateGDG			= @IsUpdateGDG			
			,@IsUpdateHabanero		= @IsUpdateHabanero	
			,@IsUpdateVGaming		= @IsUpdateVGaming				
			,@WMCasinoComm				= @WMCasinoComm		
			,@BigGamingComm				= @BigGamingComm		
			,@JokerComm					= @JokerComm			
			,@GDGComm					= @GDGComm			
			,@HabaneroComm				= @HabaneroComm		
			,@VGamingComm				= @VGamingComm		
			,@WMCasinoComm_Group		= @WMCasinoComm_Group		
			,@BigGamingComm_Group		= @BigGamingComm_Group		
			,@JokerComm_Group			= @JokerComm_Group			
			,@GDGComm_Group				= @GDGComm_Group		
			,@HabaneroComm_Group		= @HabaneroComm_Group
			,@VGamingComm_Group			= @VGamingComm_Group			

		-- delay 00.100ms after 5 times continuous running
		IF @runningCNT % 2 = 0 WAITFOR DELAY '00:00:00.280'
	END
	
END	
GO
