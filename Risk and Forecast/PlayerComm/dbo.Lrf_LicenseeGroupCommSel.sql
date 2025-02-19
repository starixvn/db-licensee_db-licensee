/*<info serverAlias="DBCUST-bodb_Licensee" executers="wsv_lap" viewers="" isFunction="0"></info>*/ 
ALTER PROCEDURE [dbo].[Lrf_LicenseeGroupCommSel]
	@LicenseeID INT,
	@GroupName VARCHAR(100) = ''
AS  
/*  
 * Created: 20120726@Henry
 * Task : Select Group Commission
 * DB: DBCUST/bodb_Licensee  
 *  
 * Revisions:     
	 - 20121227@Henry: Add column IsDefault
	 - 20131023@Hannah: Offer Live Casino commission
	 - 20131126@Hannah: offer RNG Casino commission
	 - 20151106@Francis: Revise SP to enhance performance [Redmine: #47080]
	 - 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]		
	 - 20171020@Johnson: offer Allbet commision [Redmine: #82036]
	 - 20180228@Vicky: Remove LC from product list [Redmine: #85965]
	 - 20180809@Amanda: Remove Racing [RedmineID: #99378]
	 - 20181003@Sophia: Migrate SP from DB052 to DBCUST [Redmine: #99855]
	 - 20180927@Winnie: Remove AllBet [RedmineID: #99378]
	 - 20200408@Johnson: Add comm for AB,Macau,PP,GD,AG [redmine:#131774]
	 - 20200511@Max: Add comm for FW, Remove AG, GD - [Redmine: #131774]
	 - 20200701@Helen: Remove Allbet - [Redmine: #131774]  
	 - 20200814@Helen: LAP - Offer commission to 3rd party products - Phase 2 - [Redmine: #139238] 
	 - 20201111@Helen: LAP - Offer commission to 3rd party products - Phase 3 - [Redmine: #145012]   
	 - 20210603@Eden: LAP - Support commission for 3rd party products - Phase 4 [Redmine: #154048]   
	 - 20210813@Johnson: Add VGaming [redmine: #159696]
	 - 20220422@Winfred: LAP - Support commission for 3rd party products - Phase 4.2 [Redmine: #171586] 
	 - 20221201@Tacy: Non-sports products - Remove GDG and Fishing World [RedmineID: #174511] 
	 - 20230313@Johnson: Add MaxGame, FGG, Jili Comm [redmine:#182922]
	 - 20230804@Tacy: LAP - Offer Player Commission to Yeebet, MG-RNG [redmine: #192203]
	 - 20240111@Tacy: LAP - Merge VS1, VS2, VS3 as Virtual Sports [Redmine: #199523]
	 - 20240408@Johnson: Restructure Commission [redmine:#179088]
	 - 20250219@Eden:Scale Out DBCUST - bodb_Licensee [Redmine:#216866]
	Parameter's Explaination: 
*/  
BEGIN  
	SET NOCOUNT ON;  
	CREATE TABLE #Result (GroupDiscountID INT PRIMARY KEY, GroupName VARCHAR(100), GroupColor VARCHAR(20),NumberOfCustomer INT,IsDefault BIT)
	DECLARE @SportBetype TABLE (sporttype SMALLINT, bettype INT, ProductPrefix VARCHAR(20))
	
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
				
	SELECT @GroupName = ltrim(rtrim(@GroupName))
	
	INSERT INTO #Result(GroupDiscountID,GroupName,GroupColor,NumberOfCustomer,IsDefault)
	SELECT g.GroupDiscountID
		,g.GroupName		
		,g.color AS GroupColor
		,ISNULL(c.NumberOfCustomer,0) AS NumberOfCustomer
		,g.IsDefault 
	FROM dbo.LicenseeGroupDiscount g WITH (NOLOCK)   
		LEFT JOIN (	SELECT COUNT(1) AS NumberOfCustomer, GroupDiscountID
					FROM LicenseeCustDiscount (NOLOCK)
					WHERE LicenseeID = @LicenseeID
					GROUP BY GroupDiscountID) c ON g.GroupDiscountID=c.GroupDiscountID  
	WHERE   
		IsActive = 1   
		AND (@GroupName='' OR (@GroupName<>'' AND GroupName LIKE '%' + @GroupName + '%'))  
		AND g.LicenseeID = @LicenseeID  
	OPTION (MAXDOP 4)  
	
	SELECT * FROM #Result
	ORDER BY GroupDiscountID
	
	SELECT GroupDiscountID, g.Sporttype, g.Bettype, s.ProductPrefix as ProductCode, Discount
	FROM LicenseeGroupDiscountDetail g WITH(NOLOCK)
		INNER JOIN @SportBetype s ON g.SportType = s.SportType AND s.Bettype = g.Bettype
	WHERE GroupDiscountID IN (SELECT GroupDiscountID FROM #Result)
	ORDER BY GroupDiscountID
	
END
GO