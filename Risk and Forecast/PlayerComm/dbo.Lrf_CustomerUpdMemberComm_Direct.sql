/*<info serverAlias="DBCUST-CustDB" executers="bodbLicenseeNet,bodbAdminNet,Dot_Member" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CustomerUpdMemberComm_Direct]
	@CustID INT,
	@SBComm DECIMAL(9,8) ,
	@NGComm DECIMAL(9,8)=0,	
	@ParlayComm DECIMAL(9,8)=0,
	@AllbetComm DECIMAL(9,8)=0,	
	@MacauComm DECIMAL(9,8)=0,	
	@PPComm DECIMAL(9,8)=0,
	@FWComm DECIMAL(9,8)=0,
	@IsUpdateSB BIT = 1,
	@IsParlayComm BIT = 1,
	@IsUpdateNG BIT = 0,
	@IsUpdateAllbet BIT = 0,
	@IsUpdateMacau BIT = 0,
	@IsUpdatePP BIT = 0,
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
	-- param of phase 3
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
	@IsUpdateGDG			BIT = 0,
	@IsUpdateHabanero		BIT = 0,
	@IsUpdateVGaming		BIT = 0,
	-- phase 4.2
	@IsUpdateCG				BIT = 0,
	@IsUpdateAdvant			BIT = 0,
	@IsUpdateAdvantMini		BIT = 0,
	@IsUpdateVS3			BIT = 0,
	@WMCasinoComm		DECIMAL(9,8) = 0,
	@BigGamingComm		DECIMAL(9,8) = 0,
	@JokerComm			DECIMAL(9,8) = 0,
	@GDGComm			DECIMAL(9,8) = 0,
	@HabaneroComm		DECIMAL(9,8) = 0,
	@VGamingComm		DECIMAL(9,8) = 0,
	@IsUpdateSabaCasino	BIT = 0,
	@SabaCasinoComm		DECIMAL(9,8) =0,
	@CGComm				DECIMAL(9,8) = 0,
	@AdvantComm			DECIMAL(9,8) = 0,
	@AdvantMiniComm		DECIMAL(9,8) = 0,
	@VS3Comm			DECIMAL(9,8) = 0
AS
/*
	Created: 20130114@Henry
	Task : Update Licensee's players commission in DBTRANS
	DB: DBCUST/CustDB
	Original: 

	Revisions:
		- 20131023@Hannah: offer Live Casino commission
		- 20150513@Jim: force BA member comm is zero
		- 20151005@Jim:HotFix #45031
		- 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]	
		- 20171019@Johnson: offer Allbet commision [Redmine: #82036]
		- 20171129@Johnson: enhance for 1st dep, dont move to individual dcs setting if no change setting [Redmine: #87352]
		- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
		- 20180809@Sophia: HA - remove LicenseeCustInfo table [Redmine: #99464]
		- 20180809@Amanda: Remove Racing [RedmineID: #99378]
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
		- 20180927@Winnie: Remove AllBet [RedmineID: #99378]
		- 20200409@Johnson: Add comm for AB,Macau,PP,GD,AG [redmine:#131774]
		- 20200511@Max: Add comm for FW, Remove AG, GD - [Redmine: #131774]
		- 20200518@Helen: Add comm for FW, Remove AG, GD - Tuning performance - [Redmine: #131774]
		- 20200701@Helen: Remove Allbet - [Redmine: #131774]
		- 20200814@Helen: LAP - Offer commission to 3rd party products - Phase 2 - [Redmine: #139238] 
		- 20201111@Helen: LAP - Offer commission to 3rd party products - Phase 3 - [Redmine: #145012] 
		- 20210603@Eden: LAP - Support commission for 3rd party products - Phase 4 [Redmine: #154048]  
		- 20210817@Johnson: Add VGaming [redmine: #159696]
		- 20211101@Winfred: Merge Sports Lottery under Sportsbook when turn on BA [redmine:#163191]
		- 20220112@Eden: LAP - RNG Casino - Implement DCS Settings [Redmine: #166217] 
		- 20220422@Winfred: LAP - Support commission for 3rd party products - Phase 4.2 [Redmine: #171586] 
		- 20220301@Eden: Deposit - Sportsbook - Revise customer settings [Redmine: #167898]
				
	Param's Explanation:	

*/
BEGIN
	SET NOCOUNT ON
	DECLARE @IsGroupedComm BIT, 
			@AgentID INT
	
	-- param for DCS
	DECLARE @sporttype SMALLINT, @bettype SMALLINT, @Comm DECIMAL(9,8)			
	DECLARE @tblSettingDCS_tmp AS TABLE (IsUpdated BIT,sporttype SMALLINT,Bettype SMALLINT, Comm DECIMAL(9,8), isfinished BIT DEFAULT(0))
	
	SELECT @AgentID = recommend 
	FROM CustInfo WITH(NOLOCK)
	WHERE CustID = @CustID
	
	IF EXISTS (SELECT 1 FROM bodb_licensee.dbo.LicenseeBAHistory WITH (NOLOCK) WHERE CustID = @CustID AND Status = 'running')
	BEGIN 
		IF NOT EXISTS ( SELECT 1 
						FROM bodb_licensee.dbo.Licensees l WITH (NOLOCK) 
							INNER JOIN bodb_licensee.dbo.LicenseeCust lc WITH (NOLOCK) ON l.licenseeId = lc.LicenseeId
							INNER JOIN Customer lci WITH (NOLOCK) ON lc.CustId=lci.Recommend
						WHERE l.LicenseeName = 'Macaubet' AND lci.CustID = @CustID 																
						)
		BEGIN
			SELECT @SBComm = 0 , @ParlayComm = 0 
		END
	END
	
	-- DCS Structure ---------
	IF (@IsUpdateMacau=1
		OR @IsUpdatePP=1
		OR @IsUpdateFW=1
		OR @IsUpdateSexyGaming = 1
		OR @IsUpdateSpadeGaming = 1
		OR @IsUpdateLottery = 1
		OR @IsUpdateVS = 1
		OR @IsUpdateVS2 = 1
		OR @IsUpdateTableGame = 1
		-- PHASE 3
		OR @IsUpdateVirtualGames = 1
		OR @IsUpdateArcadiaGaming = 1
		OR @IsUpdateSabaclub  = 1
		OR @IsUpdateSAGaming  = 1
		OR @IsUpdatePGSoft  = 1
		OR @IsUpdateAllbet = 1
		--> phase 4
		OR @IsUpdateWMCasino = 1	
		OR @IsUpdateBigGaming = 1	
		OR @IsUpdateJoker  = 1	
		OR @IsUpdateGDG  = 1	
		OR @IsUpdateHabanero  = 1
		OR @IsUpdateVGaming  = 1
		OR @IsUpdateSabaCasino  = 1
		-- phase 4.2
		OR @IsUpdateCG			= 1
		OR @IsUpdateAdvant		= 1
		OR @IsUpdateAdvantMini	= 1
		OR @IsUpdateVS3			= 1
		--
		OR @IsUpdateSB  = 1	
		OR @IsParlayComm  = 1
		OR @IsUpdateNG  = 1
		OR @IsUpdateKeno  = 1
	)
	BEGIN
		INSERT INTO @tblSettingDCS_tmp (IsUpdated,sporttype,Bettype, Comm)
		VALUES (@IsUpdateMacau, 212,4001, @MacauComm)
				, (@IsUpdatePP,248,4101, @PPComm )
				, (@IsUpdateFW,219,1011, @FWComm)
				-- phase 2
				,(@IsUpdateSexyGaming,243,3101, @SexyGamingComm )
				,(@IsUpdateSpadeGaming ,247,4301, @SpadeGamingComm )
				,(@IsUpdateLottery ,220,1021, @LotteryComm )
				,(@IsUpdateVS ,180,1201, @VSComm )
				,(@IsUpdateVS2 ,190,2701, @VS2Comm )
				,(@IsUpdateTableGame ,222,4901, @TableGameComm )
				-- Phase 3
				,(@IsUpdateVirtualGames,245,4601,@VirtualGamesComm)
				,(@IsUpdateArcadiaGaming,165,1901,@ArcadiaGamingComm)
				,(@IsUpdateSabaclub,200,1611,@SabaclubComm)
				,(@IsUpdateSAGaming,244,3001,@SAGamingComm)
				,(@IsUpdatePGSoft,232,6001,@PGSoftComm)
				,(@IsUpdateAllbet,211,2401,@AllbetComm)
				--> phase 4
				,(@IsUpdateWMCasino,233,3401,@WMCasinoComm)
				,(@IsUpdateBigGaming,239,3501,@BigGamingComm)
				,(@IsUpdateJoker,234,6401,@JokerComm)
				,(@IsUpdateGDG,236,5701,@GDGComm)
				,(@IsUpdateHabanero,238,7001,@HabaneroComm)
				,(@IsUpdateVGaming,171,3801,@VGamingComm)
				--Saba Casino
				,(@IsUpdateSabaCasino,208,2101,@SabaCasinoComm)
				-- Phase 4.2
				,(@IsUpdateCG,167,7301,@CGComm)
				,(@IsUpdateAdvant,172,7701,@AdvantComm)
				,(@IsUpdateAdvantMini,174,7801,@AdvantMiniComm)
				,(@IsUpdateVS3,231,5301,@VS3Comm)
				--
				,(@IsUpdateSB,1,1,@SBComm)
				,(@IsUpdateSB,1,4,@SBComm)
				,(@IsUpdateSB,1,5,@SBComm)
				,(@IsUpdateSB,2,2,@SBComm)
				,(@IsParlayComm,1,9,@ParlayComm)
				,(@IsUpdateNG,161,81,@NGComm)
				,(@IsUpdateKeno,202,1501,@KenoComm)
	END
	
	IF EXISTS(SELECT TOP (1) 1 FROM @tblSettingDCS_tmp)
	BEGIN
		WHILE (1=1)
		BEGIN
			UPDATE TOP (1) @tblSettingDCS_tmp
				SET isfinished = 1
					,@sporttype = sporttype
					,@bettype = Bettype
					,@Comm = comm 
			WHERE isfinished = 0 AND IsUpdated = 1
			
			IF @@ROWCOUNT = 0 BREAK
 
			SELECT @IsGroupedComm = IsGroupedComm
			FROM dbo.Dep_CustSettingMode WITH(NOLOCK)
			WHERE custid = @CustID
			
			IF @IsGroupedComm = 0
			BEGIN
				UPDATE dbo.Dep_CustDiscountSetting_Member WITH(UPDLOCK,ROWLOCK)
					SET PlayerDiscount = @Comm
				WHERE CustID = @CustID
					AND sporttype = @sporttype
					AND bettype = @bettype
			END
			ELSE
			BEGIN
				--check if setting change really or not before move
				IF EXISTS(SELECT 1
						FROM dbo.Dep_CustDiscountGroupSetting_Member grp WITH(NOLOCK)
						WHERE AgentID = @AgentID
							AND sporttype = @sporttype
							AND bettype = @bettype
							AND playerdiscount <> @Comm
						)
				BEGIN		
					--move to individual setting
					INSERT INTO dbo.Dep_CustDiscountSetting_Member
						(CustID
						,SportType
						,BetType
						,PlayerDiscount
						,AgentDiscount
						,MasterDiscount
						,SuperDiscount)
					SELECT @CustID
						,grp.SportType
						,grp.BetType
						,CASE WHEN grp.SportType = @sporttype AND grp.BetType = @bettype THEN @Comm ELSE grp.PlayerDiscount END
						,grp.AgentDiscount
						,grp.MasterDiscount
						,grp.SuperDiscount
					FROM dbo.Dep_CustDiscountGroupSetting_Member grp WITH(NOLOCK)
						LEFT JOIN dbo.Dep_CustDiscountSetting_Member cs WITH(NOLOCK) ON cs.custid = @custid
																					AND cs.sporttype = grp.sporttype
																					AND cs.bettype = grp.bettype
					WHERE AgentID = @AgentID
						AND cs.custid IS NULL
					
					UPDATE dbo.Dep_CustDiscountSetting_Member WITH(UPDLOCK,ROWLOCK)
						SET playerdiscount = @Comm
					WHERE CustID = @CustID	
						AND sporttype = @sporttype
						AND bettype = @bettype
					
					UPDATE dbo.Dep_CustSettingMode WITH(UPDLOCK,ROWLOCK)
						SET IsGroupedComm = 0
					WHERE CustID = @CustID	
				END	
			END
			
			WAITFOR DELAY '00:00:00.10'	
		END
	END
END
GO 