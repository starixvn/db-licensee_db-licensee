/*<info serverAlias="DBCUST-bodb_Licensee" executers="" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[Lrf_ExecRep_00]
(
	@strCustId VARCHAR(MAX) = '',
	@LicenseeID INT,
	@GroupCommID INT = 0,
	@MacauLicenseeID INT = 0,
	@IsUpdateNG BIT = 0,
	@IsUpdateRNG BIT = 0,	
	@IsUpdateAllbet BIT = 0,
	@IsUpdateMacau BIT = 0,
	@IsUpdatePP BIT = 0,
	@SBComm DECIMAL(9,8)=0,
	@NGComm DECIMAL(9,8)=0,	
	@RNGComm DECIMAL(9,8)=0,
	@ParlayComm DECIMAL(9,8)=0,	
	@AllbetComm DECIMAL(9,8)=0,	
	@MacauComm DECIMAL(9,8)=0,	
	@PPComm DECIMAL(9,8)=0,	
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
	-- PHASE 3
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
	@IsUpdateVGaming		BIT = 0,
	@IsUpdateCG				BIT = 0,
	@IsUpdateAdvant			BIT = 0,
	@IsUpdateAdvantMini		BIT = 0,
	@WMCasinoComm		DECIMAL(9,8) = 0,
	@BigGamingComm		DECIMAL(9,8) = 0,
	@JokerComm			DECIMAL(9,8) = 0,
	@HabaneroComm		DECIMAL(9,8) = 0,
	@VGamingComm		DECIMAL(9,8) = 0,
	@CGComm				DECIMAL(9,8) = 0,
	@AdvantComm			DECIMAL(9,8) = 0,
	@AdvantMiniComm		DECIMAL(9,8) = 0,
	
	@IsUpdateMaxGame		BIT = 0,
	@IsUpdateFGG			BIT = 0,
	@IsUpdateJili			BIT = 0,
	@MaxGameComm			DECIMAL(9,8) = 0,
	@FGGComm				DECIMAL(9,8) = 0,
	@JiliComm				DECIMAL(9,8) = 0,
	
	@IsUpdateYeeBet			BIT = 0,
	@IsUpdateMgRNG			BIT = 0,
	@YeeBetComm				DECIMAL(9,8) = 0,
	@MgRNGComm				DECIMAL(9,8) = 0,

	@isClearGroupComm BIT = 0,
	@IsUpdateGroupComm BIT = 0

)
AS
/*
	Created: 20200416@Max
	Task : Support commission for 3rd party products - [Redmine: #131774]
	DB: DBCUST/bodb_Licensee
	Original: 

	Revisions:
		- 20200416@Max: Support commission for 3rd party products - [Redmine: #131774]
		- 20200511@Max: Add comm for FW, Remove AG, GD - [Redmine: #131774]
		- 20200518@Helen: Add comm for FW, Remove AG, GD - Tuning performance - [Redmine: #131774] 
		- 20200701@Helen: Remove Allbet - [Redmine: #131774]  
		- 20200814@Helen: LAP - Offer commission to 3rd party products - Phase 2 - [Redmine: #139238] 
		- 20201111@Helen: LAP - Offer commission to 3rd party products - Phase 3 - [Redmine: #145012]
		- 20210603@Eden: LAP - Support commission for 3rd party products - Phase 4 [Redmine: #154048]   
		- 20210817@Johnson: Add VGaming [redmine:#159696]
		- 20211101@Winfred: Merge Sports Lottery under Sportsbook when turn on BA [redmine:#163191]
		- 20220422@Winfred: LAP - Support commission for 3rd party products - Phase 4.2 [Redmine: #171586]   
		- 20221201@Tacy: Non-sports products - Remove GDG and Fishing World [RedmineID: #174511]
		- 20230314@Johnson: Add MaxGame, FGG, Jili Comm [redmine:#182922]
		- 20230804@Tacy: LAP - Offer Player Commission to Yeebet, MG-RNG [redmine: #192203]
		- 20240111@Tacy: LAP - Merge VS1, VS2, VS3 as Virtual Sports [Redmine: #199523]
		
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;
	
	IF @strCustId = ''
		RETURN
	
	DECLARE @TempList_Input AS TABLE (CustID INT PRIMARY KEY )
	DECLARE @xml XML, @BA_cnt INT
	
	DECLARE @TempLicenseeBA_batch AS TABLE (CustID INT PRIMARY KEY)
	
	SELECT @xml = CONVERT(XML,N'<root><r t="' + REPLACE(@strCustId,',','"/><r t="') + '"/></root>"')

	INSERT INTO @TempList_Input (CustID)
	SELECT T.C.value('./@t', 'int')			
	FROM @xml.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@xml = NULL ))
	
	IF @isClearGroupComm = 1
	BEGIN
		UPDATE lc
			SET GroupCommID = 0
		FROM dbo.LicenseeCustComm lc WITH (ROWLOCK,UPDLOCK) 
			INNER JOIN @TempList_Input t ON lc.CustID = t.CustID
		
		RETURN	
	END
	-- Get list of BA members
	INSERT INTO @TempLicenseeBA_batch (CustID)
	SELECT t.CustID 
	FROM @TempList_Input  t
		INNER JOIN dbo.LicenseeBAHistory ba WITH (NOLOCK) ON t.CustID=ba.CustID
	WHERE ba.Status ='Running' AND ba.LicenseeID = @LicenseeID 
	
	SET @BA_cnt = @@ROWCOUNT
	
	-- performance tuning for update comm group
	IF @IsUpdateGroupComm = 1
	BEGIN
		UPDATE cs
			 SET 
				SBComm = CASE WHEN ba.custID IS NOT NULL AND @LicenseeID <> @MacauLicenseeID THEN 0 ELSE @SBComm END
				, ParlayComm = CASE WHEN ba.custID IS NOT NULL AND @LicenseeID <> @MacauLicenseeID THEN 0 ELSE @ParlayComm END
				, GroupCommID = @GroupCommID
				, NGComm=CASE WHEN  @IsUpdateNG = 1 THEN @NGComm ELSE NGComm END
				, RNGComm=CASE WHEN @IsUpdateRNG = 1 THEN @RNGComm ELSE RNGComm END
				, AllbetComm=CASE WHEN @IsUpdateAllbet = 1 THEN @AllbetComm ELSE AllbetComm END
				, MacauComm= CASE WHEN @IsUpdateMacau = 1 THEN @MacauComm ELSE MacauComm END
				, PPComm= CASE WHEN @IsUpdatePP = 1 THEN @PPComm ELSE PPComm END
				-- phase 2
				, SexyGamingComm  = CASE WHEN @IsUpdateSexyGaming = 1 THEN @SexyGamingComm ELSE SexyGamingComm END 
				, SpadeGamingComm  = CASE WHEN @IsUpdateSpadeGaming = 1 THEN @SpadeGamingComm ELSE SpadeGamingComm END
				, KenoComm  = CASE WHEN @IsUpdateKeno = 1 THEN @KenoComm ELSE KenoComm END
				, LotteryComm  = CASE WHEN @IsUpdateLottery = 1 THEN @LotteryComm ELSE LotteryComm END
				, VSComm  = CASE WHEN @IsUpdateVS = 1 THEN @VSComm ELSE VSComm END
				, TableGameComm  = CASE WHEN @IsUpdateTableGame = 1 THEN @TableGameComm ELSE TableGameComm END
				-- PHASE 3
				, VirtualGamesComm  = CASE WHEN @IsUpdateVirtualGames = 1 THEN @VirtualGamesComm  ELSE VirtualGamesComm END
				, ArcadiaGamingComm  = CASE WHEN @IsUpdateArcadiaGaming = 1 THEN @ArcadiaGamingComm  ELSE ArcadiaGamingComm END
				, SabaclubComm  = CASE WHEN @IsUpdateSabaclub = 1 THEN @SabaclubComm ELSE SabaclubComm END
				, SAGamingComm  = CASE WHEN @IsUpdateSAGaming = 1 THEN @SAGamingComm ELSE SAGamingComm END	
				, PGSoftComm  = CASE WHEN @IsUpdatePGSoft = 1 THEN @PGSoftComm ELSE PGSoftComm END
				--> phase 4
				,WMCasinoComm = CASE WHEN @IsUpdateWMCasino = 1 THEN @WMCasinoComm ELSE WMCasinoComm END
				,BigGamingComm = CASE WHEN @IsUpdateBigGaming = 1 THEN @BigGamingComm ELSE BigGamingComm END
				,JokerComm = CASE WHEN @IsUpdateJoker = 1 THEN @JokerComm ELSE JokerComm END
				,HabaneroComm = CASE WHEN @IsUpdateHabanero = 1 THEN @HabaneroComm ELSE HabaneroComm END
				,VGamingComm = CASE WHEN @IsUpdateVGaming = 1 THEN @VGamingComm ELSE VGamingComm END
				-- phase 4.2
				,CGComm = CASE WHEN @IsUpdateCG = 1 THEN @CGComm ELSE CGComm END
				,AdvantComm = CASE WHEN @IsUpdateAdvant = 1 THEN @AdvantComm ELSE AdvantComm END
				,AdvantMiniComm = CASE WHEN @IsUpdateAdvantMini = 1 THEN @AdvantMiniComm ELSE AdvantMiniComm END
				
				,MaxGameComm = CASE WHEN @IsUpdateMaxGame = 1 THEN @MaxGameComm ELSE MaxGameComm END
				,FGGComm = CASE WHEN @IsUpdateFGG = 1 THEN @FGGComm ELSE FGGComm END
				,JiliComm = CASE WHEN @IsUpdateJili = 1 THEN @JiliComm ELSE JiliComm END

				,YeeBetComm = CASE WHEN @IsUpdateYeeBet = 1 THEN @YeeBetComm ELSE YeeBetComm END
				,MgRNGComm = CASE WHEN @IsUpdateMgRNG = 1 THEN @MgRNGComm ELSE MgRNGComm END
		FROM dbo.LicenseeCustComm cs WITH (ROWLOCK,UPDLOCK)
			INNER JOIN @TempList_Input ip ON cs.CustID = ip.CustID
			LEFT JOIN @TempLicenseeBA_batch ba ON ba.custid = ip.custid
	END
	ELSE
	BEGIN
		-- Update SB for Non BA members
		MERGE dbo.LicenseeCustComm AS target
		USING (SELECT @LicenseeID AS LicenseeID, t.CustID, @SBComm AS SBComm,@ParlayComm AS ParlayComm, @GroupCommID AS GroupCommID 
				FROM  @TempList_Input t
					LEFT JOIN @TempLicenseeBA_batch ba ON t.custid = ba.custid
				WHERE ba.custID IS NULL
				 
				) AS source
			ON (target.CustID = source.CustID)
		WHEN MATCHED THEN 
			UPDATE 
			SET target.SBComm = source.SBComm,
				target.ParlayComm = source.ParlayComm,
				target.GroupCommID = source.GroupCommID
		WHEN NOT MATCHED THEN	
			INSERT (LicenseeID,CustID,SBComm,ParlayComm,GroupCommID)
			VALUES (source.LicenseeID,source.CustID,source.SBComm,Source.ParlayComm,source.GroupCommID);
					
		-- Update SB for BA members
		IF @BA_cnt > 0
		BEGIN
			MERGE dbo.LicenseeCustComm AS target
			USING (SELECT @LicenseeID AS LicenseeID
							,CustID
							,CASE WHEN @LicenseeID <> @MacauLicenseeID THEN 0 ELSE @SBComm END AS SBComm 
							,CASE WHEN @LicenseeID <> @MacauLicenseeID THEN 0 ELSE @ParlayComm END AS ParlayComm
							,@GroupCommID AS GroupCommID 
					FROM @TempLicenseeBA_batch 
					) AS source
				ON (target.CustID = source.CustID)
			WHEN MATCHED THEN 
				UPDATE 
				SET target.SBComm = source.SBComm,
					target.ParlayComm = source.ParlayComm,
					target.GroupCommID = source.GroupCommID
			WHEN NOT MATCHED THEN	
				INSERT (LicenseeID,CustID,SBComm,ParlayComm,GroupCommID)
				VALUES (source.LicenseeID,source.CustID,source.SBComm,Source.ParlayComm,source.GroupCommID);
		END
		
		IF (@IsUpdateNG = 1
			OR @IsUpdateRNG = 1
			OR @IsUpdateAllbet=1
			OR @IsUpdateMacau=1
			OR @IsUpdatePP=1
			-- phase 2
			OR @IsUpdateSexyGaming = 1
			OR @IsUpdateSpadeGaming = 1
			OR @IsUpdateKeno = 1
			OR @IsUpdateLottery = 1
			OR @IsUpdateVS = 1
			OR @IsUpdateTableGame = 1
			--PHASE 3
			OR @IsUpdateVirtualGames  = 1
			OR @IsUpdateArcadiaGaming  = 1
			OR @IsUpdateSabaclub  = 1
			OR @IsUpdateSAGaming  = 1
			OR @IsUpdatePGSoft  = 1
			--Phase 4
			OR @IsUpdateWMCasino		= 1
			OR @IsUpdateBigGaming		= 1
			OR @IsUpdateJoker			= 1
			OR @IsUpdateHabanero		= 1
			OR @IsUpdateVGaming			= 1
			-- phase 4.2
			OR @IsUpdateCG				= 1
			OR @IsUpdateAdvant			= 1
			OR @IsUpdateAdvantMini		= 1
			
			OR @IsUpdateMaxGame			= 1
			OR @IsUpdateFGG				= 1
			OR @IsUpdateJili			= 1

			OR @IsUpdateYeeBet			= 1
			OR @IsUpdateMgRNG			= 1
			)
		BEGIN	
			UPDATE cs
				SET NGComm=CASE WHEN  @IsUpdateNG = 1 THEN @NGComm ELSE NGComm END
					, RNGComm=CASE WHEN @IsUpdateRNG = 1 THEN @RNGComm ELSE RNGComm END
					, AllbetComm=CASE WHEN @IsUpdateAllbet = 1 THEN @AllbetComm ELSE AllbetComm END
					, MacauComm= CASE WHEN @IsUpdateMacau = 1 THEN @MacauComm ELSE MacauComm END
					, PPComm= CASE WHEN @IsUpdatePP = 1 THEN @PPComm ELSE PPComm END
					-- phase 2
					, SexyGamingComm  = CASE WHEN @IsUpdateSexyGaming = 1 THEN @SexyGamingComm ELSE SexyGamingComm END 
					, SpadeGamingComm  = CASE WHEN @IsUpdateSpadeGaming = 1 THEN @SpadeGamingComm ELSE SpadeGamingComm END
					, KenoComm  = CASE WHEN @IsUpdateKeno = 1 THEN @KenoComm ELSE KenoComm END
					, LotteryComm  = CASE WHEN @IsUpdateLottery = 1 THEN @LotteryComm ELSE LotteryComm END
					, VSComm  = CASE WHEN @IsUpdateVS = 1 THEN @VSComm ELSE VSComm END
					, TableGameComm  = CASE WHEN @IsUpdateTableGame = 1 THEN @TableGameComm ELSE TableGameComm END
					-- PHASE 3
					, VirtualGamesComm  = CASE WHEN @IsUpdateVirtualGames = 1 THEN @VirtualGamesComm  ELSE VirtualGamesComm END
					, ArcadiaGamingComm  = CASE WHEN @IsUpdateArcadiaGaming = 1 THEN @ArcadiaGamingComm  ELSE ArcadiaGamingComm END
					, SabaclubComm  = CASE WHEN @IsUpdateSabaclub = 1 THEN @SabaclubComm ELSE SabaclubComm END
					, SAGamingComm  = CASE WHEN @IsUpdateSAGaming = 1 THEN @SAGamingComm ELSE SAGamingComm END	
					, PGSoftComm  = CASE WHEN @IsUpdatePGSoft = 1 THEN @PGSoftComm ELSE PGSoftComm END
					--> phase 4
					,WMCasinoComm = CASE WHEN @IsUpdateWMCasino = 1 THEN @WMCasinoComm ELSE WMCasinoComm END
					,BigGamingComm = CASE WHEN @IsUpdateBigGaming = 1 THEN @BigGamingComm ELSE BigGamingComm END
					,JokerComm = CASE WHEN @IsUpdateJoker = 1 THEN @JokerComm ELSE JokerComm END
					,HabaneroComm = CASE WHEN @IsUpdateHabanero = 1 THEN @HabaneroComm ELSE HabaneroComm END
					,VGamingComm = CASE WHEN @IsUpdateVGaming = 1 THEN @VGamingComm ELSE VGamingComm END
					-- phase 4.2
					,CGComm = CASE WHEN @IsUpdateCG = 1 THEN @CGComm ELSE CGComm END
					,AdvantComm = CASE WHEN @IsUpdateAdvant = 1 THEN @AdvantComm ELSE AdvantComm END
					,AdvantMiniComm = CASE WHEN @IsUpdateAdvantMini = 1 THEN @AdvantMiniComm ELSE AdvantMiniComm END
					
					,MaxGameComm = CASE WHEN @IsUpdateMaxGame = 1 THEN @MaxGameComm ELSE MaxGameComm END
					,FGGComm = CASE WHEN @IsUpdateFGG = 1 THEN @FGGComm ELSE FGGComm END
					,JiliComm = CASE WHEN @IsUpdateJili = 1 THEN @JiliComm ELSE JiliComm END

					,YeeBetComm = CASE WHEN @IsUpdateYeeBet = 1 THEN @YeeBetComm ELSE YeeBetComm END
					,MgRNGComm = CASE WHEN @IsUpdateMgRNG = 1 THEN @MgRNGComm ELSE MgRNGComm END
			FROM dbo.LicenseeCustComm cs WITH (ROWLOCK,UPDLOCK)
				INNER JOIN @TempList_Input ip ON ip.CustID = cs.CustID
		END
		
	END
	
END

GO


