/*<info serverAlias="DBCUST-CUSTDB" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CustSetting3rd_16]
	@IDs VARCHAR(MAX),
	@SBComm DECIMAL(9,8) = 0,
	@NGComm DECIMAL(9,8)=0,	
	@ParlayComm DECIMAL(9,8)=0,
	@AllbetComm DECIMAL(9,8)=0,	
	@MacauComm DECIMAL(9,8)=0,	
	@PPComm DECIMAL(9,8)=0,
	@FWComm DECIMAL(9,8)=0,
	@IsUpdateSB BIT = 0,
	@IsParlayComm BIT = 0,
	@IsUpdateNG BIT = 0,
	@IsUpdateAllbet BIT = 0,
	@IsUpdateMacau BIT = 0,
	@IsUpdatePP BIT = 0,
	@IsUpdateFW BIT = 0,
	@AgentID INT = NULL,
	@AllbetComm_Group DECIMAL(9,8)=0,	
	@MacauComm_Group DECIMAL(9,8)=0,	
	@PPComm_Group DECIMAL(9,8)=0,
	@FWComm_Group DECIMAL(9,8)=0,
	-- start param phase 2 - group param
	@SexyGamingComm_Group DECIMAL(9,8)=0,
	@SpadeGamingComm_Group DECIMAL(9,8)=0,
	@LotteryComm_Group DECIMAL(9,8)=0,
	@VSComm_Group DECIMAL(9,8)=0,
	@VS2Comm_Group DECIMAL(9,8)=0,
	@TableGameComm_Group DECIMAL(9,8)=0,	
	-- start param phase 2 - new value setting
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
	@VirtualGamesComm_Group DECIMAL(9,8) = 0,	
	@ArcadiaGamingComm_Group DECIMAL(9,8) = 0,	
	@SabaclubComm_Group DECIMAL(9,8) = 0,	
	@SAGamingComm_Group DECIMAL(9,8) = 0,	
	@PGSoftComm_Group DECIMAL(9,8) = 0,
	-->phase 4
	@IsUpdateWMCasino		BIT = 0,
	@IsUpdateBigGaming		BIT = 0,
	@IsUpdateJoker			BIT = 0,
	@IsUpdateGDG			BIT = 0,
	@IsUpdateSportsLottery	BIT = 0,
	@IsUpdateHabanero		BIT = 0,
	@IsUpdateVGaming		BIT = 0,
	@WMCasinoComm		DECIMAL(9,8) = 0,
	@BigGamingComm		DECIMAL(9,8) = 0,
	@JokerComm			DECIMAL(9,8) = 0,
	@GDGComm			DECIMAL(9,8) = 0,
	@SportsLotteryComm	DECIMAL(9,8) = 0,
	@HabaneroComm		DECIMAL(9,8) = 0,
	@VGamingComm		DECIMAL(9,8) = 0,
	@WMCasinoComm_Group			DECIMAL(9,8) = 0,
	@BigGamingComm_Group		DECIMAL(9,8) = 0,
	@JokerComm_Group			DECIMAL(9,8) = 0,
	@GDGComm_Group				DECIMAL(9,8) = 0,
	@SportsLotteryComm_Group	DECIMAL(9,8) = 0,
	@HabaneroComm_Group			DECIMAL(9,8) = 0,
	@VGamingComm_Group			DECIMAL(9,8) = 0
AS
/*
Created: 20120730@Henry
Task : Update Licensee's players commission
DB: DBCUST/CustDB
Original: Acc_ExecRep_Cust_02

Revisions:
	- 20131023@Hannah: offer Live Casino commission
	- 20150610@Daniel: 
	    + Improve medthod check table existing in subscribers	
	    + Separate custDB to new server DBCUST 	
	- 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]
	- 20171020@Johnson: offer Allbet commision [Redmine: #82036]
	- 20171201@Johnson: enhance AB comm setting, dont move individual setting if not change comm AB [Redmine: #87352]
	- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
	- 20180809@Amanda: Remove Racing [RedmineID: #99378]
	- 20180924@Winnie: Remove Allbet [RedmineID: #99378]
	- 20200409@Johnson: Add comm for AB,Macau,PP [redmine:#131774]
	- 20200511@Max: Add comm for FW, Remove AG, GD - [Redmine: #131774]
	- 20200518@Helen: Add comm for FW, Remove AG, GD - Tuning performance - [Redmine: #131774]
	- 20200701@Helen: Remove Allbet - [Redmine: #131774]
	- 20200814@Helen: LAP - Offer commission to 3rd party products - Phase 2 - [Redmine: #139238] 
	- 20201111@Helen: LAP - Offer commission to 3rd party products - Phase 3 - [Redmine: #145012]
	- 20210603@Eden: LAP - Support commission for 3rd party products - Phase 4 [Redmine: #154048]   
	- 20210816@Johnson: Add VGaming [redmine: #159696]
Param's Explanation:
• @ErrCode:
    = 0: Transaction recorded successfully.
    > 0: Specific Error.
    
• @ErrMsg: Error description.
*/
BEGIN
	SET NOCOUNT ON;
	
	IF NOT(dbo.f_CheckRepTable('custinfo') = 1 
		 AND dbo.f_CheckRepTable('Dep_CustSetting') = 1 
		 AND dbo.f_CheckRepTable('Dep_CustSetting3rd') = 1 		
		 AND dbo.f_CheckRepTable('Dep_CustDiscountSetting_Member') = 1 
		 AND dbo.f_CheckRepTable('Dep_CustDiscountGroupSetting_Member') = 1 
		 AND dbo.f_CheckRepTable('Dep_CustSettingMode') = 1 

	 )
		RETURN 

	DECLARE @InputRes_updateComm AS TABLE (custid INT PRIMARY KEY
					, IsfinishedSB BIT
					, IsfinishedParlay BIT
					, IsfinishedSBParlay BIT
					, IsfinishedNumberGame BIT
					)
	
			
	DECLARE @InputRes_updateComm_batch AS TABLE (custid INT PRIMARY KEY)
	DECLARE @xml XML
	
	-- param for DCS
	DECLARE @sporttype SMALLINT, @bettype SMALLINT, @Comm DECIMAL(9,8), @CommGroup DECIMAL(9,8)			
	DECLARE @tblSettingDCS_tmp AS TABLE (IsUpdated BIT,sporttype SMALLINT,Bettype SMALLINT, Comm DECIMAL(9,8),CommGroup DECIMAL(9,8), isfinished BIT DEFAULT(0))
	
	SET @xml = CONVERT(XML, @IDs) 
	
	INSERT INTO @InputRes_updateComm (custid)
	SELECT T.C.value('./@id', 'INT')
	FROM @xml.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@xml = NULL ))
	
	IF @IsUpdateSB = 1 AND @IsParlayComm = 1
	BEGIN
		WHILE (1=1)
		BEGIN
		
			DELETE @InputRes_updateComm_batch
			
			UPDATE TOP (120) t
				SET IsfinishedSBParlay = 1
			OUTPUT deleted.custid
			INTO @InputRes_updateComm_batch (custid)	
			FROM @InputRes_updateComm t
			WHERE t.IsfinishedSBParlay IS NULL	
			
			IF @@ROWCOUNT = 0
				BREAK
				
			UPDATE cs
				SET playerdiscount = CASE WHEN bettype IN (9,29) THEN @ParlayComm ELSE @SBComm END 
			FROM @InputRes_updateComm_batch r
				INNER JOIN dbo.Dep_CustSetting cs WITH (ROWLOCK, UPDLOCK) ON r.custid = cs.custid
		END
	END
	ELSE
	IF @IsUpdateSB = 1
	BEGIN
		WHILE (1=1)
		BEGIN
		
			DELETE @InputRes_updateComm_batch
			
			UPDATE TOP (120) t
				SET IsfinishedSB = 1
			OUTPUT deleted.custid
			INTO @InputRes_updateComm_batch (custid)	
			FROM @InputRes_updateComm t
			WHERE t.IsfinishedSB IS NULL	
			
			IF @@ROWCOUNT = 0
				BREAK
				
			UPDATE cs
			SET playerdiscount = @SBComm 
			FROM @InputRes_updateComm_batch r
				INNER JOIN dbo.Dep_CustSetting cs WITH (ROWLOCK, UPDLOCK) ON r.custid = cs.custid
			WHERE playerdiscount <> @SBComm  	
				AND bettype NOT IN (9,29)
		END
	END
	ELSE
	IF @IsParlayComm = 1
	BEGIN
		UPDATE cs
			SET playerdiscount = @ParlayComm 
		FROM @InputRes_updateComm r
			INNER JOIN dbo.Dep_CustSetting cs WITH (ROWLOCK, UPDLOCK) ON r.custid = cs.custid
		WHERE playerdiscount <>  @ParlayComm  	
			AND bettype  IN (9,29)
	END
		
	IF (@IsUpdateNG=1) -- update Number Game
	BEGIN
		WHILE (1=1)
		BEGIN
			DELETE @InputRes_updateComm_batch
			
			UPDATE TOP (300) t
				SET IsfinishedNumberGame = 1
			OUTPUT deleted.custid
			INTO @InputRes_updateComm_batch (custid)	
			FROM @InputRes_updateComm t
			WHERE t.IsfinishedNumberGame IS NULL	
			
			IF @@ROWCOUNT = 0
				BREAK
				
			UPDATE cs
				SET playerdiscount = @NGComm 
			FROM @InputRes_updateComm_batch r
				INNER JOIN dbo.Dep_CustSetting3rd cs WITH (ROWLOCK, UPDLOCK) ON r.custid = cs.custid
			WHERE playerdiscount <> @NGComm
				AND sporttype = 161 
				AND bettype BETWEEN 81 AND 90 
		END
	END
	
	IF (@IsUpdateKeno = 1)
	BEGIN
		UPDATE cs
			SET playerdiscount = @KenoComm 
		FROM @InputRes_updateComm r
			INNER JOIN dbo.CustSettingGame cs WITH (ROWLOCK, UPDLOCK) ON r.custid = cs.custid
		WHERE playerdiscount <>  @KenoComm  	
			AND sporttype = 202 AND Bettype = 1501
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
		OR @IsUpdateSportsLottery  = 1	
		OR @IsUpdateHabanero  = 1
		OR @IsUpdateVGaming  = 1		
	)
	BEGIN
		INSERT INTO @tblSettingDCS_tmp (IsUpdated,sporttype,Bettype,CommGroup, Comm)
		VALUES (@IsUpdateMacau, 212,4001,@MacauComm_Group, @MacauComm)
				, (@IsUpdatePP,248,4101,@PPComm_Group ,@PPComm )
				, (@IsUpdateFW,219,1011,@FWComm_Group ,@FWComm)
				-- phase 2
				,(@IsUpdateSexyGaming,243,3101,@SexyGamingComm_Group, @SexyGamingComm )
				,(@IsUpdateSpadeGaming ,247,4301,@SpadeGamingComm_Group, @SpadeGamingComm )
				,(@IsUpdateLottery ,220,1021,@LotteryComm_Group, @LotteryComm )
				,(@IsUpdateVS ,180,1201,@VSComm_Group, @VSComm )
				,(@IsUpdateVS2 ,190,2701,@VS2Comm_Group, @VS2Comm )
				,(@IsUpdateTableGame ,222,4901,@TableGameComm_Group, @TableGameComm )
				-- Phase 3
				,(@IsUpdateVirtualGames,245,4601,@VirtualGamesComm_Group,@VirtualGamesComm)
				,(@IsUpdateArcadiaGaming,165,1901,@ArcadiaGamingComm_Group,@ArcadiaGamingComm)
				,(@IsUpdateSabaclub,200,1611,@SabaclubComm_Group,@SabaclubComm)
				,(@IsUpdateSAGaming,244,3001,@SAGamingComm_Group,@SAGamingComm)
				,(@IsUpdatePGSoft,232,6001,@PGSoftComm_Group,@PGSoftComm)
				,(@IsUpdateAllbet,211,2401,@AllbetComm_Group,@AllbetComm)
				-- Phase 4
				,(@IsUpdateWMCasino,233,3401,@WMCasinoComm_Group,@WMCasinoComm)
				,(@IsUpdateBigGaming,239,3501,@BigGamingComm_Group,@BigGamingComm)
				,(@IsUpdateJoker,234,6401,@JokerComm_Group,@JokerComm)
				,(@IsUpdateGDG,236,5701,@GDGComm_Group,@GDGComm)
				,(@IsUpdateSportsLottery,169,3611,@SportsLotteryComm_Group,@SportsLotteryComm)
				,(@IsUpdateHabanero,238,7001,@HabaneroComm_Group,@HabaneroComm)
				,(@IsUpdateVGaming,171,3801,@VGamingComm_Group,@VGamingComm)
			
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
					,@CommGroup = CommGroup
			WHERE isfinished = 0 AND IsUpdated = 1
			
			IF @@ROWCOUNT = 0 BREAK
			
			IF EXISTS(SELECT TOP 1 1 
					FROM dbo.Dep_CustSettingMode csm WITH(NOLOCK)
						INNER JOIN @InputRes_updateComm r ON csm.CustID = r.custid
					WHERE isGroupedComm = 1)
			BEGIN
				--check if setting change really or not before move
				IF @CommGroup <> @Comm
				BEGIN		
					----move to individual setting
					INSERT INTO dbo.Dep_CustDiscountSetting_Member
						(CustID
						,SportType
						,BetType
						,PlayerDiscount
						,AgentDiscount
						,MasterDiscount
						,SuperDiscount)
					SELECT t.CustID
						,grp.SportType
						,grp.BetType
						,CASE WHEN grp.SportType = @sporttype AND grp.BetType = @bettype THEN @Comm ELSE grp.PlayerDiscount END
						,grp.AgentDiscount
						,grp.MasterDiscount
						,grp.SuperDiscount
					FROM dbo.Dep_CustDiscountGroupSetting_Member grp WITH(NOLOCK)
					CROSS APPLY (SELECT csm.custid
								FROM dbo.Dep_CustSettingMode csm WITH(NOLOCK)
									INNER JOIN @InputRes_updateComm r ON csm.CustID = r.custid
								WHERE isGroupedComm = 1) t
					LEFT JOIN dbo.Dep_CustDiscountSetting_Member cs WITH(NOLOCK) ON cs.custid = t.custid
																				AND cs.sporttype = grp.sporttype
																				AND cs.bettype = grp.bettype
					WHERE AgentID = @AgentID
						AND cs.custid IS NULL
						
					UPDATE csm
						SET	isGroupedComm = 0	
					FROM @InputRes_updateComm r
						INNER JOIN dbo.Dep_CustSettingMode csm WITH(UPDLOCK,ROWLOCK) ON r.custid = csm.CustID		
					WHERE isGroupedComm = 1
				END		
			END		
			
			UPDATE cs
				SET playerdiscount = @Comm
			FROM @InputRes_updateComm r
				INNER JOIN dbo.Dep_CustDiscountSetting_Member cs WITH(UPDLOCK,ROWLOCK) ON r.custid = cs.CustID
			WHERE sporttype = @sporttype
				AND bettype = @bettype
				AND playerdiscount <> @Comm
			
			WAITFOR DELAY '00:00:00.10'	
		END	
	END
END
GO


