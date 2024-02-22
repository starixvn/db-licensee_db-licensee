/*<info serverAlias="DBCUST-CustDB" executers="wsv_lap,wsv_nap,svc_tig" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CustomerUpdMemberComm_Direct]
	@CustID INT,
	@DiscountSettings VARCHAR(MAX) = ''	
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
		- 20221201@Tacy: Non-sports products - Remove GDG and Fishing World [RedmineID: #174511]
		- 20230314@Johnson: Add MaxGame, FGG, Jili Comm [redmine:#182922]
		- 20230804@Tacy: LAP - Offer Player Commission to Yeebet, MG-RNG [redmine: #192203]
		- 20230808@Tacy: LAP - Offer Player Commission to VS3 (new) [redmine: #192203]
		- 20240111@Tacy: LAP - Merge VS1, VS2, VS3 as Virtual Sports [Redmine: #199523]
		- 20240221@Johnson: Restructure Commission [redmine:#179088]
	Param's Explanation:	

*/
BEGIN
	SET NOCOUNT ON
	DECLARE @IsGroupedComm BIT, 
			@AgentID INT
	
	DECLARE @sporttype SMALLINT, @bettype SMALLINT, @Discount DECIMAL(9,8)			
	DECLARE @tblSettings TABLE(SportType SMALLINT, BetType SMALLINT, Discount DECIMAL(9,8), isfinished BIT DEFAULT(0))
	
	DECLARE @xmlDiscountSettings XML
	
	SELECT @xmlDiscountSettings = CAST(@DiscountSettings as XML)
	
	INSERT INTO @tblSettings (SportType,BetType,Discount)
	SELECT t.c.value('@SportType[1]','smallint'),
		t.c.value('@BetType[1]','smallint'),
		t.c.value('@Discount[1]','DECIMAL(9,8)')
	FROM @xmlDiscountSettings.nodes('/Root/r') as T(c)
	
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
			--Update SBComm = 0, ParlayComm = 0
			UPDATE t
			SET Discount = 0
			FROM @tblSettings
			WHERE SportType = 1
		END
	END
	
	IF EXISTS(SELECT TOP (1) 1 FROM @tblSettings)
	BEGIN
		WHILE (1=1)
		BEGIN
			UPDATE TOP (1) @tblSettings
				SET isfinished = 1
					,@sporttype = sporttype
					,@bettype = Bettype
					,@Discount = Discount 
			WHERE isfinished = 0 
			
			IF @@ROWCOUNT = 0 BREAK
 
			SELECT @IsGroupedComm = IsGroupedComm
			FROM dbo.Dep_CustSettingMode WITH(NOLOCK)
			WHERE custid = @CustID
			
			IF @IsGroupedComm = 0
			BEGIN
				UPDATE dbo.Dep_CustDiscountSetting_Member WITH(UPDLOCK,ROWLOCK)
					SET PlayerDiscount = @Discount
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
							AND playerdiscount <> @Discount
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
						,CASE WHEN grp.SportType = @sporttype AND grp.BetType = @bettype THEN @Discount ELSE grp.PlayerDiscount END
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
						SET playerdiscount = @Discount
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