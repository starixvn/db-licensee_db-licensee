/*<info serverAlias="DBCUST-bodb_Licensee" executers="wsv_lap" viewers="" isFunction="0"></info>*/ 
ALTER PROCEDURE [dbo].[Lrf_GroupCommGetById]
	@GroupDiscountID	INT,
	@LicenseeID		INT

AS  
/*  
 * Created: 20120801@Henry
 * Task : Get Group Comm Info
 * DB: DBLIC/bodb_Licensee  
 *  
 * Revisions:     
	- 20121227@Henry: Add column IsDefault
	- 20131034@Hannah: Offer Live Casino commission
	- 20131126@Hannah: offer RNG Casino commission
	- 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]	
	- 20171025@Johnson: offer Allbet commision [Redmine: #82036]
	- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
	- 20180809@Amanda: Remove Racing [RedmineID: #99378]
	- 20180927@Winnie: Remove AllBet [RedmineID: #99378]
	- 20181205@Winnie: LAP-Security Risks found_settings [RedmineID: #105701]
	- 20200410@Johnson: Add comm for AB,Macau,PP,GD,AG [redmine:#131774] 
	- 20200511@Max: Add comm for FW, Remove AG, GD - [Redmine: #131774]
	- 20200701@Helen: Remove Allbet - [Redmine: #131774]
	- 20200814@Helen: LAP - Offer commission to 3rd party products - Phase 2 - [Redmine: #139238] 
	- 20201111@Helen: LAP - Offer commission to 3rd party products - Phase 3 - [Redmine: #145012] 
	- 20210603@Eden: LAP - Support commission for 3rd party products - Phase 4 [Redmine: #154048]  
	- 20210817@Johnson: Add VGaming [redmine:#159696]
	- 20211101@Winfred: Merge Sports Lottery under Sportsbook when turn on BA [redmine:#163191]
	- 20220422@Winfred: LAP - Support commission for 3rd party products - Phase 4.2 [Redmine: #171586]  
	- 20230314@Johnson: Add MaxGame, FGG, Jili Comm [redmine:#182922]
	- 20230412@Tacy: Non-sports products - Remove GDG and Fishing World [RedmineID: #174511]
	- 20230426@Johnson: missing version PRO [redmine:#182922]
	- 20230804@Tacy: LAP - Offer Player Commission to Yeebet, MG-RNG [redmine: #192203]
	- 20240111@Tacy: LAP - Merge VS1, VS2, VS3 as Virtual Sports [Redmine: #199523]
	- 20240403@Johnson: Restructure Commission [redmine:#179088]
	- 20250219@Eden:Scale Out DBCUST - bodb_Licensee [Redmine:#216866]
*/  
BEGIN  
SET NOCOUNT ON;  
DECLARE @SportBetype TABLE (sporttype SMALLINT, bettype INT, ProductPrefix VARCHAR(10))
	
INSERT INTO @SportBetype (sporttype,bettype,ProductPrefix)
SELECT SportType,bettype,
	CASE WHEN SportType = 1 AND Bettype = 1 THEN 'SB'
		WHEN SportType = 1 AND Bettype = 9 THEN 'Parlay'
		WHEN SportType = 161 AND Bettype = 81 THEN 'NG' ELSE p.ProductPrefix END
FROM GlobCustDB.dbo.Dep_ProductSetting d WITH(NOLOCK)
	INNER JOIN GlobCustDB.dbo.Dep_ProductSettingDetail dp WITH(NOLOCK) 
		ON d.ProductSettingID = dp.ProductSettingID
	LEFT JOIN Product3rd p WITH(NOLOCK) ON d.ProductID = p.ProductID
WHERE SettingType = 9
	AND SettingStatus <> 2
	AND 1 = CASE WHEN (Sporttype = 1 AND Bettype IN (4,5)) OR Sporttype = 2 THEN 0 ELSE 1 END
				
SELECT g.GroupDiscountID,
	g.GroupName,
	g.color AS GroupColor, 
	g.IsDefault
FROM LicenseeGroupDiscount g WITH(NOLOCK)
WHERE 
	IsActive = 1 
	AND GroupDiscountID = @GroupDiscountID
	AND Licenseeid=@LicenseeID
	
SELECT gd.Sporttype, gd.Bettype, s.ProductPrefix as ProductCode, Discount
FROM LicenseeGroupDiscount g WITH(NOLOCK)
	INNER JOIN LicenseeGroupDiscountDetail gd WITH (NOLOCK) ON g.GroupDiscountID = gd.GroupDiscountID	
	INNER JOIN @SportBetype s ON gd.SportType = s.SportType AND s.Bettype = gd.Bettype
WHERE 
	IsActive = 1 
	AND g.GroupDiscountID = @GroupDiscountID
	AND g.Licenseeid=@LicenseeID		
END
GO   
