/*<info serverAlias="DBCUST-CUSTDB" executers="" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[Acc_CustSetting3rd_16]
	@IDs VARCHAR(MAX),
	@DiscountSettings VARCHAR(MAX) = '',
	@AgentID INT = NULL	
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
	- 20211101@Winfred: Merge Sports Lottery under Sportsbook when turn on BA [redmine:#163191]
	- 20220112@Eden: LAP - RNG Casino - Implement DCS Settings [Redmine: #166217] 
	- 20220422@Winfred: LAP - Support commission for 3rd party products - Phase 4.2 [Redmine: #171586] 
	- 20220613@Winfred: HF LAP - Licensee Commission Group - Player discount don't update when user update Group Comm [Redmine: #174029]   
	- 20220301@Eden: Deposit - Sportsbook - Revise customer settings [Redmine: #167898]
	- 20221201@Tacy: Non-sports products - Remove GDG and Fishing World [RedmineID: #174511]
	- 20230314@Johnson: Add MaxGame, FGG, Jili Comm [redmine:#182922]
	- 20230804@Tacy: LAP - Offer Player Commission to Yeebet, MG-RNG [redmine: #192203]
	- 20230808@Tacy: LAP - Offer Player Commission to VS3 (new) [redmine: #192203]
	- 20240126@Tacy: LAP - Merge VS1, VS2, VS3 as Virtual Sports [Redmine: #199523]
	- 20240222@Johnson: Restructure Commission [redmine:#179088]
	- 20240715@Johnson: Apply In-house Replication for Customer Setting [redmine:#207025]	
Param's Explanation:
� @ErrCode:
    = 0: Transaction recorded successfully.
    > 0: Specific Error.
    
� @ErrMsg: Error description.
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @InputRes_updateComm AS TABLE (custid INT PRIMARY KEY)
			
	DECLARE @InputRes_updateComm_batch AS TABLE (custid INT PRIMARY KEY)
	DECLARE @xml XML
	
	SET @xml = CONVERT(XML, @IDs) 
	
	INSERT INTO @InputRes_updateComm (custid)
	SELECT T.C.value('./@id', 'INT')
	FROM @xml.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@xml = NULL ))
	
	-- param for DCS
	DECLARE @sporttype SMALLINT, @bettype SMALLINT, @Discount DECIMAL(9,8), @DiscountGroup DECIMAL(9,8)			
	DECLARE @tblSettings TABLE(SportType SMALLINT, BetType SMALLINT, Discount DECIMAL(9,8), DiscountGroup DECIMAL(9,8), isfinished BIT DEFAULT(0))
	
	DECLARE @xmlDiscountSettings XML
	
	SELECT @xmlDiscountSettings = CAST(@DiscountSettings as XML)
	
	INSERT INTO @tblSettings (SportType,BetType,Discount)
	SELECT t.c.value('@SportType[1]','smallint'),
		t.c.value('@BetType[1]','smallint'),
		t.c.value('@Discount[1]','DECIMAL(9,8)')
	FROM @xmlDiscountSettings.nodes('/Root/r') as T(c)
	
	IF EXISTS (SELECT 1 FROM @tblSettings WHERE SportType =1 AND Bettype = 1)
	BEGIN
		INSERT INTO @tblSettings (SportType,BetType,Discount)
		SELECT s.SportType,s.BetType,Discount
		FROM @tblSettings t
			CROSS APPLY (SELECT 1 Sporttype, 4 AS Bettype
						UNION SELECT 1,5
						UNION SELECT 2,2) s
		WHERE t.Sporttype = 1 AND t.Bettype = 1
	END
	
	UPDATE t
	SET	DiscountGroup = ISNULL(grp.playerdiscount,0)
	FROM dbo.Dep_CustDiscountGroupSetting_Member grp WITH(NOLOCK)
		INNER JOIN @tblSettings t ON grp.SportType = t.SportType AND grp.BetType = t.BetType
	WHERE AgentID = @AgentID
			
	IF EXISTS(SELECT TOP (1) 1 FROM @tblSettings)
	BEGIN
		WHILE (1=1)
		BEGIN
			UPDATE TOP (1) @tblSettings
				SET isfinished = 1
					,@sporttype = sporttype
					,@bettype = Bettype
					,@Discount = Discount 
					,@DiscountGroup = DiscountGroup
			WHERE isfinished = 0
			
			IF @@ROWCOUNT = 0 BREAK
			
			IF EXISTS(SELECT TOP 1 1 
					FROM dbo.Dep_CustSettingMode csm WITH(NOLOCK)
						INNER JOIN @InputRes_updateComm r ON csm.CustID = r.custid
					WHERE isGroupedComm = 1)
			BEGIN
				--check if setting change really or not before move
				IF @DiscountGroup <> @Discount
				BEGIN		
					----move to individual setting
					INSERT INTO dbo.Dep_CustDiscountSetting_Member
						(CustID
						,SportType
						,BetType
						,PlayerDiscount
						,AgentDiscount
						,MasterDiscount
						,SuperDiscount
						,RepUpdateTime)
					SELECT t.CustID
						,grp.SportType
						,grp.BetType
						,CASE WHEN grp.SportType = @sporttype AND grp.BetType = @bettype THEN @Discount ELSE grp.PlayerDiscount END
						,grp.AgentDiscount
						,grp.MasterDiscount
						,grp.SuperDiscount
						,SYSDATETIME()
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
						SET	isGroupedComm = 0,
							RepUpdateTime = SYSDATETIME()
					FROM @InputRes_updateComm r
						INNER JOIN dbo.Dep_CustSettingMode csm WITH(UPDLOCK,ROWLOCK) ON r.custid = csm.CustID		
					WHERE isGroupedComm = 1
				END		
			END		
			
			UPDATE cs
				SET playerdiscount = @Discount,
					RepUpdateTime = SYSDATETIME()
			FROM @InputRes_updateComm r
				INNER JOIN dbo.Dep_CustDiscountSetting_Member cs WITH(UPDLOCK,ROWLOCK) ON r.custid = cs.CustID
			WHERE sporttype = @sporttype
				AND bettype = @bettype
				AND playerdiscount <> @Discount
			
			WAITFOR DELAY '00:00:00.10'	
		END	
	END
END
GO


