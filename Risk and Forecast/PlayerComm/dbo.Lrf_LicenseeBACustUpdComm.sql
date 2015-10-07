SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Lrf_LicenseeBACustUpdComm    Script Date: 5/28/2015 9:20:36 AM ******/
 
CREATE PROC [dbo].[Lrf_LicenseeBACustUpdComm]
	@LicenseeID INT,
	@CustID INT,--member
	@IsBA BIT
AS
/*
Created: 20150508@Jim
Task : Update SB Commission WHEN BA is ON/OFF
DB: DBLIC/bodb_licensee
*/
DECLARE @SBComm [decimal](9,8)
	SET @SBComm = 0
		
SELECT @SBComm = lgc.SBComm
FROM dbo.LicenseeCustComm lcs WITH (NOLOCK)
	INNER JOIN dbo.LicenseeGroupComm lgc WITH (NOLOCK) ON lcs.GroupCommID = lgc.id AND lcs.LicenseeID = lgc.Licenseeid
WHERE lcs.LicenseeID = @LicenseeID
	  AND CustID = @CustID	   
	  
IF (@IsBA =1 )	--- Turn-on BA
	BEGIN 
		IF  NOT EXISTS (SELECT 1 FROM dbo.licensees WITH (NOLOCK) WHERE LicenseeName='Macaubet' AND LicenseeId=@LicenseeID )	
			BEGIN
				UPDATE dbo.LicenseeCustComm WITH (ROWLOCK,UPDLOCK)
				SET SBComm      =  0
				WHERE LicenseeID = @LicenseeID
					   AND CustID = @CustID	   	
			END
	END
ELSE IF (@IsBA = 0 ) -- Turn-off BA
	BEGIN 
	
		UPDATE dbo.LicenseeCustComm WITH (ROWLOCK,UPDLOCK)
		SET SBComm      = @SBComm
		WHERE LicenseeID = @LicenseeID
			   AND CustID = @CustID	   	
	END	
IF  NOT EXISTS (SELECT 1 FROM dbo.licensees WITH (NOLOCK) WHERE LicenseeName='Macaubet' AND LicenseeId=@LicenseeID )	
			BEGIN
				EXEC  DBCUST.CustDB.dbo.Lrf_LicenseeBACust_Playerdiscount_Upd @CustID = @CustID,@SBComm=@SBComm
			END
			

GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT VIEW DEFINITION ON [dbo].[Lrf_LicenseeBACustUpdComm] TO [vnteam]
GO 
 GRANT EXECUTE ON [dbo].[Lrf_LicenseeBACustUpdComm] TO [bodbLicenseeNet]
GO 
	