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
		ISNULL(lc.FWComm,0) AS FWComm
	FROM dbo.LicenseeCustComm lc WITH (NOLOCK)					
	WHERE lc.CustID = @CustID	
END
GO