USE [bodb_licensee]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_LicenseeBACustUpdComm]    Script Date: 10/13/2015 17:49:59 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/****** Object:  Stored Procedure dbo.Lrf_LicenseeBACustUpdComm    Script Date: 5/28/2015 9:20:36 AM ******/
  
ALTER PROC [dbo].[Lrf_LicenseeBACustUpdComm]
	@LicenseeID INT,
	@CustID INT,--member
	@IsBA BIT
AS
/*
Created: 20150508@Jim
Task : Update SB Commission WHEN BA is ON/OFF
DB: DBLIC/bodb_licensee
Revision:
	-20151005@Jim:HotFix #45031
	-20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]
	-20170509@Winnie: LRF-Set back VR setting=0 for BA members [RedmineID:#76231]
*/
DECLARE @SBComm [decimal](9,8), @ParlayComm [decimal](9,8)
	SELECT  @SBComm = 0 , @ParlayComm = 0

DECLARE @bitmap binary(64)
DECLARE @ProfileID INT
SELECT @ProfileID = ProfileID FROM DBCUST.CUSTDB.dbo.[ProfileVirtualSetting] WITH(NOLOCK) WHERE sporttype=1 and bettype=1 and islive=1
SELECT @bitmap = [bitmapVirtual] FROM DBCUST.CUSTDB.[dbo].[CustVirtualSetting] WITH(NOLOCK) WHERE seqNo=1

DECLARE @VirtualMultiplier VARCHAR(MAX)
SELECT @VirtualMultiplier = '<ROOT>	<Rate CustIds="' + CONVERT(VARCHAR(50),@CustID) + '" VirtualMultiplier="1.0" />	</ROOT>' 
		
SELECT @SBComm = lgc.SBComm
	   ,@ParlayComm = lgc.ParlayComm
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
					,ParlayComm =  0
				WHERE LicenseeID = @LicenseeID
					   AND CustID = @CustID	   	
			END
			IF  NOT EXISTS (SELECT 1 FROM dbo.licensees WITH (NOLOCK) WHERE LicenseeName='Macaubet' AND LicenseeId=@LicenseeID )	
			BEGIN
				EXEC  DBCUST.CustDB.dbo.Lrf_LicenseeBACust_Playerdiscount_Upd @CustID = @CustID,@SBComm=0, @ParlayComm = 0
			END
			IF (SELECT top 1 val FROM [dbo].[f_GetVirtualSetting](@ProfileID,@bitmap))=1 
			BEGIN			
				EXEC DBCUST.CustDB.dbo.Acc_CustSetting_10 @VirtualMultiplier = @VirtualMultiplier
			END
	END
ELSE IF (@IsBA = 0 ) -- Turn-off BA
	BEGIN 
	
		UPDATE dbo.LicenseeCustComm WITH (ROWLOCK,UPDLOCK)
		SET SBComm      = @SBComm
			,ParlayComm = @ParlayComm
		WHERE LicenseeID = @LicenseeID
			   AND CustID = @CustID	   	
		IF  NOT EXISTS (SELECT 1 FROM dbo.licensees WITH (NOLOCK) WHERE LicenseeName='Macaubet' AND LicenseeId=@LicenseeID )	
			BEGIN
				EXEC  DBCUST.CustDB.dbo.Lrf_LicenseeBACust_Playerdiscount_Upd @CustID = @CustID,@SBComm=@SBComm, @ParlayComm = @ParlayComm
			END
				   
	END	


GO 
 GRANT VIEW DEFINITION ON [dbo].[Lrf_LicenseeBACustUpdComm] TO [vnteam]
GO 
 GRANT EXECUTE ON [dbo].[Lrf_LicenseeBACustUpdComm] TO [bodbLicenseeNet]
GO 