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
	--@IsUpdateAllbet BIT = 0,
	@IsUpdateMacau BIT = 0,
	@IsUpdatePP BIT = 0,
	@IsUpdateFW BIT = 0,
	@AgentID INT = NULL,
	--@AllbetComm_Group DECIMAL(9,8)=0,	
	@MacauComm_Group DECIMAL(9,8)=0,	
	@PPComm_Group DECIMAL(9,8)=0,
	@FWComm_Group DECIMAL(9,8)=0	
	
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
	
	--Macau game
	IF (@IsUpdateMacau=1)
	BEGIN
		IF EXISTS(SELECT TOP 1 1 
					FROM dbo.Dep_CustSettingMode csm WITH(NOLOCK)
						INNER JOIN @InputRes_updateComm r ON csm.CustID = r.custid
					WHERE isGroupedComm = 1)
		BEGIN
			--check if setting change really or not before move
			IF @MacauComm_Group <> @MacauComm
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
					,CASE WHEN grp.SportType = 212 AND grp.BetType = 4001 THEN @MacauComm ELSE grp.PlayerDiscount END
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
			IF @PPComm_Group <> @PPComm
			BEGIN		
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
			IF @FWComm_Group <> @FWComm
			BEGIN		
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
			SET playerdiscount = @FWComm
		FROM @InputRes_updateComm r
			INNER JOIN dbo.Dep_CustDiscountSetting_Member cs WITH(UPDLOCK,ROWLOCK) ON cs.CustID = r.custid
		WHERE sporttype = 219
			AND bettype = 1011
			AND playerdiscount <> @FWComm
	END
END
GO


