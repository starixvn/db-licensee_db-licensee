

CREATE PROC [dbo].[Lrf_LicenseeBACust_Playerdiscount_Upd]
	@CustID INT,--member
	@SBComm [decimal](9,8),
	@ParlayComm [decimal](9,8)
AS
/*
Created: 20151007@Jim
Task : Update SB Commission,Parlay Commission WHEN BA is ON/OFF
DB: DBCUST/CustDB
Revision :
	-20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]
*/
 

BEGIN				
	UPDATE [dbo].Dep_CustSetting WITH (ROWLOCK, UPDLOCK)
	SET playerdiscount = @SBComm 
	WHERE custid = @CustID
		 AND bettype NOT IN (9,29)
		 
	UPDATE [dbo].Dep_CustSetting WITH (ROWLOCK, UPDLOCK)
	SET playerdiscount = @ParlayComm
	WHERE custid = @CustID
		 AND bettype  IN (9,29)	 
END	
GO
GRANT EXECUTE ON [dbo].[Lrf_LicenseeBACust_Playerdiscount_Upd] TO [bodbLicenseeNet]
GO
GRANT EXECUTE ON [dbo].[Lrf_LicenseeBACust_Playerdiscount_Upd] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_LicenseeBACust_Playerdiscount_Upd] TO [vnteam] 