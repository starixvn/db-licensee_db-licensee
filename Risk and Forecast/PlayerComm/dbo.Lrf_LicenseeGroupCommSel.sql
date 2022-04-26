/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/ 
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

	Parameter's Explaination: 
*/  
BEGIN  
	SET NOCOUNT ON;  

	SELECT @GroupName = ltrim(rtrim(@GroupName))

	SELECT g.ID AS GroupCommID
		,g.GroupName
		,g.SBComm
		,g.NGComm
		,g.RNGComm
		,g.Parlaycomm	
		,g.AllbetComm
		,g.MacauComm
		,g.PPComm
		--,g.GDComm
		--,g.AGComm
		,g.FWComm
		,g.color AS GroupColor
		,ISNULL(c.NumberOfCustomer,0) AS NumberOfCustomer
		,g.IsDefault  
		,g.SexyGamingComm
		,g.SpadeGamingComm
		,g.LotteryComm
		,g.KenoComm
		,g.VSComm
		,g.VS2Comm
		,g.TableGameComm
		,g.VirtualGamesComm	
		,g.ArcadiaGamingComm
		,g.SabaclubComm	
		,g.SAGamingComm	
		,g.PGSoftComm
		--> Phase 4
		,g.WMCasinoComm
		,g.BigGamingComm
		,g.JokerComm
		,g.GDGComm
		,g.HabaneroComm
		,g.VGamingComm
		,g.CGComm
		,g.AdvantComm
		,g.AdvantMiniComm
		,g.VS3Comm
	FROM dbo.LicenseeGroupComm g WITH (NOLOCK)   
		LEFT JOIN (	SELECT COUNT(1) AS NumberOfCustomer, GroupCommID
					FROM LicenseeCustComm (NOLOCK)
					WHERE LicenseeID = @LicenseeID
					GROUP BY GroupCommID) c ON g.id=c.GroupCommID  
	WHERE   
		IsActive = 1   
		AND (@GroupName='' OR (@GroupName<>'' AND GroupName LIKE '%' + @GroupName + '%'))  
		AND g.LicenseeID = @LicenseeID  
	OPTION (MAXDOP 4)  

END
GO