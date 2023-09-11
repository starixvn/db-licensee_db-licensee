/*<info serverAlias="DBLic-bodb_Licensee" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
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
*/  
BEGIN  
	SET NOCOUNT ON;  
	SELECT 
		lc.CustID,
		lc.SBComm,
		lc.ParlayComm,
		lc.NGComm,
		lc.GroupCommID,		
		ISNULL(lc.RNGComm, 0) AS RNGComm,						
		ISNULL(lc.AllbetComm,0) AS AllbetComm,
		ISNULL(lc.MacauComm,0) AS MacauComm,
		ISNULL(lc.PPComm,0) AS PPComm,
		--ISNULL(lc.GDComm,0) AS GDComm,
		--ISNULL(lc.AGComm,0) AS AGComm,
		ISNULL(SexyGamingComm,0) AS SexyGamingComm ,
		ISNULL(SpadeGamingComm ,0) AS SpadeGamingComm,
		ISNULL(KenoComm,0) AS KenoComm,
		ISNULL(LotteryComm,0) AS LotteryComm,
		ISNULL(VSComm,0) AS VSComm, 
		ISNULL(VS2Comm,0) AS VS2Comm,
		ISNULL(TableGameComm,0) AS TableGameComm,
		
		ISNULL(VirtualGamesComm,0) AS VirtualGamesComm,	
		ISNULL(ArcadiaGamingComm,0) AS  ArcadiaGamingComm,	
		ISNULL(SabaclubComm,0) AS SabaclubComm,	
		ISNULL(SAGamingComm,0) AS SAGamingComm,	
		ISNULL(PGSoftComm,0) AS PGSoftComm,
		-->phase 4:
		ISNULL(WMCasinoComm,0) AS WMCasinoComm,
		ISNULL(BigGamingComm,0) AS BigGamingComm,	
		ISNULL(JokerComm,0) AS  JokerComm,	
		ISNULL(HabaneroComm,0) AS HabaneroComm,
		ISNULL(VGamingComm,0) AS VGamingComm,
		-- phase 4.2
		ISNULL(CGComm,0) AS CGComm,
		ISNULL(AdvantComm,0) AS AdvantComm,
		ISNULL(AdvantMiniComm,0) AS AdvantMiniComm,
		ISNULL(VS3Comm,0) AS VS3Comm,
		
		ISNULL(MaxGameComm,0) AS MaxGameComm,
		ISNULL(FGGComm,0) AS FGGComm,
		ISNULL(JiliComm,0) AS JiliComm,

		ISNULL(YeeBetComm,0) AS YeeBetComm,
		ISNULL(MgRNGComm,0) AS MgRNGComm
	FROM dbo.LicenseeCustComm lc WITH (NOLOCK)					
	WHERE lc.CustID = @CustID	
END
GO