/*<info serverAlias="DBCUST-CustDB" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_ExecRep_Cust_02]
	@IDs VARCHAR(MAX),
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
	@IsUpdateFW BIT = 0
AS
/*
Created: 20120730@Henry
Task : Update Licensee's players commission
DB: DBCUST/CustDB
Original: 

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
					, IsFinishNG BIT
					, IsfinishedAllbet BIT
					, IsfinishedMacau BIT
					, IsfinishedPP BIT
					, IsfinishedFishingWorld BIT)
					
	DECLARE @InputRes_updateComm_batch AS TABLE (custid INT PRIMARY KEY)
	DECLARE @xml XML
	DECLARE @AgentID INT 
	
	SET @xml = CONVERT(XML, @IDs) 
	
	INSERT INTO @InputRes_updateComm (custid)
	SELECT T.C.value('./@custid', 'INT')
	FROM @xml.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@xml = NULL ))
	
	IF @IsUpdateSB = 1
	BEGIN
		WHILE (1=1)
		BEGIN
		
			DELETE @InputRes_updateComm_batch
			
			UPDATE TOP (100) t
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
	
	IF @IsParlayComm = 1
	BEGIN
		WHILE (1=1)
		BEGIN
		
			DELETE @InputRes_updateComm_batch
			
			UPDATE TOP (2000) t
				SET IsfinishedParlay = 1
			OUTPUT deleted.custid
			INTO @InputRes_updateComm_batch (custid)	
			FROM @InputRes_updateComm t
			WHERE t.IsfinishedParlay IS NULL	
			
			IF @@ROWCOUNT = 0
				BREAK
				
			UPDATE cs
				SET playerdiscount = @ParlayComm 
			FROM @InputRes_updateComm_batch r
				INNER JOIN dbo.Dep_CustSetting cs WITH (ROWLOCK, UPDLOCK) ON r.custid = cs.custid
			WHERE playerdiscount <>  @ParlayComm  	
				AND bettype  IN (9,29)
		END
	END
		
	IF (@IsUpdateNG=1) -- update Number Game
	BEGIN
		WHILE (1=1)
		BEGIN
		
			DELETE @InputRes_updateComm_batch
			
			UPDATE TOP (500) t
				SET IsFinishNG = 1
			OUTPUT deleted.custid
			INTO @InputRes_updateComm_batch (custid)	
			FROM @InputRes_updateComm t
			WHERE t.IsFinishNG IS NULL	
			
			IF @@ROWCOUNT = 0 BREAK
				
			UPDATE CS 
				SET playerdiscount = @NGComm 
			FROM @InputRes_updateComm_batch r 
				INNER JOIN [dbo].Dep_CustSetting3rd CS WITH (ROWLOCK, UPDLOCK) ON r.custid = cs.custid
			WHERE playerdiscount <> @NGComm
				AND sporttype = 161 
				AND bettype BETWEEN 81 AND 90 	
				
		END
		
	END
	
	IF ( @IsUpdateAllbet = 1
			OR @IsUpdateMacau = 1
			OR @IsUpdatePP = 1
			OR @IsUpdateFW = 1)
	BEGIN		
		SET @AgentID = (SELECT TOP (1) recommend 
						FROM dbo.CustInfo ci WITH(NOLOCK)
							INNER JOIN @InputRes_updateComm r ON ci.custid = r.custid
						)
	END	
	
	IF (@IsUpdateAllbet=1)
	BEGIN
		IF EXISTS(SELECT TOP 1 1 
					FROM dbo.Dep_CustSettingMode cs WITH(NOLOCK)
						INNER JOIN @InputRes_updateComm r ON r.custid = cs.custid
					WHERE isGroupedComm = 1)
		BEGIN
			--check if setting change really or not before move
			IF EXISTS(SELECT 1
					FROM dbo.Dep_CustDiscountGroupSetting_Member grp WITH(NOLOCK)
					WHERE AgentID = @AgentID
						AND sporttype = 211
						AND bettype = 2401
						AND playerdiscount <> @AllbetComm
					)
			BEGIN		
				--move to individual setting
				WHILE (1=1)
				BEGIN
				
					DELETE @InputRes_updateComm_batch
					
					UPDATE TOP (500) t
						SET IsfinishedAllbet = 1
					OUTPUT deleted.custid
					INTO @InputRes_updateComm_batch (custid)	
					FROM @InputRes_updateComm t
					WHERE t.IsfinishedAllbet IS NULL	
					
					IF @@ROWCOUNT = 0
						BREAK
						
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
						,CASE WHEN grp.SportType = 211 AND grp.BetType = 2401 THEN @AllbetComm ELSE grp.PlayerDiscount END
						,grp.AgentDiscount
						,grp.MasterDiscount
						,grp.SuperDiscount
					FROM dbo.Dep_CustDiscountGroupSetting_Member grp WITH(NOLOCK)
					CROSS APPLY (SELECT csm.custid
								FROM dbo.Dep_CustSettingMode csm WITH(NOLOCK)
									INNER JOIN @InputRes_updateComm_batch r ON r.custid = csm.CustID
								WHERE isGroupedComm = 1) t
					LEFT JOIN dbo.Dep_CustDiscountSetting_Member cs WITH(NOLOCK) ON cs.custid = t.custid
																				AND cs.sporttype = grp.sporttype
																				AND cs.bettype = grp.bettype
					WHERE AgentID = @AgentID
						AND cs.custid IS NULL
				END
				
				UPDATE csm 
					SET	isGroupedComm = 0	
				FROM @InputRes_updateComm r 
					INNER JOIN dbo.Dep_CustSettingMode csm WITH(UPDLOCK,ROWLOCK) ON csm.CustID = r.custid	
				WHERE isGroupedComm = 1
				
			END		
		END		
		
		UPDATE cs
			SET playerdiscount = @AllbetComm
		FROM @InputRes_updateComm r
			INNER JOIN dbo.Dep_CustDiscountSetting_Member cs WITH(UPDLOCK,ROWLOCK) ON cs.CustID = r.custid
		WHERE sporttype = 211
			AND bettype = 2401
			AND playerdiscount <> @AllbetComm
	END
	
	--Macau game
	IF (@IsUpdateMacau=1)
	BEGIN
		IF EXISTS(SELECT TOP 1 1 
					FROM dbo.Dep_CustSettingMode csm WITH(NOLOCK)
						INNER JOIN @InputRes_updateComm r ON csm.CustID = r.custid
					WHERE isGroupedComm = 1)
		BEGIN
			--check if setting change really or not before move
			IF EXISTS(SELECT 1
					FROM dbo.Dep_CustDiscountGroupSetting_Member grp WITH(NOLOCK)
					WHERE AgentID = @AgentID
						AND sporttype = 212
						AND bettype = 4001
						AND playerdiscount <> @MacauComm
					)
			BEGIN		
				--move to individual setting
				WHILE (1=1)
				BEGIN
				
					DELETE @InputRes_updateComm_batch
					
					UPDATE TOP (500) t
						SET IsfinishedMacau = 1
					OUTPUT deleted.custid
					INTO @InputRes_updateComm_batch (custid)	
					FROM @InputRes_updateComm t
					WHERE t.IsfinishedMacau IS NULL	
					
					IF @@ROWCOUNT = 0
						BREAK
						
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
						,CASE WHEN grp.SportType = 212 AND grp.BetType = 4001 THEN @MacauComm ELSE grp.PlayerDiscount END
						,grp.AgentDiscount
						,grp.MasterDiscount
						,grp.SuperDiscount
					FROM dbo.Dep_CustDiscountGroupSetting_Member grp WITH(NOLOCK)
					CROSS APPLY (SELECT csm.custid
								FROM dbo.Dep_CustSettingMode csm WITH(NOLOCK)
									INNER JOIN @InputRes_updateComm_batch r ON csm.CustID = r.custid
								WHERE isGroupedComm = 1) t
					LEFT JOIN dbo.Dep_CustDiscountSetting_Member cs WITH(NOLOCK) ON cs.custid = t.custid
																				AND cs.sporttype = grp.sporttype
																				AND cs.bettype = grp.bettype
					WHERE AgentID = @AgentID
						AND cs.custid IS NULL
						
				END
				
				UPDATE csm
					SET	isGroupedComm = 0	
				FROM @InputRes_updateComm r
					INNER JOIN dbo.Dep_CustSettingMode csm WITH(UPDLOCK,ROWLOCK) ON r.custid = csm.CustID		
				WHERE isGroupedComm = 1
			END		
		END		
		
		UPDATE cs
			SET playerdiscount = @MacauComm
		FROM @InputRes_updateComm r
			INNER JOIN dbo.Dep_CustDiscountSetting_Member cs WITH(UPDLOCK,ROWLOCK) ON r.custid = cs.CustID
		WHERE sporttype = 212
			AND bettype = 4001
			AND playerdiscount <> @MacauComm
	END
	
	IF (@IsUpdatePP=1)
	BEGIN
		IF EXISTS(SELECT TOP (1) 1 
					FROM dbo.Dep_CustSettingMode csm WITH(NOLOCK)
						INNER JOIN @InputRes_updateComm r ON csm.CustID = r.custid
					WHERE isGroupedComm = 1)
		BEGIN
			--check if setting change really or not before move
			IF EXISTS(SELECT TOP (1) 1
					FROM dbo.Dep_CustDiscountGroupSetting_Member grp WITH(NOLOCK)
					WHERE AgentID = @AgentID
						AND sporttype = 248
						AND bettype = 4101
						AND playerdiscount <> @PPComm
					)
			BEGIN		
				--move to individual setting
				WHILE (1=1)
				BEGIN
				
					DELETE @InputRes_updateComm_batch
					
					UPDATE TOP (500) t
						SET IsfinishedPP = 1
					OUTPUT deleted.custid
					INTO @InputRes_updateComm_batch (custid)	
					FROM @InputRes_updateComm t
					WHERE t.IsfinishedPP IS NULL	
					
					IF @@ROWCOUNT = 0
						BREAK
						
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
						,CASE WHEN grp.SportType = 248 AND grp.BetType = 4101 THEN @PPComm ELSE grp.PlayerDiscount END
						,grp.AgentDiscount
						,grp.MasterDiscount
						,grp.SuperDiscount
					FROM dbo.Dep_CustDiscountGroupSetting_Member grp WITH(NOLOCK)
					CROSS APPLY (SELECT csm.custid
								FROM dbo.Dep_CustSettingMode csm WITH(NOLOCK)
									INNER JOIN @InputRes_updateComm_batch r ON csm.CustID = r.custid
								WHERE isGroupedComm = 1) t
					LEFT JOIN dbo.Dep_CustDiscountSetting_Member cs WITH(NOLOCK) ON cs.custid = t.custid
																				AND cs.sporttype = grp.sporttype
																				AND cs.bettype = grp.bettype
					WHERE AgentID = @AgentID
						AND cs.custid IS NULL
						
				END
				
				UPDATE csm
					SET	isGroupedComm = 0
				FROM @InputRes_updateComm r
					INNER JOIN dbo.Dep_CustSettingMode csm WITH(UPDLOCK,ROWLOCK) ON r.custid = csm.CustID
				WHERE isGroupedComm = 1
			END		
		END		
		
		UPDATE cs
			SET playerdiscount = @PPComm
		FROM @InputRes_updateComm r
			INNER JOIN dbo.Dep_CustDiscountSetting_Member cs WITH(UPDLOCK,ROWLOCK) ON r.custid = cs.CustID
		WHERE sporttype = 248
			AND bettype = 4101
			AND playerdiscount <> @PPComm
	END

	--Fishing World
	IF (@IsUpdateFW=1)
	BEGIN
		IF EXISTS(SELECT TOP (1) 1 
					FROM dbo.Dep_CustSettingMode csm WITH(NOLOCK)
						INNER JOIN @InputRes_updateComm r ON csm.CustID = r.custid
					WHERE isGroupedComm = 1)
		BEGIN
			--check if setting change really or not before move
			IF EXISTS(SELECT TOP (1) 1
					FROM dbo.Dep_CustDiscountGroupSetting_Member grp WITH(NOLOCK)
					WHERE AgentID = @AgentID
						AND sporttype = 219
						AND bettype = 1011
						AND playerdiscount <> @FWComm
					)
			BEGIN		
				--move to individual setting
				WHILE (1=1)
				BEGIN
				
					DELETE @InputRes_updateComm_batch
					
					UPDATE TOP (500) t
						SET IsfinishedFishingWorld = 1
					OUTPUT deleted.custid
					INTO @InputRes_updateComm_batch (custid)	
					FROM @InputRes_updateComm t
					WHERE t.IsfinishedFishingWorld IS NULL	
					
					IF @@ROWCOUNT = 0
						BREAK
						
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
						,CASE WHEN grp.SportType = 219 AND grp.BetType = 1011 THEN @PPComm ELSE grp.PlayerDiscount END
						,grp.AgentDiscount
						,grp.MasterDiscount
						,grp.SuperDiscount
					FROM dbo.Dep_CustDiscountGroupSetting_Member grp WITH(NOLOCK)
					CROSS APPLY (SELECT csm.custid
								FROM dbo.Dep_CustSettingMode csm WITH(NOLOCK)
									INNER JOIN @InputRes_updateComm_batch r ON csm.CustID = r.custid
								WHERE isGroupedComm = 1) t
					LEFT JOIN dbo.Dep_CustDiscountSetting_Member cs WITH(NOLOCK) ON cs.custid = t.custid
																				AND cs.sporttype = grp.sporttype
																				AND cs.bettype = grp.bettype
					WHERE AgentID = @AgentID
						AND cs.custid IS NULL
						
				END
				
				UPDATE csm
					SET	isGroupedComm = 0
				FROM @InputRes_updateComm r
					INNER JOIN dbo.Dep_CustSettingMode csm WITH(UPDLOCK,ROWLOCK) ON r.custid = csm.CustID		
				WHERE isGroupedComm = 1
			END		
		END		
		
		UPDATE cs
			SET playerdiscount = @FWComm
		FROM @InputRes_updateComm r
			INNER JOIN dbo.Dep_CustDiscountSetting_Member cs WITH(UPDLOCK,ROWLOCK) ON cs.CustID = r.custid
		WHERE sporttype = 219
			AND bettype = 1011
			AND playerdiscount <> @FWComm
	END
END
GO