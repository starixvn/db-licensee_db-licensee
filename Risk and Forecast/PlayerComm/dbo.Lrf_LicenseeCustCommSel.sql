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
		ISNULL(lc.FWComm,0) AS FWComm,
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
		ISNULL(PGSoftComm,0) AS PGSoftComm	
		
	FROM dbo.LicenseeCustComm lc WITH (NOLOCK)					
	WHERE lc.CustID = @CustID	
END
GO