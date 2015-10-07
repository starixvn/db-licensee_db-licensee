

CREATE PROC [dbo].[Lrf_LicenseeBACust_Playerdiscount_Upd]
	@CustID INT,--member
	@SBComm [decimal](9,8)
AS
/*
Created: 20151007@Jim
Task : Update SB Commission WHEN BA is ON/OFF
DB: DBCUST/CustDB
*/

BEGIN				
	UPDATE [dbo].Dep_CustSetting WITH (ROWLOCK, UPDLOCK)
	SET playerdiscount = @SBComm 
	WHERE custid = @CustID
END	
GO
GRANT EXECUTE ON [dbo].[Lrf_LicenseeBACust_Playerdiscount_Upd] TO [bodbLicenseeNet]
GO
GRANT EXECUTE ON [dbo].[Lrf_LicenseeBACust_Playerdiscount_Upd] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_LicenseeBACust_Playerdiscount_Upd] TO [vnteam] 