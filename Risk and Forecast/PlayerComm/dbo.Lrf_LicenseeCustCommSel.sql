/*<info serverAlias="DBLic-bodb_Licensee" executers="wsv_lap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_LicenseeCustCommSel]
	@CustID INT
AS  
/*  
 * Created: 20120726@Henry
 * Task : Select List Member Commission
 * DB: DBLIC/bodb_Licensee  
 *  
 * Revisions:     
	-20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]
	- 20171020@Johnson: offer Allbet commision [Redmine: #82036]
	- 20180927@Winnie: Remove AllBet [RedmineID: #99378]
	- 20181005@Amanda: Remove Racing [RedmineID: #99378]
	- 20200413@Johnson: add AB,Macau,PP,AG,GD comm [redmine:#131774]
	- 20200511@Max: Add comm for FW, Remove AG, GD - [Redmine: #131774]
	- 20200701@Helen: Remove Allbet - [Redmine: #131774]
	- 20200814@Helen: LAP - Offer commission to 3rd party products - Phase 2 - [Redmine: #139238] 
	- 20201111@Helen: LAP - Offer commission to 3rd party products - Phase 3 - [Redmine: #145012] 
	- 20210603@Eden: LAP - Support commission for 3rd party products - Phase 4 [Redmine: #154048] 
	- 20210813@Johnson: Add VGaming [redmine: #159696]
	- 20211101@Winfred: Merge Sports Lottery under Sportsbook when turn on BA [redmine:#163191]
	- 20220422@Winfred: LAP - Support commission for 3rd party products - Phase 4.2 [Redmine: #171586]  
	- 20221201@Tacy: Non-sports products - Remove GDG and Fishing World [RedmineID: #174511] 
	- 20230314@Johnson: Add MaxGame, FGG, Jili Comm [redmine:#182922]
	- 20230804@Tacy: LAP - Offer Player Commission to Yeebet, MG-RNG [redmine: #192203]
	- 20240111@Tacy: LAP - Merge VS1, VS2, VS3 as Virtual Sports [Redmine: #199523]
	- 20240403@Johnson: Restructure Commission [redmine:#179088]
*/  
BEGIN  
	SET NOCOUNT ON;  
	SELECT 
		lc.CustID,		
		lc.GroupDiscountID		
	FROM dbo.LicenseeCustDiscount lc WITH (NOLOCK)			
	WHERE lc.CustID = @CustID	
	
	DECLARE @IsGroupedComm BIT = 0,
		@AgentID INT
			
	SELECT @IsGroupedComm = IsGroupedComm
	FROM CustDB.dbo.Dep_CustSettingMode d WITH(NOLOCK) 
	WHERE custid = @CustID
	
	IF @IsGroupedComm = 0
	BEGIN
		SELECT Sporttype, Bettype, PlayerDiscount
		FROM CustDB.dbo.Dep_CustDiscountSetting_Member WITH(NOLOCK)
		WHERE custid = @CustID
			AND 1 = CASE WHEN Sporttype = 1 AND Bettype IN (4,5,9) THEN 0 ELSE 1 END
	END
	ELSE 
	BEGIN
		SELECT @AgentID = recommend FROM CustDB.dbo.custinfo WITH(NOLOCK) WHERE custid = @custid
		
		SELECT Sporttype, Bettype, PlayerDiscount
		FROM CustDB.dbo.Dep_CustDiscountGroupSetting_Member WITH(NOLOCK)
		WHERE AgentID = @AgentID
			AND 1 = CASE WHEN Sporttype = 1 AND Bettype IN (4,5,9) THEN 0 ELSE 1 END
	END
END
GO