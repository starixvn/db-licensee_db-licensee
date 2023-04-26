/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/ 
ALTER PROCEDURE [dbo].[Lrf_GroupCommGetById]
	@GroupCommID	INT,
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
	
*/  
BEGIN  
SET NOCOUNT ON;  

SELECT g.ID AS GroupCommID,
	g.GroupName,
	g.SBComm,
	g.NGComm,
	g.RNGComm,
	g.Parlaycomm,	
	g.AllbetComm,
	g.MacauComm,
	g.PPComm,
	g.color AS GroupColor, 
	g.IsDefault,
	g.SexyGamingComm,
	g.SpadeGamingComm,
	g.LotteryComm,
	g.KenoComm,
	g.VSComm,
	g.VS2Comm,
	g.TableGameComm,
	g.VirtualGamesComm,	
	g.ArcadiaGamingComm,	
	g.SabaclubComm,	
	g.SAGamingComm,	
	g.PGSoftComm,
	--> Phase 4
	g.WMCasinoComm,
	g.BigGamingComm,
	g.JokerComm,
	g.HabaneroComm,
	g.VGamingComm,
	g.CGComm, 			
	g.AdvantComm, 		
	g.AdvantMiniComm, 	
	g.VS3Comm,
	g.MaxGameComm,
	g.FGGComm,
	g.JiliComm	
FROM dbo.LicenseeGroupComm g WITH (NOLOCK) 
WHERE 
	IsActive = 1 
	AND Id = @GroupCommID
	AND Licenseeid=@LicenseeID
END
GO   
